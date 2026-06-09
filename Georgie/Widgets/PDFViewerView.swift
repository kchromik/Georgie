import SwiftUI
import PDFKit

struct PDFViewerView: View {
    @Bindable var instance: WidgetInstance

    var body: some View {
        Group {
            if instance.fileURL != nil {
                PDFKitRepresentable(instance: instance)
            } else {
                WidgetPlaceholder(
                    symbol: "doc.richtext",
                    title: "No PDF loaded",
                    subtitle: "Drag a PDF file here or open one from the menu."
                )
            }
        }
    }
}

private struct PDFKitRepresentable: NSViewRepresentable {
    @Bindable var instance: WidgetInstance

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        load(into: view)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {

        let version = instance.contentVersion
        if context.coordinator.loadedVersion != version {
            context.coordinator.loadedVersion = version
            load(into: nsView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func load(into view: PDFView) {
        guard let url = instance.fileURL, let document = PDFDocument(url: url) else { return }
        view.document = document
    }

    final class Coordinator {
        var loadedVersion = 0
    }
}
