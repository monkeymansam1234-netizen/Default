import SwiftUI

/// The app opens straight onto tonight's card. No tabs, no dashboard,
/// nothing between launching and answering.
struct RootView: View {
    @EnvironmentObject private var store: EntryStore
    @State private var showingHistory = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            CheckInView(dayKey: store.todayKey)
                .id(store.todayKey)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingHistory = true
                        } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("History")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView().environmentObject(store)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environmentObject(store)
        }
    }
}
