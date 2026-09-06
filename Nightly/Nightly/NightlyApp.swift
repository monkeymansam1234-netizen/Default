import SwiftUI

@main
struct NightlyApp: App {
    @StateObject private var store = EntryStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.settings.appearance.colorScheme)
                .onAppear { store.syncReminder() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Reopening after midnight should land on the right night.
            if phase == .active { store.refreshToday() }
        }
    }
}
