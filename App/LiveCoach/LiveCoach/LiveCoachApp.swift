import SwiftUI
import SwiftData
import LifeCoachCore

@main
struct LiveCoachApp: App {
    @State private var settings = AppSettings()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Entry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environment(settings)
    }
}
