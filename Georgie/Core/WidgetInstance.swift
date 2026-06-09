import AppKit
import Observation

@MainActor
@Observable
final class WidgetInstance: Identifiable {
    let id: UUID
    let kind: WidgetKind

    var title: String

    var opacity: Double
    var level: FloatLevel
    var clickThrough: Bool
    var frame: CGRect?

    var urlString: String = ""

    var text: String = ""

    var contentVersion: Int = 0

    @ObservationIgnored var fileURL: URL?
    @ObservationIgnored var fileBookmark: Data?
    @ObservationIgnored var pasteboardImage: NSImage?

    init(kind: WidgetKind, settings: SettingsStore) {
        self.id = UUID()
        self.kind = kind
        self.title = kind.displayName
        self.opacity = settings.defaultOpacity
        self.level = settings.defaultLevel
        self.clickThrough = false
    }

    init(snapshot: WidgetSnapshot) {
        self.id = snapshot.id
        self.kind = snapshot.kind
        self.title = snapshot.title
        self.opacity = snapshot.opacity
        self.level = snapshot.level
        self.clickThrough = snapshot.clickThrough
        self.frame = snapshot.frame
        self.urlString = snapshot.urlString
        self.text = snapshot.text
        self.fileBookmark = snapshot.fileBookmark
        resolveBookmarkIfNeeded()
    }

    func setFile(_ url: URL) {
        fileURL = url
        title = url.deletingPathExtension().lastPathComponent
        fileBookmark = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        contentVersion += 1
    }

    private func resolveBookmarkIfNeeded() {
        guard let data = fileBookmark else { return }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return }
        fileURL = url
    }

    var snapshot: WidgetSnapshot {
        WidgetSnapshot(
            id: id,
            kind: kind,
            title: title,
            opacity: opacity,
            level: level,
            clickThrough: clickThrough,
            frame: frame,
            urlString: urlString,
            text: text,
            fileBookmark: fileBookmark
        )
    }

    var isRestorable: Bool {
        switch kind {
        case .web, .note, .camera:
            return true
        case .pdf, .image, .video:
            return fileBookmark != nil
        }
    }
}
