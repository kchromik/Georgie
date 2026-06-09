import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    var defaultOpacity: Double {
        didSet { defaults.set(defaultOpacity, forKey: Keys.opacity) }
    }
    var defaultLevel: FloatLevel {
        didSet { defaults.set(defaultLevel.rawValue, forKey: Keys.level) }
    }
    var restoreSession: Bool {
        didSet { defaults.set(restoreSession, forKey: Keys.restore) }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Keys {
        static let opacity = "settings.defaultOpacity"
        static let level = "settings.defaultLevel"
        static let restore = "settings.restoreSession"
    }

    init() {
        defaults.register(defaults: [
            Keys.opacity: 1.0,
            Keys.level: FloatLevel.floating.rawValue,
            Keys.restore: true,
        ])
        self.defaultOpacity = defaults.double(forKey: Keys.opacity)
        self.defaultLevel = FloatLevel(rawValue: defaults.string(forKey: Keys.level) ?? "") ?? .floating
        self.restoreSession = defaults.bool(forKey: Keys.restore)
    }
}
