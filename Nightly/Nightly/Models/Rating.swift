import SwiftUI

/// The only answer a question ever takes: three taps, no typing, no sliders.
/// Deliberately gentle wording — nothing here should feel like a grade.
enum Rating: Int, Codable, CaseIterable, Identifiable, Hashable {
    case rough = -1
    case okay = 0
    case good = 1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .rough: return "Not really"
        case .okay: return "Kind of"
        case .good: return "Yeah"
        }
    }

    /// Weather instead of faces or thumbs: a rainy day isn't a failing grade.
    var symbolName: String {
        switch self {
        case .rough: return "cloud.rain.fill"
        case .okay: return "cloud.sun.fill"
        case .good: return "sun.max.fill"
        }
    }

    var tint: Color {
        switch self {
        case .rough: return Color(red: 0.42, green: 0.55, blue: 0.80)
        case .okay: return Color(red: 0.86, green: 0.68, blue: 0.36)
        case .good: return Color(red: 0.36, green: 0.72, blue: 0.55)
        }
    }

    /// 0...1, so a day's answers can be averaged.
    var normalized: Double { (Double(rawValue) + 1) / 2 }
}
