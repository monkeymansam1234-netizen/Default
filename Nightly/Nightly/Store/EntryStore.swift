import Foundation
import SwiftUI

/// Everything lives in two small JSON files in Application Support.
/// No account, no sync, no network — the app works in airplane mode at 1am.
final class EntryStore: ObservableObject {
    @Published private(set) var entries: [String: DayEntry]
    @Published var settings: AppSettings {
        didSet { settingsChanged(from: oldValue) }
    }
    /// The day new check-ins land on. Re-read whenever the app comes forward.
    @Published private(set) var todayKey: String

    private let entriesURL: URL
    private let settingsURL: URL

    init(directory: URL? = nil) {
        let folder = directory ?? EntryStore.defaultDirectory()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        entriesURL = folder.appendingPathComponent("entries.json")
        settingsURL = folder.appendingPathComponent("settings.json")

        entries = EntryStore.loadEntries(from: entriesURL)
        var loaded = EntryStore.loadSettings(from: settingsURL)
        loaded.mergeInNewBuiltIns()
        settings = loaded
        todayKey = DayKey.currentKey()
    }

    // MARK: - Reading

    var todayEntry: DayEntry? { entries[todayKey] }

    var hasLoggedToday: Bool { todayEntry != nil }

    func entry(for dayKey: String) -> DayEntry? { entries[dayKey] }

    func rating(for promptID: String, on dayKey: String) -> Rating? {
        entries[dayKey]?.answers[promptID]
    }

    var entriesByRecency: [DayEntry] {
        entries.values.sorted { $0.dayKey > $1.dayKey }
    }

    /// Consecutive logged days. If today isn't in yet the count runs back from
    /// yesterday, so the number doesn't read as 0 all day and shame you into it.
    var streak: Int {
        var cursor = todayKey
        if entries[cursor] == nil {
            guard let yesterday = DayKey.previous(cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while entries[cursor] != nil {
            count += 1
            guard let previous = DayKey.previous(cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Day keys ending with today, oldest first — the history grid's backbone.
    func recentDayKeys(days: Int) -> [String] {
        var keys: [String] = []
        var cursor = todayKey
        for _ in 0..<max(days, 1) {
            keys.append(cursor)
            guard let previous = DayKey.previous(cursor) else { break }
            cursor = previous
        }
        return keys.reversed()
    }

    /// Share of good-ish answers for one question over a window, 0...1.
    /// `nil` when the question was never answered in that window.
    func positivity(for promptID: String, days: Int) -> Double? {
        let ratings = recentDayKeys(days: days).compactMap { entries[$0]?.answers[promptID] }
        guard !ratings.isEmpty else { return nil }
        return ratings.reduce(0.0) { $0 + $1.normalized } / Double(ratings.count)
    }

    func answeredCount(for promptID: String, days: Int) -> Int {
        recentDayKeys(days: days).filter { entries[$0]?.answers[promptID] != nil }.count
    }

    // MARK: - Writing

    func setRating(_ rating: Rating?, for promptID: String, on dayKey: String) {
        var entry = entries[dayKey] ?? DayEntry(dayKey: dayKey)
        if let rating {
            entry.answers[promptID] = rating
        } else {
            entry.answers.removeValue(forKey: promptID)
        }
        entry.updatedAt = Date()
        entries[dayKey] = entry
        saveEntries()
    }

    /// Tapping the same answer twice clears it — no long-press, no undo menu.
    func toggleRating(_ rating: Rating, for promptID: String, on dayKey: String) {
        let current = self.rating(for: promptID, on: dayKey)
        setRating(current == rating ? nil : rating, for: promptID, on: dayKey)
    }

    func setNote(_ note: String, on dayKey: String) {
        let existing = entries[dayKey]
        // Don't create an entry just because an empty note field lost focus.
        if existing == nil && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        guard existing?.note != note else { return }
        var entry = existing ?? DayEntry(dayKey: dayKey)
        entry.note = note
        entry.updatedAt = Date()
        entries[dayKey] = entry
        saveEntries()
    }

    /// The "done" tap: guarantees the night is on record even if nothing was answered.
    @discardableResult
    func markLogged(_ dayKey: String) -> DayEntry {
        var entry = entries[dayKey] ?? DayEntry(dayKey: dayKey)
        entry.updatedAt = Date()
        entries[dayKey] = entry
        saveEntries()
        return entry
    }

    func deleteEntry(for dayKey: String) {
        entries.removeValue(forKey: dayKey)
        saveEntries()
    }

    func deleteAllEntries() {
        entries.removeAll()
        saveEntries()
    }

    func addCustomPrompt(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.prompts.append(Prompt(id: UUID().uuidString,
                                       text: trimmed,
                                       symbolName: "sparkles",
                                       isEnabled: true,
                                       isBuiltIn: false))
    }

    /// Built-ins are switched off rather than deleted, so they can come back.
    func removePrompts(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where settings.prompts.indices.contains(index) {
            if settings.prompts[index].isBuiltIn {
                settings.prompts[index].isEnabled = false
            } else {
                settings.prompts.remove(at: index)
            }
        }
    }

    /// Single mutation so the reminder is only rescheduled once per change.
    func setReminderTime(hour: Int, minute: Int) {
        var updated = settings
        updated.reminderHour = hour
        updated.reminderMinute = minute
        settings = updated
    }

    func refreshToday() {
        let current = DayKey.currentKey()
        if current != todayKey { todayKey = current }
    }

    // MARK: - Export

    /// Plain JSON, readable in any text editor — the data is the user's.
    func makeExportFile() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payload = entries.values.sorted { $0.dayKey < $1.dayKey }
        guard let data = try? encoder.encode(payload) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nightly-\(DayKey.currentKey()).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Persistence

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Nightly", isDirectory: true)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func loadEntries(from url: URL) -> [String: DayEntry] {
        guard let data = try? Data(contentsOf: url),
              let list = try? makeDecoder().decode([DayEntry].self, from: data) else { return [:] }
        return Dictionary(list.map { ($0.dayKey, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    private static func loadSettings(from url: URL) -> AppSettings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? makeDecoder().decode(AppSettings.self, from: data) else { return .standard }
        return settings
    }

    private func saveEntries() {
        let payload = entries.values.sorted { $0.dayKey < $1.dayKey }
        guard let data = try? EntryStore.makeEncoder().encode(payload) else { return }
        try? data.write(to: entriesURL, options: .atomic)
    }

    private func saveSettings() {
        guard let data = try? EntryStore.makeEncoder().encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    private func settingsChanged(from old: AppSettings) {
        saveSettings()
        let scheduleChanged = old.reminderEnabled != settings.reminderEnabled
            || old.reminderHour != settings.reminderHour
            || old.reminderMinute != settings.reminderMinute
        if scheduleChanged { syncReminder() }
    }

    /// Re-applies the nightly nudge to the system. Safe to call at launch.
    func syncReminder() {
        guard settings.reminderEnabled else {
            Reminders.cancel()
            return
        }
        Reminders.requestAuthorization { [weak self] granted in
            guard let self else { return }
            if granted {
                Reminders.schedule(hour: self.settings.reminderHour, minute: self.settings.reminderMinute)
            } else if self.settings.reminderEnabled {
                // Permission was refused; don't leave the switch lying about it.
                self.settings.reminderEnabled = false
            }
        }
    }
}
