import Foundation
import SwiftData
import Testing
@testable import LifeCoachCore

@MainActor
struct ExtractionApplierTests {
    /// The Abgleich marks old facts superseded, never deletes
    /// (MEMORY.md: supersededBy; Eval-Kategorie Wissens-Update).
    @Test func extractionSupersedesOldFactWithoutDeleting() throws {
        let container = try ModelContainer(
            for: Entry.self, Fact.self, Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let entry = Entry(rawText: "lisa will doch lieber ein buch")
        context.insert(entry)
        let old = Fact(statement: "Lisa wünscht sich eine Kerze.")
        old.entry = entry
        context.insert(old)

        let extraction = Extraction(
            facts: [.init(statement: "Lisa wünscht sich ein Buch.", people: ["Lisa"], eventDate: nil)],
            aliasSuggestions: [],
            supersedes: [old.id])
        let suggestions = try ExtractionApplier().apply(extraction, to: entry, in: context)

        let facts = try context.fetch(FetchDescriptor<Fact>())
        #expect(facts.count == 2) // nie gelöscht
        let superseded = facts.first { $0.id == old.id }
        let replacement = facts.first { $0.statement.contains("Buch") }
        #expect(superseded?.supersededByID == replacement?.id)
        #expect(suggestions.isEmpty)
    }

    /// New facts carry their source entry and resolved (or newly created) people
    /// (MEMORY.md, Schicht 2/3).
    @Test func newFactLinksEntryAndPeople() throws {
        let container = try ModelContainer(
            for: Entry.self, Fact.self, Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let entry = Entry(rawText: "der neue nachbar heißt jonas, hat nen hund namens bello")
        context.insert(entry)
        let existing = Person(name: "Jonas")
        context.insert(existing)

        let extraction = Extraction(
            facts: [
                .init(statement: "Der neue Nachbar heißt Jonas.", people: ["Jonas"], eventDate: nil),
                .init(statement: "Jonas hat einen Hund namens Bello.", people: ["Jonas"], eventDate: nil),
            ],
            aliasSuggestions: [],
            supersedes: [])
        _ = try ExtractionApplier().apply(extraction, to: entry, in: context)

        let facts = try context.fetch(FetchDescriptor<Fact>())
        #expect(facts.count == 2)
        #expect(facts.allSatisfy { $0.entry === entry })
        #expect(facts.allSatisfy { $0.people.first?.name == "Jonas" })
        let persons = try context.fetch(FetchDescriptor<Person>())
        #expect(persons.count == 1) // kein Duplikat
    }

    /// Alias suggestions are returned for UI confirmation, never silently written to Person
    /// (MEMORY.md, Schicht 3: Aliase werden nie still übernommen).
    @Test func aliasSuggestionsAreNotSilentlyConfirmed() throws {
        let container = try ModelContainer(
            for: Entry.self, Fact.self, Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let entry = Entry(rawText: "meine freundin lisa mag keine rosen")
        context.insert(entry)
        let lisa = Person(name: "Lisa")
        context.insert(lisa)

        let extraction = Extraction(
            facts: [.init(statement: "Lisa mag keine Rosen.", people: ["Lisa"], eventDate: nil)],
            aliasSuggestions: [.init(alias: "meine Freundin", person: "Lisa")],
            supersedes: [])
        let suggestions = try ExtractionApplier().apply(extraction, to: entry, in: context)

        #expect(suggestions == [.init(alias: "meine Freundin", person: "Lisa")])
        let persons = try context.fetch(FetchDescriptor<Person>())
        #expect(persons.first?.aliases.isEmpty == true)
    }
}
