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
    private let snapThreshold: CGFloat = 32
    private let snapBackZone: CGFloat = 48
    private let minVisibleSliver: CGFloat = 24
    private let edgePadding: CGFloat = 12
    private let throwSpeedThreshold: CGFloat = 350
    private let throwAxisThreshold: CGFloat = 200
    private var isSnapping = false
    private var pendingSnapTask: Task<Void, Never>?
    private var dragSamples: [(time: TimeInterval, point: NSPoint)] = []

    init(instance: WidgetInstance, manager: WidgetManager) {
        self.instance = instance
        self.manager = manager

        let frame = Self.rescuedIfLost(instance.frame ?? Self.defaultFrame(for: instance.kind))
        self.panel = FloatingPanel(contentRect: frame)

        super.init()

        panel.delegate = self

        let host = FirstMouseHostingView(
            rootView: WidgetContainerView(instance: instance, manager: manager)
        )
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        panel.onLeftMouseDown = { [weak self] in
            self?.scheduleSnapAfterDrag()
        }

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
        } else if !isSnapping {
            snapToEdgesIfNeeded()
        }
        if !isSnapping {
            saveFrame()
            manager?.scheduleAutosave()
        }
    }

    // The mouse is sampled directly on a fixed cadence while the button is
    // held — windowDidMove arrives far too sporadically during server-side
    // drags to derive a usable release velocity from it.
    private func recordDragSample() {
        dragSamples.append((ProcessInfo.processInfo.systemUptime, NSEvent.mouseLocation))
        if dragSamples.count > 20 {
            dragSamples.removeFirst(dragSamples.count - 20)
        }
    }

    private func scheduleSnapAfterDrag() {
        guard pendingSnapTask == nil else { return }
        dragSamples.removeAll()
        let startOrigin = panel.frame.origin
        pendingSnapTask = Task { [weak self] in
            while NSEvent.pressedMouseButtons & 1 != 0, !Task.isCancelled {
                self?.recordDragSample()
                try? await Task.sleep(for: .milliseconds(8))
            }
            guard let self, !Task.isCancelled else { return }
            self.pendingSnapTask = nil
            let velocity = self.releaseVelocity()
            self.dragSamples.removeAll()
            // Tracking starts on mouse-down, so plain clicks land here too.
            guard self.panel.frame.origin != startOrigin else { return }
            if !self.throwToEdgeIfNeeded(velocity: velocity) {
                self.snapToEdgesIfNeeded()
            }
            self.saveFrame()
            self.manager?.scheduleAutosave()
        }
    }

    // Velocity over the final stretch of the drag; a pause before releasing
    // yields near-zero displacement, so only genuine flicks count as throws.
    private func releaseVelocity() -> CGVector {
        guard let lastTime = dragSamples.last?.time else { return .zero }
        let recent = dragSamples.filter { lastTime - $0.time < 0.12 }
        guard let first = recent.first, let last = recent.last,
              last.time - first.time > 0.012
        else { return .zero }
        let dt = last.time - first.time
        return CGVector(
            dx: (last.point.x - first.point.x) / dt,
            dy: (last.point.y - first.point.y) / dt
        )
    }

    // PiP-style: a flicked panel glides to the edge (or corner, when thrown
    // diagonally) it was thrown toward.
    private func throwToEdgeIfNeeded(velocity: CGVector) -> Bool {
        guard manager?.settings.snapToEdges ?? true else { return false }
        guard hypot(velocity.dx, velocity.dy) > throwSpeedThreshold else { return false }
        guard let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return false }

        let size = panel.frame.size
        var target = panel.frame.origin
        if abs(velocity.dx) > throwAxisThreshold {
            target.x = velocity.dx > 0 ? visible.maxX - size.width - edgePadding : visible.minX + edgePadding
        }
        if abs(velocity.dy) > throwAxisThreshold {
            target.y = velocity.dy > 0 ? visible.maxY - size.height - edgePadding : visible.minY + edgePadding
        }
        guard target != panel.frame.origin else { return false }

        let distance = hypot(target.x - panel.frame.origin.x, target.y - panel.frame.origin.y)
        isSnapping = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = min(0.32, max(0.16, distance / 2200))
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(NSRect(origin: target, size: size), display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isSnapping = false
                self.saveFrame()
                self.manager?.scheduleAutosave()
            }
        }
        return true
    }

    // Runs after the mouse is released. constrainFrameRect is NOT consulted
    // during server-side drags, so this is the only reliable place to apply
    // edge magnetism and the keep-a-sliver-visible parking guard.
    private func snapToEdgesIfNeeded() {
        guard !isSnapping else { return }
        guard let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }

        let snapEnabled = manager?.settings.snapToEdges ?? true
        var origin = panel.frame.origin
        let size = panel.frame.size
        var moved = false

        // Magnetic band per edge: from `snapBackZone` outside the edge to
        // `snapThreshold` inside it. Dropped further outside than the band
        // counts as deliberate parking; then only the minimum visible sliver
        // is enforced so the panel can always be grabbed again.
        func resolve(_ position: CGFloat, span: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat? {
            let fromLower = position - lower
            let fromUpper = upper - (position + span)
            if snapEnabled, fromLower > -snapBackZone, fromLower <= snapThreshold {
                return lower + edgePadding
            }
            if snapEnabled, fromUpper > -snapBackZone, fromUpper <= snapThreshold {
                return upper - span - edgePadding
            }
            let clamped = min(max(position, lower - span + minVisibleSliver), upper - minVisibleSliver)
            return clamped == position ? nil : clamped
        }

        if let x = resolve(origin.x, span: size.width, lower: visible.minX, upper: visible.maxX) {
            origin.x = x; moved = true
        }
        if let y = resolve(origin.y, span: size.height, lower: visible.minY, upper: visible.maxY) {
            origin.y = y; moved = true
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

    // A saved frame can end up (almost) fully offscreen — e.g. dragged out by
    // accident or a display was unplugged. Deliberately parked panels keep at
    // least the 24pt sliver, so anything below 20pt visible counts as lost
    // and gets recentered on the main screen.
    private static func rescuedIfLost(_ frame: NSRect) -> NSRect {
        let minVisible: CGFloat = 20
        for screen in NSScreen.screens {
            let overlap = frame.intersection(screen.visibleFrame)
            if overlap.width >= minVisible, overlap.height >= minVisible {
                return frame
            }
        }
        guard let visible = NSScreen.main?.visibleFrame else { return frame }
        return NSRect(
            x: visible.midX - frame.width / 2,
            y: visible.midY - frame.height / 2,
            width: frame.width,
            height: frame.height
        )
    }
}

// Lets controls respond to the first click even when the app is inactive,
// which is the usual state for these non-activating panels.
// Deliberately non-generic: a generic NSHostingView subclass crashes the
// Swift optimizer (EarlyPerfInliner) in Release builds.
private final class FirstMouseHostingView: NSHostingView<WidgetContainerView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
