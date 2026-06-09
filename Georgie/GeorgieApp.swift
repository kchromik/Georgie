import SwiftUI

@main
struct GeorgieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Georgie", systemImage: "pip.fill") {
            AppMenu(manager: delegate.manager, updater: delegate.updater, uiState: delegate.uiState)
        }

        Settings {
            SettingsView(
                settings: delegate.manager.settings,
                updater: delegate.updater,
                uiState: delegate.uiState
            )
        }
    }
}
