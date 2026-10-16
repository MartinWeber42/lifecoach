import SwiftUI
import SwiftData
import LifeCoachCore

@main
struct LiveCoachApp: App {
    @State private var settings = AppSettings()

    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Entry.self, Fact.self, Person.self])
        let storeURL = URL.applicationSupportDirectory.appending(path: "LifeCoach.store")
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            // NSFileProtectionComplete (CONCEPT Datenschutz: Store nur bei entriegeltem Gerät)
            for suffix in ["", "-wal", "-shm"] {
                let file = URL(fileURLWithPath: storeURL.path + suffix)
                try? (file as NSURL).setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
            }
            return container
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
                .tint(.orange)
        }
        .modelContainer(Self.sharedModelContainer)
        .environment(settings)
    }
}
