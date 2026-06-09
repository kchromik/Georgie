import AppKit

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow

        // The controller owns this panel via a strong reference; NSPanel's
        // default of releasing itself on close would over-release it.
        isReleasedWhenClosed = false

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        minSize = NSSize(width: 200, height: 150)
    }

    override var canBecomeKey: Bool { true }

    override var canBecomeMain: Bool { false }

    // Panels may be parked mostly offscreen at any edge; only keep a small
    // sliver visible so they can always be grabbed and dragged back.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let visible = (screen ?? self.screen ?? NSScreen.main)?.visibleFrame else {
            return frameRect
        }
        let peek: CGFloat = 24
        var rect = frameRect
        rect.origin.x = min(max(rect.origin.x, visible.minX - rect.width + peek), visible.maxX - peek)
        rect.origin.y = min(max(rect.origin.y, visible.minY - rect.height + peek), visible.maxY - peek)
        return rect
    }
}
