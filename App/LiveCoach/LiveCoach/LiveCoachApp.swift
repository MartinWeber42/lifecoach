import SwiftUI
import SwiftData
import LifeCoachCore

@main
struct LiveCoachApp: App {
    @State private var settings = AppSettings()

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Entry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: "reminder", actions: [
                UNNotificationAction(identifier: "markDone", title: "Erledigt"),
                UNNotificationAction(identifier: "snooze1h", title: "In 1 Stunde"),
            ], intentIdentifiers: []),
        ])
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Self.sharedModelContainer)
        .environment(settings)
    }
}
