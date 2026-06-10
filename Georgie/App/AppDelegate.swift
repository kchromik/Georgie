import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = WidgetManager()
    let updater = UpdaterService()
    let uiState = AppUIState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        manager.restoreIfEnabled()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.isFileURL {
            manager.open(fileURL: url)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Persist before AppKit starts closing panels — their close callbacks
        // would otherwise empty the widget list and overwrite the session.
        manager.prepareForTermination()
        return .terminateNow
    }
}
