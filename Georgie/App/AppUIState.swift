import Observation

enum SettingsTab: Hashable {
    case general
    case about
}

@MainActor
@Observable
final class AppUIState {
    var settingsTab: SettingsTab = .general
}
