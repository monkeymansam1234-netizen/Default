import SwiftUI

/// Tonight's card. Every answer saves the instant it's tapped, so quitting
/// halfway through never loses anything and there is nothing to "submit".
struct CheckInView: View {
    @EnvironmentObject private var store: EntryStore
    @Environment(\.dismiss) private var dismiss

    let dayKey: String

    @State private var note: String = ""
    @State private var showingConfirmation = false
    @FocusState private var noteFocused: Bool

    private var isToday: Bool { dayKey == store.todayKey }
    private var entry: DayEntry? { store.entry(for: dayKey) }
    private var prompts: [Prompt] { store.settings.enabledPrompts }
    private var hapticsOn: Bool { store.settings.hapticsEnabled }

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 16) {
                    header
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(prompts) { prompt in
                        PromptCard(prompt: prompt,
                                   selection: store.rating(for: prompt.id, on: dayKey)) { rating in
                            Haptics.tap(enabled: hapticsOn)
                            store.toggleRating(rating, for: prompt.id, on: dayKey)
                        }
                    }

                    if prompts.isEmpty { noQuestionsCard }

                    noteCard
                    doneButton
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)

            if showingConfirmation {
                confirmationOverlay
            }
        }
        .onAppear { note = entry?.note ?? "" }
        .onChange(of: noteFocused) { _, focused in
            if !focused { commitNote() }
        }
        .onDisappear { commitNote() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { noteFocused = false }
            }
        }
    }

    // MARK: - Pieces

    private var background: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            LinearGradient(colors: [Color.accentColor.opacity(0.22), .clear],
                           startPoint: .top,
                           endPoint: .center)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(isToday ? "How was today?" : Formatting.relativeDay(from: dayKey, todayKey: store.todayKey))
                .font(.largeTitle.weight(.semibold))
            Text(Formatting.longDate(from: dayKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if store.streak > 1 {
                Text("\(store.streak) nights in a row")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var noQuestionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No questions turned on")
                .font(.headline)
            Text("Add some in settings, or just leave a note below — that works too.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Anything worth remembering?", systemImage: "text.alignleft")
                .font(.headline)
            TextField("Optional. One line is plenty.", text: $note, axis: .vertical)
                .lineLimit(2...6)
                .focused($noteFocused)
                .textInputAutocapitalization(.sentences)
        }
        .cardStyle()
    }

    private var doneButton: some View {
        Button(action: finish) {
            HStack(spacing: 8) {
                Image(systemName: entry == nil ? "moon.zzz.fill" : "checkmark.circle.fill")
                Text(doneTitle)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .padding(.top, 4)
    }

    private var doneTitle: String {
        if !isToday { return entry == nil ? "Log this day" : "Save changes" }
        return entry == nil ? "Log tonight" : "Saved — tap to update"
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 6) {
            if isToday && DayKey.isAfterMidnightGrace() {
                Text("Past midnight — this still counts for \(Formatting.shortDate(from: dayKey)).")
            }
            Text("Skipping questions is fine. Logging nothing at all still counts.")
        }
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .padding(.top, 6)
    }

    private var confirmationOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)
                Text(entry?.summary ?? "Logged. That counts.")
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                Text("Goodnight.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
        }
        .transition(.opacity)
        .onTapGesture { dismissConfirmation() }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Actions

    private func commitNote() {
        store.setNote(note, on: dayKey)
    }

    private func finish() {
        noteFocused = false
        commitNote()
        store.markLogged(dayKey)
        Haptics.done(enabled: hapticsOn)

        guard isToday else {
            dismiss()
            return
        }

        withAnimation(.easeOut(duration: 0.25)) { showingConfirmation = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            await MainActor.run { dismissConfirmation() }
        }
    }

    private func dismissConfirmation() {
        guard showingConfirmation else { return }
        withAnimation(.easeIn(duration: 0.3)) { showingConfirmation = false }
    }
}
