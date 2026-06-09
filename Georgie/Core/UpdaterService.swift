import AppKit
import Observation
import Sparkle

private final class GentleUpdaterDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {

        if handleShowingUpdate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@MainActor
@Observable
final class UpdaterService {
    @ObservationIgnored let controller: SPUStandardUpdaterController
    @ObservationIgnored private let driverDelegate: GentleUpdaterDriverDelegate
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    var canCheckForUpdates: Bool = true

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    init() {
        let driverDelegate = GentleUpdaterDriverDelegate()
        self.driverDelegate = driverDelegate
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: driverDelegate
        )
        controller.updater.automaticallyChecksForUpdates = true
        controller.updater.updateCheckInterval = 4 * 60 * 60
        controller.startUpdater()

        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] updater, change in
            let value = change.newValue ?? updater.canCheckForUpdates
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = value
            }
        }
    }

    func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}
