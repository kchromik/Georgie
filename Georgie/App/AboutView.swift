import SwiftUI

struct AboutView: View {
    @Bindable var updater: UpdaterService

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 14) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 84, height: 84)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 3) {
                Text(verbatim: "Georgie")
                    .font(.title2.weight(.semibold))
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Float any window — web, PDF, image, video, a note, or your camera — always on top, with adjustable opacity and click-through.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(!updater.canCheckForUpdates)

                Toggle("Check for updates automatically", isOn: $updater.automaticallyChecksForUpdates)
                    .toggleStyle(.checkbox)
                    .font(.callout)
            }
            .padding(.horizontal, 8)

            HStack(spacing: 14) {
                Link("Website", destination: URL(string: "https://github.com/kchromik/Georgie")!)
                Link("Support", destination: URL(string: "https://github.com/kchromik/Georgie/issues")!)
            }
            .font(.callout)

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text(verbatim: "\u{00A9} 2026 Kevin Chromik")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Auto-updates powered by Sparkle.")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(20)
        .frame(width: 380, height: 420)
    }
}
