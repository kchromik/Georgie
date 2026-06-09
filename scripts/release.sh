#!/bin/bash
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
# Georgie release pipeline: archive → export → re-sign → DMG → notarize →
# staple → Sparkle-sign → update appcast → GitHub release → push.
#
# Unlike the ShoutFlow original this:
#   • is NOT for Homebrew,
#   • uses ONE repo (this one) for both the appcast.xml and the DMG release,
#   • signs the Sparkle update with a dedicated keychain account ("Georgie").
APP_NAME="Georgie"
SCHEME="Georgie"
RELEASES_REPO="kchromik/Georgie"          # appcast.xml + DMG live in this repo
SPARKLE_ACCOUNT="Georgie"                  # generate_keys/sign_update --account
TEAM_ID="7HFRDKKUCK"
SIGNING_ID="Developer ID Application: Kevin Chromik (${TEAM_ID})"
# Override with: NOTARIZE_PROFILE=Foo ./scripts/release.sh
# The keychain on this machine has one shared notary profile (created for
# ShoutFlow, same team) — Georgie 1.0.0 was notarized with it too.
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-ShoutFlow-Notarize}"

ARCHIVE_PATH="/tmp/${APP_NAME}.xcarchive"
EXPORT_PATH="/tmp/${APP_NAME}-export"
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData/${APP_NAME}-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update 2>/dev/null | head -1)

# ─── Helpers ──────────────────────────────────────────────────────────────────
red()   { printf "\033[31m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
blue()  { printf "\033[34m%s\033[0m\n" "$1"; }
die()   { red "ERROR: $1"; exit 1; }

# ─── Preflight checks ────────────────────────────────────────────────────────
command -v gh >/dev/null || die "GitHub CLI (gh) is not installed"
command -v xcodebuild >/dev/null || die "Xcode command-line tools are not installed"
command -v create-dmg >/dev/null || die "create-dmg is not installed (brew install create-dmg)"
[ -n "$SIGN_UPDATE" ] || die "Sparkle sign_update not found. Build the project in Xcode first."
security find-identity -v -p codesigning | grep -q "$SIGNING_ID" \
    || die "Signing identity not found in keychain: ${SIGNING_ID}"

# ─── Get or set version ───────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
PBXPROJ="${PROJECT_DIR}/Georgie.xcodeproj/project.pbxproj"
ENTITLEMENTS="${PROJECT_DIR}/Georgie/Georgie.entitlements"
APPCAST="${PROJECT_DIR}/appcast.xml"
RELEASE_NOTES_FILE="${PROJECT_DIR}/scripts/release-notes.html"

if [ -n "${1:-}" ]; then
    NEW_VERSION="$1"
    blue "Setting version to ${NEW_VERSION}..."
    sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${NEW_VERSION}/" "$PBXPROJ"
    OLD_BUILD=$(grep "CURRENT_PROJECT_VERSION" "$PBXPROJ" | head -1 | awk '{print $3}' | tr -d ';')
    NEW_BUILD=$((OLD_BUILD + 1))
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = ${NEW_BUILD}/" "$PBXPROJ"
    MARKETING_VERSION="$NEW_VERSION"
    BUILD_NUMBER="$NEW_BUILD"
    green "Version: ${MARKETING_VERSION} (build ${BUILD_NUMBER})"
else
    MARKETING_VERSION=$(xcodebuild -scheme "$SCHEME" -showBuildSettings 2>/dev/null | grep "MARKETING_VERSION" | head -1 | awk '{print $3}')
    BUILD_NUMBER=$(xcodebuild -scheme "$SCHEME" -showBuildSettings 2>/dev/null | grep "CURRENT_PROJECT_VERSION" | head -1 | awk '{print $3}')
fi

[ -n "$MARKETING_VERSION" ] || die "Could not read MARKETING_VERSION from project"
[ -n "$BUILD_NUMBER" ] || die "Could not read CURRENT_PROJECT_VERSION from project"

VERSION="v${MARKETING_VERSION}"
blue "Releasing ${APP_NAME} ${VERSION} (build ${BUILD_NUMBER})"

# ─── Step 1: Archive ─────────────────────────────────────────────────────────
blue "Step 1/8: Archiving..."
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    CODE_SIGN_STYLE=Automatic \
    2>&1 | tail -5
[ -d "$ARCHIVE_PATH" ] || die "Archive failed"
green "Archive created."

# ─── Step 2: Export ───────────────────────────────────────────────────────────
blue "Step 2/8: Exporting (Developer ID)..."
rm -rf "$EXPORT_PATH"
cat > /tmp/georgie-export-options.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist /tmp/georgie-export-options.plist \
    -exportPath "$EXPORT_PATH" \
    2>&1 | tail -5

APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
[ -d "$APP_PATH" ] || die "Export failed — ${APP_NAME}.app not found"
green "Exported app."

# Re-sign the app WITH entitlements + hardened runtime so the camera
# entitlement is preserved. This only re-seals the top-level bundle; the
# embedded Sparkle.framework (and its XPC services) keep their Xcode signature.
blue "Re-signing app with entitlements + hardened runtime..."
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGNING_ID" \
    "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tail -3 || die "Codesign verification failed"
green "App re-signed and verified."

# ─── Step 3: Create DMG ──────────────────────────────────────────────────────
blue "Step 3/8: Creating DMG..."
DMG_NAME="${APP_NAME}-${MARKETING_VERSION}.dmg"
DMG_PATH="/tmp/${DMG_NAME}"
rm -f "$DMG_PATH"

APP_ICNS="${APP_PATH}/Contents/Resources/AppIcon.icns"
VOLICON_ARG=""
[ -f "$APP_ICNS" ] && VOLICON_ARG="--volicon ${APP_ICNS}"

create-dmg \
    --volname "$APP_NAME" \
    ${VOLICON_ARG} \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 180 170 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 480 170 \
    "$DMG_PATH" \
    "$APP_PATH" \
    2>&1

[ -f "$DMG_PATH" ] || die "DMG creation failed"
green "DMG created: ${DMG_NAME}"

# ─── Step 4: Notarize ─────────────────────────────────────────────────────────
blue "Step 4/8: Notarizing with Apple (this may take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait \
    2>&1
blue "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH" 2>&1
green "Notarization complete."

DMG_SIZE=$(stat -f%z "$DMG_PATH")

# ─── Step 5: Sign with Sparkle ───────────────────────────────────────────────
blue "Step 5/8: Signing with Sparkle EdDSA (account: ${SPARKLE_ACCOUNT})..."
SIGNATURE_OUTPUT=$("$SIGN_UPDATE" --account "$SPARKLE_ACCOUNT" "$DMG_PATH" 2>&1)
ED_SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep "sparkle:edSignature=" | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
[ -n "$ED_SIGNATURE" ] || die "Failed to get EdDSA signature. Output: $SIGNATURE_OUTPUT"
green "Signed. EdDSA: ${ED_SIGNATURE:0:20}..."

# ─── Step 6: Update appcast.xml (in this repo) ───────────────────────────────
blue "Step 6/8: Updating appcast.xml..."
DOWNLOAD_URL="https://github.com/${RELEASES_REPO}/releases/download/${VERSION}/${DMG_NAME}"
PUB_DATE=$(date -R)

if [ -f "$RELEASE_NOTES_FILE" ]; then
    RELEASE_NOTES_HTML=$(cat "$RELEASE_NOTES_FILE")
    blue "Release notes found."
else
    RELEASE_NOTES_HTML=""
fi

python3 -c "
import xml.etree.ElementTree as ET

ET.register_namespace('sparkle', 'http://www.andymatuschak.org/xml-namespaces/sparkle')
ET.register_namespace('dc', 'http://purl.org/dc/elements/1.1/')

tree = ET.parse('$APPCAST')
root = tree.getroot()
channel = root.find('channel')

item = ET.SubElement(channel, 'item')
ET.SubElement(item, 'title').text = 'Version $MARKETING_VERSION'
ET.SubElement(item, 'pubDate').text = '$PUB_DATE'
ET.SubElement(item, '{http://www.andymatuschak.org/xml-namespaces/sparkle}version').text = '$BUILD_NUMBER'
ET.SubElement(item, '{http://www.andymatuschak.org/xml-namespaces/sparkle}shortVersionString').text = '$MARKETING_VERSION'
ET.SubElement(item, '{http://www.andymatuschak.org/xml-namespaces/sparkle}minimumSystemVersion').text = '14.0'

release_notes = '''$RELEASE_NOTES_HTML'''
if release_notes.strip():
    ET.SubElement(item, 'description').text = release_notes

enclosure = ET.SubElement(item, 'enclosure')
enclosure.set('url', '$DOWNLOAD_URL')
enclosure.set('length', '$DMG_SIZE')
enclosure.set('type', 'application/octet-stream')
enclosure.set('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature', '$ED_SIGNATURE')

ET.indent(tree, space='  ')
tree.write('$APPCAST', xml_declaration=True, encoding='utf-8')
"
green "appcast.xml updated."

# ─── Step 7: Create GitHub release with the DMG ──────────────────────────────
blue "Step 7/8: Creating GitHub release ${VERSION}..."
if [ -f "$RELEASE_NOTES_FILE" ]; then
    gh release create "$VERSION" "$DMG_PATH" \
        --repo "$RELEASES_REPO" \
        --title "${APP_NAME} ${MARKETING_VERSION}" \
        --notes-file "$RELEASE_NOTES_FILE" 2>&1
else
    gh release create "$VERSION" "$DMG_PATH" \
        --repo "$RELEASES_REPO" \
        --title "${APP_NAME} ${MARKETING_VERSION}" \
        --notes "${APP_NAME} ${MARKETING_VERSION}" 2>&1
fi
green "GitHub release created."

# ─── Step 8: Commit appcast + version bump and push ──────────────────────────
blue "Step 8/8: Committing appcast.xml and version bump..."
git add "$APPCAST"
git diff --quiet "$PBXPROJ" 2>/dev/null || git add "$PBXPROJ"
git commit -m "Release ${VERSION}" 2>&1 || blue "Nothing to commit."
git push 2>&1
green "Pushed."

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
green "============================================"
green "  Release ${VERSION} complete!"
green "  DMG:     ${DMG_PATH}"
green "  Release: https://github.com/${RELEASES_REPO}/releases/tag/${VERSION}"
green "  Appcast: https://raw.githubusercontent.com/${RELEASES_REPO}/main/appcast.xml"
green "============================================"
echo ""
blue "Reminder: the repo must be PUBLIC for Sparkle to fetch the appcast & DMG."
