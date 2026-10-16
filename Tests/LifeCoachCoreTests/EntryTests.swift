import Foundation
import SwiftData
import Testing
@testable import LifeCoachCore

@MainActor
struct EntryTests {
    /// A raw capture is persisted unchanged as an Entry (CONCEPT: rawText, Flow A).
    @Test func captureIsSavedAsEntry() throws {
        let container = try ModelContainer(
            for: Entry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let capture = "Lisa wünscht sich eine Keramikvase"
        context.insert(Entry(rawText: capture))
        try context.save()

        let saved = try context.fetch(FetchDescriptor<Entry>())
        #expect(saved.count == 1)
        #expect(saved.first?.rawText == capture)
    }
}
