import SwiftUI
import AppKit

struct ImageViewerView: View {
    @Bindable var instance: WidgetInstance

    var body: some View {
        Group {
            if currentImage != nil {
                ImageScrollRepresentable(instance: instance)
            } else {
                WidgetPlaceholder(
                    symbol: "photo",
                    title: "No image loaded",
                    subtitle: "Drag an image here or paste it from the clipboard."
                )
            }
        }
    }

    private var currentImage: NSImage? {
        instance.pasteboardImage ?? instance.fileURL.flatMap { NSImage(contentsOf: $0) }
    }
}

private struct ImageScrollRepresentable: NSViewRepresentable {
    @Bindable var instance: WidgetInstance

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 8.0
        scrollView.drawsBackground = false

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.autoresizingMask = [.width, .height]
        scrollView.documentView = imageView

        context.coordinator.imageView = imageView
        update(scrollView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let version = instance.contentVersion
        if context.coordinator.loadedVersion != version {
            context.coordinator.loadedVersion = version
            update(nsView, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func update(_ scrollView: NSScrollView, coordinator: Coordinator) {
        let image = instance.pasteboardImage ?? instance.fileURL.flatMap { NSImage(contentsOf: $0) }
        coordinator.imageView?.image = image
        coordinator.imageView?.frame = scrollView.bounds
        scrollView.magnification = 1.0
    }

    final class Coordinator {
        var imageView: NSImageView?
        var loadedVersion = 0
    }
}
