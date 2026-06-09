import Foundation
import Observation
import ServiceManagement
import OSLog

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
    var snapToEdges: Bool {
        didSet { defaults.set(snapToEdges, forKey: Keys.snap) }
    }

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let log = Logger(subsystem: "com.kchromik.Georgie", category: "settings")

    private enum Keys {
        static let opacity = "settings.defaultOpacity"
        static let level = "settings.defaultLevel"
        static let restore = "settings.restoreSession"
        static let snap = "settings.snapToEdges"
    }

    init() {
        defaults.register(defaults: [
            Keys.opacity: 1.0,
            Keys.level: FloatLevel.floating.rawValue,
            Keys.restore: true,
            Keys.snap: true,
        ])
        self.defaultOpacity = defaults.double(forKey: Keys.opacity)
        self.defaultLevel = FloatLevel(rawValue: defaults.string(forKey: Keys.level) ?? "") ?? .floating
        self.restoreSession = defaults.bool(forKey: Keys.restore)
        self.snapToEdges = defaults.bool(forKey: Keys.snap)
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Failed to set launch-at-login to \(enabled): \(error.localizedDescription)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
