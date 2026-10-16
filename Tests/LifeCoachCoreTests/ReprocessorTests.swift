import Foundation
import SwiftData
import Testing
@testable import LifeCoachCore

private final class CallCounter: @unchecked Sendable {
    var count = 0
}

private struct CountingClassifier: Classifier {
    let result: Result<Classification, Error>
    let counter: CallCounter

    init(_ result: Result<Classification, Error>, _ counter: CallCounter) {
        self.result = result
        self.counter = counter
    }

    func classify(_ input: String, now: Date, timeZone: TimeZone) async throws -> Classification {
        counter.count += 1
        switch result {
        case .success(let c): return c
        case .failure(let e): throw e
        }
    }
}

private struct CountingExtractor: Extractor {
    let result: Result<Extraction, Error>
    let counter: CallCounter

    init(_ result: Result<Extraction, Error>, _ counter: CallCounter) {
        self.result = result
        self.counter = counter
    }

    func extract(_ input: String, facts: [Fact], people: [Person], now: Date, timeZone: TimeZone) async throws -> Extraction {
        counter.count += 1
        switch result {
        case .success(let e): return e
        case .failure(let e): throw e
        }
    }
}

@MainActor
struct ReprocessorTests {
    /// Offline gefallene Einträge werden aus rawText neu klassifiziert
    /// (MEMORY.md Verarbeitung: App-Start / wieder online).
    @Test func offlineEntriesAreReclassified() async throws {
        let container = try ModelContainer(
            for: Entry.self, Fact.self, Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let entry = Entry(rawText: "morgen 10 uhr mama anrufen") // offline als note gefallen
        context.insert(entry)
        let reprocessor = Reprocessor(
            classifier: CountingClassifier(
                .success(Classification(kind: .reminder, text: "Mama anrufen",
                                        due: DueDate.parse("2026-10-17T10:00:00+02:00", timeZone: .current))),
                CallCounter()),
            extractor: nil)

        _ = await reprocessor.reprocess(entry, facts: [], people: [], in: context)

        #expect(entry.kind == .reminder)
        #expect(entry.text == "Mama anrufen")
        #expect(entry.dueAt != nil)
        #expect(entry.processedVersion == 1)
    }

    /// isPrivate-Einträge gehen nie an ein Modell (MEMORY.md, Vorstufe — Privacy-Invariante).
    @Test func reprocessSkipsPrivateEntries() async throws {
        let container = try ModelContainer(
            for: Entry.self, Fact.self, Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let entry = Entry(rawText: "wlan pw ist sonnenblume42", isPrivate: true)
        context.insert(entry)
        let classifierCounter = CallCounter()
        let extractorCounter = CallCounter()
        let reprocessor = Reprocessor(
            classifier: CountingClassifier(.success(Classification(kind: .note, text: "", due: nil)), classifierCounter),
            extractor: CountingExtractor(.success(Extraction(facts: [], aliasSuggestions: [], supersedes: [])), extractorCounter))

        _ = await reprocessor.reprocess(entry, facts: [], people: [], in: context)

        #expect(classifierCounter.count == 0)
        #expect(extractorCounter.count == 0)
        #expect(entry.processedVersion == nil)
    }

    /// Re-klassifizierte Fragen bleiben gespeichert — nichts geht verloren (CONCEPT: nichts verloren).
    @Test func reclassifiedQuestionStaysStored() async throws {
        let container = try ModelContainer(
            for: Entry.self, Fact.self, Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let entry = Entry(rawText: "was mag lisa für blumen")
        context.insert(entry)
        let reprocessor = Reprocessor(
            classifier: CountingClassifier(
                .success(Classification(kind: .question, text: "was mag lisa", due: nil)), CallCounter()),
            extractor: nil)

        _ = await reprocessor.reprocess(entry, facts: [], people: [], in: context)

        #expect(entry.kind == .note) // Frage bleibt als Notiz erhalten
        #expect(entry.processedVersion == 1)
    }

    /// Nachverarbeitung extrahiert Fakten und wendet sie an (MEMORY.md Verarbeitung).
    @Test func reprocessExtractsFacts() async throws {
        let container = try ModelContainer(
            for: Entry.self, Fact.self, Person.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let entry = Entry(rawText: "lisa wünscht sich eine keramikvase")
        context.insert(entry)
        let extraction = Extraction(
            facts: [.init(statement: "Lisa wünscht sich eine Keramikvase.", people: ["Lisa"], eventDate: nil)],
            aliasSuggestions: [.init(alias: "meine freundin", person: "Lisa")],
            supersedes: [])
        let reprocessor = Reprocessor(
            classifier: nil,
            extractor: CountingExtractor(.success(extraction), CallCounter()))

        let suggestions = await reprocessor.reprocess(entry, facts: [], people: [], in: context)

        let facts = try context.fetch(FetchDescriptor<Fact>())
        #expect(facts.count == 1)
        #expect(facts.first?.entry === entry)
        #expect(suggestions.count == 1) // zur Bestätigung zurückgegeben, nie still übernommen
    }
}
