import AppKit
import SwiftUI
import Observation

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    let instance: WidgetInstance
    private weak var manager: WidgetManager?
    let panel: FloatingPanel

    private var clickThroughMonitors: [Any] = []

    private let chromeStripHeight: CGFloat = 56

    init(instance: WidgetInstance, manager: WidgetManager) {
        self.instance = instance
        self.manager = manager

        let frame = instance.frame ?? Self.defaultFrame(for: instance.kind)
        self.panel = FloatingPanel(contentRect: frame)

        super.init()

        panel.delegate = self

        let host = NSHostingView(
            rootView: WidgetContainerView(instance: instance, manager: manager)
        )
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        applyWindowProperties()
        observeInstance()
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func orderFront() {
        panel.orderFrontRegardless()
    }

    func closePanel() {
        panel.close()
    }

    private func applyWindowProperties() {
        panel.alphaValue = instance.opacity
        panel.level = instance.level.nsLevel
        panel.title = instance.title
        applyClickThrough()
    }

    private func applyClickThrough() {
        if instance.clickThrough {
            if clickThroughMonitors.isEmpty { installClickThroughMonitors() }
            updateClickThroughRegion()
        } else {
            removeClickThroughMonitors()
            panel.ignoresMouseEvents = false
        }
    }

    private func installClickThroughMonitors() {

        let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateClickThroughRegion() }
        }

        let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            MainActor.assumeIsolated { self?.updateClickThroughRegion() }
            return event
        }
        clickThroughMonitors = [global, local].compactMap { $0 }
    }

    private func removeClickThroughMonitors() {
        for monitor in clickThroughMonitors { NSEvent.removeMonitor(monitor) }
        clickThroughMonitors.removeAll()
    }

    private func updateClickThroughRegion() {
        guard instance.clickThrough else { return }
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let strip = NSRect(
            x: frame.minX,
            y: frame.maxY - chromeStripHeight,
            width: frame.width,
            height: chromeStripHeight
        )
        panel.ignoresMouseEvents = !strip.contains(mouse)
    }

    private func observeInstance() {
        withObservationTracking {
            _ = instance.opacity
            _ = instance.level
            _ = instance.clickThrough
            _ = instance.title
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyWindowProperties()
                self.observeInstance()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        saveFrame()
        removeClickThroughMonitors()
        manager?.handlePanelClosed(instance.id)
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
        manager?.scheduleAutosave()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveFrame()
        manager?.scheduleAutosave()
    }

    private func saveFrame() {
        instance.frame = panel.frame
    }

    private static func defaultFrame(for kind: WidgetKind) -> NSRect {
        let size = kind.defaultSize
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let x = screen.maxX - size.width - 40
        let y = screen.maxY - size.height - 40
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
