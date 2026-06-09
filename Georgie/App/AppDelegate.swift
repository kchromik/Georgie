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

    func applicationWillTerminate(_ notification: Notification) {
        manager.persist()
    }
}
