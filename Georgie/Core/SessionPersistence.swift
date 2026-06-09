import Foundation

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
    var fileBookmark: Data?
}
