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
    private let snapThreshold: CGFloat = 14
    private var isSnapping = false
    private var pendingSnapTask: Task<Void, Never>?

    init(instance: WidgetInstance, manager: WidgetManager) {
        self.instance = instance
        self.manager = manager

        let frame = instance.frame ?? Self.defaultFrame(for: instance.kind)
        self.panel = FloatingPanel(contentRect: frame)

        super.init()

        panel.delegate = self

        let host = FirstMouseHostingView(
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
        pendingSnapTask?.cancel()
        pendingSnapTask = nil
        saveFrame()
        removeClickThroughMonitors()
        // Drop the hosting view immediately so widget content (e.g. a WKWebView
        // playing audio) is torn down with the panel instead of lingering.
        panel.contentView = nil
        manager?.handlePanelClosed(instance.id)
    }

    func windowDidMove(_ notification: Notification) {
        // While the user is still dragging, the window server keeps moving the
        // window with the mouse and stomps any programmatic reposition — so a
        // snap applied mid-drag never sticks. Defer it to mouse release.
        if NSEvent.pressedMouseButtons & 1 != 0 {
            scheduleSnapAfterDrag()
        } else {
            snapToEdgesIfNeeded()
        }
        saveFrame()
        manager?.scheduleAutosave()
    }

    private func scheduleSnapAfterDrag() {
        guard pendingSnapTask == nil else { return }
        pendingSnapTask = Task { [weak self] in
            while NSEvent.pressedMouseButtons & 1 != 0, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
            }
            guard let self, !Task.isCancelled else { return }
            self.pendingSnapTask = nil
            self.snapToEdgesIfNeeded()
            self.saveFrame()
            self.manager?.scheduleAutosave()
        }
    }

    private func snapToEdgesIfNeeded() {
        guard !isSnapping else { return }
        guard manager?.settings.snapToEdges ?? true else { return }
        guard let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }

        var origin = panel.frame.origin
        let size = panel.frame.size
        var moved = false

        // Snap only while approaching an edge from inside the visible frame.
        // Snapping on the outside too would re-anchor the drag on every move
        // and make it impossible to shove a panel past the screen edge.
        let fromLeft = origin.x - visible.minX
        let fromRight = visible.maxX - (origin.x + size.width)
        if fromLeft >= 0, fromLeft <= snapThreshold {
            origin.x = visible.minX; moved = true
        } else if fromRight >= 0, fromRight <= snapThreshold {
            origin.x = visible.maxX - size.width; moved = true
        }

        let fromBottom = origin.y - visible.minY
        let fromTop = visible.maxY - (origin.y + size.height)
        if fromBottom >= 0, fromBottom <= snapThreshold {
            origin.y = visible.minY; moved = true
        } else if fromTop >= 0, fromTop <= snapThreshold {
            origin.y = visible.maxY - size.height; moved = true
        }

        guard moved else { return }
        isSnapping = true
        panel.setFrameOrigin(origin)
        isSnapping = false
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

// Lets controls respond to the first click even when the app is inactive,
// which is the usual state for these non-activating panels.
// Deliberately non-generic: a generic NSHostingView subclass crashes the
// Swift optimizer (EarlyPerfInliner) in Release builds.
private final class FirstMouseHostingView: NSHostingView<WidgetContainerView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
