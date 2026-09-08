import Foundation

enum Formatting {
    /// "Saturday, September 6"
    static func longDate(from dayKey: String) -> String {
        guard let date = DayKey.date(from: dayKey) else { return dayKey }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return formatter.string(from: date)
    }

    /// "Sat, Sep 6" — for tighter rows.
    static func shortDate(from dayKey: String) -> String {
        guard let date = DayKey.date(from: dayKey) else { return dayKey }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return formatter.string(from: date)
    }

    /// "Tonight" / "Yesterday" / the date, whichever reads most naturally.
    static func relativeDay(from dayKey: String, todayKey: String) -> String {
        if dayKey == todayKey { return "Tonight" }
        if dayKey == DayKey.previous(todayKey) { return "Yesterday" }
        return shortDate(from: dayKey)
    }
}
