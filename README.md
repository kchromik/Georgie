# Georgie

> *"We all float down here… and when you're up here with your windows, **they all float too**."*

<p align="center">
  <img src="https://c.tenor.com/2jJuBNJJZygAAAAC/tenor.gif" alt="Pennywise: we all float down here" width="480">
</p>

**Georgie** is a native macOS menu-bar app that puts any content into a **floating, always-on-top window** — a web page, a PDF, an image, a video, a quick note, or your camera. Open as many as you like, dial down their opacity, click straight through them, and keep them in view across every Space.

It's modeled on the content-widget approach of [AlwaysOnTop](https://alwaysontop.app) and the window-floating idea of [Floaty](https://floatytool.com).

---

## What's with the name?

The app is named after **Georgie Denbrough** from Stephen King's *IT* — the boy in the yellow raincoat chasing his paper boat down the gutter. Pennywise's promise from the storm drain, *"they float… they all float down here,"* is the whole pitch: with Georgie, your windows all float. Up here, though, floating is a feature, not a threat. 🎈

---

## Features

- 🌐 **Web** — a real browser window (`WKWebView`) with an address bar, back/forward/reload, and smart input (type a domain → opens it, type anything else → searches).
- 📄 **PDF** — full PDFKit viewer: scroll, zoom, continuous pages.
- 🖼️ **Image** — view files or paste straight from the clipboard; scroll-to-zoom up to 8×.
- 🎬 **Video** — local files and streams via AVKit, including system Picture-in-Picture.
- 📝 **Note** — a floating scratchpad with auto-save; the window title follows your first line.
- 📷 **Camera** — your webcam in a floating window for calls, recordings, or screen-sharing.

Every window shares the same floating behavior:

- **Always on top** — three levels: *Normal*, *Always on Top*, *Top Most*.
- **Adjustable opacity** — 20–100 % per window.
- **Click-through** — let mouse clicks pass through the window to whatever's behind it.
- **All Spaces** — windows stay visible as you switch desktops, and alongside full-screen apps.
- **Minimal chrome** — controls appear on hover; drag from anywhere on the title strip.
- **Remembers everything** — size, position, opacity and (optionally) your whole set of open windows are restored on the next launch.

Add content via the menu bar, the **file dialog**, **drag & drop** onto a window, the clipboard, or **"Open With…"** from Finder.

---

## Requirements

- macOS **14.0** (Sonoma) or later
- Apple Silicon or Intel
- Xcode **16+** to build

---

## Build & Run

```bash
git clone <repo-url> Georgie
cd Georgie
open Georgie.xcodeproj
```

Then press **⌘R** in Xcode.

Georgie is a **menu-bar-only app** (`LSUIElement`) — it has no Dock icon and no main window. After launching, look for the **`pip` icon in the macOS menu bar** (top right). Everything starts from there.

> The project uses Xcode's *file-system-synchronized groups*: any `.swift` file added under `Georgie/` is compiled automatically — no `project.pbxproj` editing required.

---

## Usage

Click the menu-bar icon and choose what to float:

| Action | What happens |
|---|---|
| **New Web Window** | Empty browser window; type an address or search term |
| **New Note** | Blank scratchpad, ready to type |
| **Camera** | Webcam preview (asks for permission the first time) |
| **Open PDF / Image / Video…** | File picker for that content type |
| **Image from Clipboard** | Floats whatever image you've copied |
| **Open Windows ▸** | Per-window: bring to front, toggle click-through, close |
| **Close All** | Dismiss every floating window |
| **Settings…** | Default opacity, default level, session restore |
| **Check for Updates…** | Manually check for a new version (Sparkle) |
| **About Georgie** | Version, links, and update preferences |

Hover over any window to reveal its control strip: title/drag-handle, opacity slider, level menu, click-through toggle, close.

> **Tip:** when a window is in click-through mode it ignores *all* mouse events — re-enable interaction from the menu bar under **Open Windows ▸**.

---

## Permissions

Georgie's core needs **no special permissions** — instant value on first launch, no scary prompts.

| Permission | Needed for | When |
|---|---|---|
| *(none)* | Web, PDF, Image, Video, Note | Always available |
| **Camera** | The camera widget only | Requested the first time you open it |

Nothing is sent anywhere — all content stays on your Mac. Georgie runs with the
**Hardened Runtime** but is **not** sandboxed (it's distributed outside the Mac
App Store), so loading web pages and opening files needs no extra entitlement.

---

## Architecture

A single floating-window component (`FloatingPanel`, an `NSPanel`) is shared by **all** widget types. Each type is just a different SwiftUI view hosted inside that panel.

```
Georgie/
├── GeorgieApp.swift            # @main — MenuBarExtra + Settings scene
├── App/
│   ├── AppDelegate.swift       # session restore, "Open With", quit-save
│   ├── AppMenu.swift           # the menu-bar menu
│   └── SettingsView.swift      # preferences UI
├── Core/
│   ├── FloatingPanel.swift            # NSPanel: non-activating, always-on-top, transparent
│   ├── FloatingPanelController.swift  # binds a model to a panel, hosts SwiftUI, mirrors state
│   ├── WidgetManager.swift            # creates/closes/focuses windows; persistence
│   ├── WidgetInstance.swift           # @Observable model per window (source + window state)
│   ├── WidgetKind.swift               # the six content types
│   ├── FloatLevel.swift               # window-level abstraction
│   ├── SettingsStore.swift            # @Observable, UserDefaults-backed
│   └── SessionPersistence.swift       # Codable snapshot for restore
└── Widgets/
    ├── WidgetContainerView.swift  # routes to content, adds chrome, handles drop
    ├── WidgetChrome.swift         # hover control strip
    ├── WindowDragHandle.swift     # reliable window dragging over web/PDF content
    ├── WidgetPlaceholder.swift    # shared empty state
    ├── WebViewerView.swift        # WKWebView + address bar
    ├── PDFViewerView.swift        # PDFKit
    ├── ImageViewerView.swift      # NSImageView in a zoomable scroll view
    ├── VideoViewerView.swift      # AVKit (AVPlayerView)
    ├── ScratchpadView.swift       # TextEditor + auto-save
    └── CameraViewerView.swift     # AVFoundation capture + preview layer
```

**State flow:** `WidgetInstance` is the single source of truth. The SwiftUI chrome edits it; `FloatingPanelController` observes it (via Swift's Observation framework) and mirrors opacity / level / click-through onto the live `NSPanel`. Files are persisted with `URL` bookmarks so they survive relaunches even if the file is moved or renamed.

---

## Tech stack

| Area | Technology |
|---|---|
| UI | SwiftUI + AppKit interop (`NSViewRepresentable`, `NSPanel`) |
| State | Observation (`@Observable`) |
| Web | WebKit (`WKWebView`) |
| PDF | PDFKit |
| Video | AVKit (`AVPlayerView`) |
| Image | AppKit (`NSImageView`) |
| Camera | AVFoundation (`AVCaptureSession`) |
| Persistence | `UserDefaults` + Codable + `URL` bookmarks |
| Updates | [Sparkle](https://sparkle-project.org) (EdDSA-signed appcast) |
| Language | English only |

---

## Roadmap

Built in phases (see `Anforderungsanalyse_PiP_App.md` for the full spec).

- ✅ **Phase 0 — Scaffold:** menu-bar app, floating-panel core, opacity, always-on-top.
- ✅ **Phase 1 — Content widgets:** Web, PDF, Image, Video, Note.
- ✅ **Phase 2 (core) — Comfort:** Camera, settings, session/geometry restore, drag & drop, "Open With".
- ✅ **Phase 3 — Distribution:** Developer-ID signing + notarization, DMG, Sparkle auto-updates, About panel. **Georgie is free** — no license gating.
- ⏳ **Phase 2 (rest):** global hotkeys (e.g. via [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)).
- ⏳ **Phase 4 — Window pinning:** mirror other apps' windows via ScreenCaptureKit (the Floaty feature; deliberately deferred).
- ⏳ **Phase 5 — Extras:** "Pets"/fun widgets, AppleScript / `pip://` URL scheme, Raycast extension.

---

## Privacy

Everything runs locally. Georgie does not transmit screen contents or any of your data. The camera feed never leaves your machine.

---

## Distribution

Georgie is **free** and ships **outside the Mac App Store**: a Developer-ID-signed,
**notarized** app delivered as a DMG, with **Sparkle** for auto-updates. The
update feed (`appcast.xml`) and the release DMGs both live in this repository.

### Updates

Georgie checks for updates automatically (every few hours) and you can trigger a
check from **Check for Updates…** in the menu or the **About** tab. Each update is
EdDSA-signed; the matching public key is baked into the app's `Info.plist`
(`SUPublicEDKey`) and the private key lives in the maintainer's Keychain under the
`Georgie` account.

### Releasing (maintainer)

```bash
./scripts/release.sh 1.1        # set a new version, or omit to reuse the current one
```

The script archives, exports with Developer ID, re-signs with the Hardened Runtime,
builds a DMG, **notarizes + staples** it, **EdDSA-signs** it for Sparkle, appends an
item to `appcast.xml`, publishes a GitHub Release with the DMG, and pushes.

**Prerequisites:**

- A `notarytool` keychain profile named `Georgie-Notarize`
  (`xcrun notarytool store-credentials Georgie-Notarize …`), or override with
  `NOTARIZE_PROFILE=… ./scripts/release.sh`.
- The `Developer ID Application: Kevin Chromik (7HFRDKKUCK)` signing identity.
- `create-dmg` (`brew install create-dmg`).
- A Sparkle EdDSA key in the Keychain under the `Georgie` account (already generated).
- **The repository must be public** so Sparkle can fetch `appcast.xml` and the DMGs.

---

*Inspired by AlwaysOnTop and Floaty. Named, with affection and a healthy fear of storm drains, after Georgie Denbrough.*
