import Foundation

/// Days are stored as `yyyy-MM-dd` strings in the user's own time zone —
/// simple to sort, simple to read in an export, no time-zone drift in history.
enum DayKey {
    /// Hours past midnight that still belong to the night before. Logging at
    /// 1:15am is the end of yesterday, not a skipped day and a fresh one.
    static let lateNightCutoffHour = 4

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func key(for date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        formatter.date(from: key)
    }

    /// The day a check-in made *now* belongs to.
    static func currentKey(now: Date = Date()) -> String {
        key(for: now.addingTimeInterval(-Double(lateNightCutoffHour) * 3600))
    }

    /// True when the clock has passed midnight but the check-in still counts
    /// for yesterday — worth saying out loud in the UI so it isn't confusing.
    static func isAfterMidnightGrace(now: Date = Date()) -> Bool {
        key(for: now) != currentKey(now: now)
    }

    static func shifting(_ key: String, byDays days: Int) -> String? {
        guard let date = date(from: key),
              let shifted = Calendar.current.date(byAdding: .day, value: days, to: date) else { return nil }
        return self.key(for: shifted)
    }

    static func previous(_ key: String) -> String? { shifting(key, byDays: -1) }
}
