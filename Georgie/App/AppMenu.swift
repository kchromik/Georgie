import SwiftUI
import UniformTypeIdentifiers

struct AppMenu: View {
    let manager: WidgetManager
    let updater: UpdaterService
    let uiState: AppUIState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Web Window") { manager.newWeb() }
        Button("Note") { manager.newNote() }
        Button("Camera") { manager.newCamera() }
        Button("Mirror Window") { manager.newWindowMirror() }

        Divider()

        Button("Open PDF…") { openFile(types: [.pdf]) }
        Button("Open Image…") { openFile(types: [.image]) }
        Button("Open Video…") { openFile(types: [.movie, .audiovisualContent]) }
        Button("Image from Clipboard") { manager.newImageFromPasteboard() }

        if !manager.widgets.isEmpty {
            Divider()
            Section("Open Windows") {
                ForEach(manager.widgets) { widget in
                    Menu(menuTitle(for: widget)) {
                        Button("Bring to Front") { manager.focus(widget) }
                        Toggle("Click-Through", isOn: Binding(
                            get: { widget.clickThrough },
                            set: { widget.clickThrough = $0 }
                        ))
                        Divider()
                        Button("Close") { manager.close(widget) }
                    }
                }
            }
            Button("Close All") { manager.closeAll() }
        }

        Divider()

        Button("Settings…") {
            openSettings(tab: .general)
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Check for Updates…") { updater.checkForUpdates() }

        Button("About Georgie") {
            openSettings(tab: .about)
        }

        Divider()

        Button("Quit Georgie") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    private func openSettings(tab: SettingsTab) {
        uiState.settingsTab = tab
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private func menuTitle(for widget: WidgetInstance) -> String {
        "\(widget.kind.displayName): \(widget.title)"
    }

    private func openFile(types: [UTType]) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = types
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            for url in panel.urls {
                manager.open(fileURL: url)
            }
        }
    }
}
