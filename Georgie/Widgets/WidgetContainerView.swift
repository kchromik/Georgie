import SwiftUI
import UniformTypeIdentifiers

struct WidgetContainerView: View {
    @Bindable var instance: WidgetInstance
    let manager: WidgetManager
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .top) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            WidgetChrome(instance: instance, manager: manager, visible: hovering)
        }
        .frame(minWidth: 200, minHeight: 150)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .background(HoverTracker { hovering = $0 })
        .onDrop(of: [.fileURL, .image, .url], isTargeted: nil, perform: handleDrop)
    }

    @ViewBuilder
    private var content: some View {
        switch instance.kind {
        case .web:    WebViewerView(instance: instance)
        case .pdf:    PDFViewerView(instance: instance)
        case .image:  ImageViewerView(instance: instance)
        case .video:  VideoViewerView(instance: instance)
        case .note:   ScratchpadView(instance: instance, manager: manager)
        case .camera: CameraViewerView(instance: instance)
        case .windowMirror: WindowMirrorView(instance: instance, manager: manager)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false

        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                handled = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in
                        if url.isFileURL {
                            loadFile(url)
                        } else {
                            manager.newWeb(url: url.absoluteString)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                handled = true
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data, let image = NSImage(data: data) else { return }
                    Task { @MainActor in
                        dropImage(image)
                    }
                }
            }
        }
        return handled
    }

    @MainActor
    private func loadFile(_ url: URL) {

        if WidgetKind.forFile(url) == instance.kind {
            instance.setFile(url)
        } else {
            manager.open(fileURL: url)
        }
    }

    @MainActor
    private func dropImage(_ image: NSImage) {
        if instance.kind == .image {
            instance.pasteboardImage = image
            instance.contentVersion += 1
        } else {
            manager.newImageFromPasteboardImage(image)
        }
    }
}

// SwiftUI's .onHover stops firing while the app is inactive, which is the
// normal state for these non-activating panels (e.g. right after session
// restore at login) — the chrome with the close button would never appear.
// An .activeAlways tracking area delivers hover events regardless.
private struct HoverTracker: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: TrackerView, context: Context) {
        nsView.onChange = onChange
    }

    final class TrackerView: NSView {
        var onChange: ((Bool) -> Void)?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func mouseEntered(with event: NSEvent) { onChange?(true) }
        override func mouseExited(with event: NSEvent) { onChange?(false) }
    }
}
