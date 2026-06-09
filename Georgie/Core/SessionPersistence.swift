import Foundation

// Skips snapshots that no longer decode (e.g. widget kinds that were removed
// from the app) instead of failing the whole session restore.
struct FailableSnapshot: Decodable {
    let value: WidgetSnapshot?

    init(from decoder: Decoder) {
        value = try? WidgetSnapshot(from: decoder)
    }
}

struct WidgetSnapshot: Codable {
    var id: UUID
    var kind: WidgetKind
    var title: String
    var opacity: Double
    var level: FloatLevel
    var clickThrough: Bool
    var frame: CGRect?
    var urlString: String
    var text: String
    var cameraDeviceID: String?
    var webZoom: Double?
    var webReloadInterval: Double?
    var cameraMirrored: Bool?
    var noteRendered: Bool?
    var fileBookmark: Data?
}
