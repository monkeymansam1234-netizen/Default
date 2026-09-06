import SwiftUI

/// History is deliberately calm: a grid you can read at a glance, a few
/// patterns, and the notes. No graphs of "productivity", no goals to miss.
struct HistoryView: View {
    @EnvironmentObject private var store: EntryStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: EditTarget?

    struct EditTarget: Identifiable {
        let id: String
    }

    private var recentKeys: [String] { store.recentDayKeys(days: 35) }
    private var loggedInWindow: Int { recentKeys.filter { store.entry(for: $0) != nil }.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statsRow
                    DayGrid(dayKeys: recentKeys, entries: store.entries)
                        .padding(.vertical, 4)
                } header: {
                    Text("Last five weeks")
                }

                if !store.settings.enabledPrompts.isEmpty && !store.entries.isEmpty {
                    Section("Patterns · last 30 days") {
                        ForEach(store.settings.enabledPrompts) { prompt in
                            PatternRow(prompt: prompt,
                                       positivity: store.positivity(for: prompt.id, days: 30),
                                       answeredDays: store.answeredCount(for: prompt.id, days: 30))
                        }
                    }
                }

                if !store.entries.isEmpty {
                    Section("Entries") {
                        ForEach(store.entriesByRecency) { entry in
                            Button {
                                editing = EditTarget(id: entry.dayKey)
                            } label: {
                                EntryRow(entry: entry,
                                         todayKey: store.todayKey,
                                         prompts: store.settings.prompts)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
            }
            .navigationTitle("Your nights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if store.entries.isEmpty {
                    ContentUnavailableView("Nothing logged yet",
                                           systemImage: "moon.stars",
                                           description: Text("Tonight can be the first one."))
                }
            }
            .sheet(item: $editing) { target in
                NavigationStack {
                    CheckInView(dayKey: target.id)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { editing = nil }
                            }
                        }
                }
                .environmentObject(store)
            }
        }
    }

    private var statsRow: some View {
        HStack {
            stat(value: "\(store.streak)", label: store.streak == 1 ? "night streak" : "nights in a row")
            Divider()
            stat(value: "\(loggedInWindow)/\(recentKeys.count)", label: "days logged")
            Divider()
            stat(value: "\(store.entries.count)", label: "total entries")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private func deleteEntries(at offsets: IndexSet) {
        let list = store.entriesByRecency
        for index in offsets where list.indices.contains(index) {
            store.deleteEntry(for: list[index].dayKey)
        }
    }
}

/// Five weeks of squares. Empty days are a faint outline, never red.
struct DayGrid: View {
    let dayKeys: [String]
    let entries: [String: DayEntry]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(dayKeys, id: \.self) { key in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color(for: key))
                        .aspectRatio(1, contentMode: .fit)
                        .accessibilityLabel(Formatting.shortDate(from: key))
                }
            }

            HStack(spacing: 12) {
                legendChip(color: Rating.rough.tint, label: Rating.rough.label)
                legendChip(color: Rating.okay.tint, label: Rating.okay.label)
                legendChip(color: Rating.good.tint, label: Rating.good.label)
                legendChip(color: Color.primary.opacity(0.07), label: "Not logged")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
        }
    }

    private func color(for dayKey: String) -> Color {
        guard let entry = entries[dayKey] else { return Color.primary.opacity(0.07) }
        guard let score = entry.score else { return Color.accentColor.opacity(0.30) }
        switch score {
        case ..<0.4: return Rating.rough.tint.opacity(0.9)
        case ..<0.7: return Rating.okay.tint.opacity(0.9)
        default: return Rating.good.tint.opacity(0.9)
        }
    }
}

struct EntryRow: View {
    let entry: DayEntry
    let todayKey: String
    let prompts: [Prompt]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Formatting.relativeDay(from: entry.dayKey, todayKey: todayKey))
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(prompts) { prompt in
                        if let rating = entry.answers[prompt.id] {
                            Circle()
                                .fill(rating.tint)
                                .frame(width: 9, height: 9)
                        }
                    }
                }
            }
            if entry.trimmedNote.isEmpty {
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(entry.trimmedNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct PatternRow: View {
    let prompt: Prompt
    let positivity: Double?
    let answeredDays: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(prompt.text, systemImage: prompt.symbolName)
                    .font(.subheadline)
                Spacer()
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: positivity ?? 0)
                .tint(barColor)
        }
        .padding(.vertical, 4)
    }

    private var caption: String {
        guard let positivity else { return "no answers yet" }
        return "\(Int((positivity * 100).rounded()))% · \(answeredDays) days"
    }

    private var barColor: Color {
        guard let positivity else { return .secondary }
        switch positivity {
        case ..<0.4: return Rating.rough.tint
        case ..<0.7: return Rating.okay.tint
        default: return Rating.good.tint
        }
    }
}
