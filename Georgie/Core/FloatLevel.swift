import AppKit

enum FloatLevel: String, Codable, CaseIterable, Identifiable {

    case normal

    case floating

    case top

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal:   return String(localized: "Normal")
        case .floating: return String(localized: "Always on Top")
        case .top:      return String(localized: "Top Most")
        }
    }

    var nsLevel: NSWindow.Level {
        switch self {
        case .normal:   return .normal
        case .floating: return .floating
        case .top:      return .modalPanel
        }
    }
}
