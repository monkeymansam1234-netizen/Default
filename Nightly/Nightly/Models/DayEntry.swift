import Foundation

/// One night's check-in. An entry with no answers and no note is still a
/// valid entry — showing up counts, and the streak treats it that way.
struct DayEntry: Codable, Identifiable, Hashable {
    var dayKey: String
    var answers: [String: Rating]
    var note: String
    var loggedAt: Date
    var updatedAt: Date

    var id: String { dayKey }

    init(dayKey: String,
         answers: [String: Rating] = [:],
         note: String = "",
         loggedAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.dayKey = dayKey
        self.answers = answers
        self.note = note
        self.loggedAt = loggedAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        answers = try container.decodeIfPresent([String: Rating].self, forKey: .answers) ?? [:]
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        loggedAt = try container.decodeIfPresent(Date.self, forKey: .loggedAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? loggedAt
    }

    var date: Date? { DayKey.date(from: dayKey) }

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var hasContent: Bool { !answers.isEmpty || !trimmedNote.isEmpty }

    /// Average of everything answered, 0...1. `nil` when the night was
    /// logged without answering anything.
    var score: Double? {
        guard !answers.isEmpty else { return nil }
        let total = answers.values.reduce(0.0) { $0 + $1.normalized }
        return total / Double(answers.count)
    }

    /// A one-line read on the day, phrased so a bad day never sounds like a verdict.
    var summary: String {
        guard let score else {
            return trimmedNote.isEmpty ? "Logged. That counts." : "Noted. That counts."
        }
        switch score {
        case 0.85...: return "Sounds like a good one."
        case 0.6..<0.85: return "Mostly a decent day."
        case 0.4..<0.6: return "A mixed one. Fair enough."
        case 0.15..<0.4: return "Rough day — you still showed up."
        default: return "Hard day. Logging it anyway is the win."
        }
    }
}
