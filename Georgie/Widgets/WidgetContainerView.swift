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
        .onHover { hovering = $0 }
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
