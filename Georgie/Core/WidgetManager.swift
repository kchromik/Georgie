import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class WidgetManager {

    private(set) var widgets: [WidgetInstance] = []

    @ObservationIgnored private var controllers: [UUID: FloatingPanelController] = [:]
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    @ObservationIgnored private var isTerminating = false

    let settings = SettingsStore()

    private let sessionKey = "session.widgets"

    @discardableResult
    func newWeb(url: String? = nil) -> WidgetInstance {
        let instance = WidgetInstance(kind: .web, settings: settings)
        if let url { instance.urlString = url }
        return present(instance)
    }

    @discardableResult
    func newNote() -> WidgetInstance {
        present(WidgetInstance(kind: .note, settings: settings))
    }

    @discardableResult
    func newCamera() -> WidgetInstance {
        present(WidgetInstance(kind: .camera, settings: settings))
    }

    @discardableResult
    func newWindowMirror() -> WidgetInstance {
        present(WidgetInstance(kind: .windowMirror, settings: settings))
    }

    @discardableResult
    func open(fileURL: URL) -> WidgetInstance? {
        guard let kind = WidgetKind.forFile(fileURL) else { return nil }
        let instance = WidgetInstance(kind: kind, settings: settings)
        instance.setFile(fileURL)
        return present(instance)
    }

    func newImageFromPasteboard() {
        guard let image = NSImage(pasteboard: .general) else {
            NSSound.beep()
            return
        }
        newImageFromPasteboardImage(image)
    }

    func newImageFromPasteboardImage(_ image: NSImage) {
        let instance = WidgetInstance(kind: .image, settings: settings)
        instance.pasteboardImage = image
        instance.title = String(localized: "Image")
        present(instance)
    }

    @discardableResult
    private func present(_ instance: WidgetInstance) -> WidgetInstance {
        widgets.append(instance)
        let controller = FloatingPanelController(instance: instance, manager: self)
        controllers[instance.id] = controller
        controller.show()
        scheduleAutosave()
        return instance
    }

    func focus(_ instance: WidgetInstance) {
        controllers[instance.id]?.show()
    }

    func close(_ instance: WidgetInstance) {
        controllers[instance.id]?.closePanel()

    }

    func closeAll() {
        for controller in controllers.values {
            controller.closePanel()
        }
    }

    func handlePanelClosed(_ id: UUID) {
        // AppKit closes every panel while the app terminates; treating that as
        // the user closing widgets would wipe the saved session.
        guard !isTerminating else { return }
        guard controllers[id] != nil else { return }
        controllers[id] = nil
        widgets.removeAll { $0.id == id }
        scheduleAutosave()
    }

    func clickThroughBinding(for instance: WidgetInstance) -> Bool {
        instance.clickThrough
    }

    func setClickThrough(_ value: Bool, for instance: WidgetInstance) {
        instance.clickThrough = value
    }

    func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    func prepareForTermination() {
        persist()
        isTerminating = true
    }

    func persist() {
        guard !isTerminating else { return }
        guard settings.restoreSession else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
            return
        }
        let snapshots = widgets.filter(\.isRestorable).map(\.snapshot)
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    func restoreIfEnabled() {
        guard settings.restoreSession else { return }
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let wrapped = try? JSONDecoder().decode([FailableSnapshot].self, from: data)
        else { return }
        let snapshots = wrapped.compactMap(\.value)

        for snapshot in snapshots {
            let instance = WidgetInstance(snapshot: snapshot)
            guard instance.isRestorable else { continue }
            widgets.append(instance)
            let controller = FloatingPanelController(instance: instance, manager: self)
            controllers[instance.id] = controller
            controller.orderFront()
        }
    }
}
