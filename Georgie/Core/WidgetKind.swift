import Foundation
import UniformTypeIdentifiers

enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case web
    case pdf
    case image
    case video
    case note
    case camera

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .web:    return String(localized: "Web")
        case .pdf:    return String(localized: "PDF")
        case .image:  return String(localized: "Image")
        case .video:  return String(localized: "Video")
        case .note:   return String(localized: "Note")
        case .camera: return String(localized: "Camera")
        }
    }

    var symbol: String {
        switch self {
        case .web:    return "globe"
        case .pdf:    return "doc.richtext"
        case .image:  return "photo"
        case .video:  return "film"
        case .note:   return "note.text"
        case .camera: return "camera"
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .web:    return CGSize(width: 520, height: 640)
        case .pdf:    return CGSize(width: 520, height: 680)
        case .image:  return CGSize(width: 480, height: 360)
        case .video:  return CGSize(width: 560, height: 340)
        case .note:   return CGSize(width: 360, height: 320)
        case .camera: return CGSize(width: 360, height: 270)
        }
    }

    static func forFile(_ url: URL) -> WidgetKind? {
        if let type = UTType(filenameExtension: url.pathExtension) {
            if type.conforms(to: .pdf) { return .pdf }
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .audiovisualContent) || type.conforms(to: .movie) { return .video }
            if type.conforms(to: .html) { return .web }
        }

        switch url.pathExtension.lowercased() {
        case "pdf": return .pdf
        case "png", "jpg", "jpeg", "gif", "heic", "tiff", "bmp", "webp": return .image
        case "mp4", "mov", "m4v", "avi", "mkv", "mp3", "m4a", "wav": return .video
        case "html", "htm": return .web
        default: return nil
        }
    }
}
