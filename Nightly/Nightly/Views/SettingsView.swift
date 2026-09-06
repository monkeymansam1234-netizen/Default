import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: EntryStore
    @Environment(\.dismiss) private var dismiss

    @State private var newQuestion = ""
    @State private var exportURL: URL?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                questionsSection
                reminderSection
                feelSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { exportURL = store.makeExportFile() }
        }
    }

    private var questionsSection: some View {
        Section {
            ForEach($store.settings.prompts) { $prompt in
                Toggle(isOn: $prompt.isEnabled) {
                    Label(prompt.text, systemImage: prompt.symbolName)
                }
            }
            .onDelete { store.removePrompts(at: $0) }

            HStack {
                TextField("Add your own question", text: $newQuestion)
                Button("Add") {
                    store.addCustomPrompt(text: newQuestion)
                    newQuestion = ""
                }
                .disabled(newQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Questions")
        } footer: {
            Text("Fewer is better. Three questions takes about ten seconds — which is the whole point. Swiping away a built-in question just switches it off.")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("Nightly nudge", isOn: $store.settings.reminderEnabled)
            if store.settings.reminderEnabled {
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Reminder")
        } footer: {
            Text("One notification a night. It never mentions a streak and it never follows up.")
        }
    }

    private var feelSection: some View {
        Section {
            Picker("Appearance", selection: $store.settings.appearance) {
                ForEach(AppSettings.Appearance.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Haptics", isOn: $store.settings.hapticsEnabled)
        } header: {
            Text("Feel")
        } footer: {
            Text("Dark by default — this gets opened with the lights off.")
        }
    }

    private var dataSection: some View {
        Section {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Export entries as JSON", systemImage: "square.and.arrow.up")
                }
            }
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete all entries", systemImage: "trash")
            }
            .confirmationDialog("Delete every entry?",
                                isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    store.deleteAllEntries()
                    exportURL = store.makeExportFile()
                }
                Button("Keep them", role: .cancel) { }
            } message: {
                Text("This can't be undone. Export first if you want a copy.")
            }
        } header: {
            Text("Your data")
        } footer: {
            Text("Everything is stored on this device only. No account, no sync, no network.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("After midnight", value: "Counts as the day before")
            LabeledContent("Version", value: appVersion)
        } header: {
            Text("About")
        } footer: {
            Text("Checking in at 1am is still last night's entry — the day rolls over at \(DayKey.lateNightCutoffHour)am.")
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { store.settings.reminderTime },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                store.setReminderTime(hour: parts.hour ?? 21, minute: parts.minute ?? 30)
            }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return version
    }
}
