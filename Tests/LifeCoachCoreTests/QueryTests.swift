import Foundation
import Testing
@testable import LifeCoachCore

private final class CallCounter: @unchecked Sendable {
    var count = 0
}

private struct CountingAnswerer: Answerer {
    let result: Result<Answer, Error>
    let counter: CallCounter

    init(_ result: Result<Answer, Error>, _ counter: CallCounter) {
        self.result = result
        self.counter = counter
    }

    func answer(_ question: String, candidates: [Fact], now: Date, timeZone: TimeZone) async throws -> Answer {
        counter.count += 1
        switch result {
        case .success(let a): return a
        case .failure(let e): throw e
        }
    }
}

@MainActor
struct QueryTests {
    private let lisa = Person(name: "Lisa", aliases: ["meine Freundin"])

    /// Ohne passende Kandidaten: Enthaltung, kein Modell-Aufruf (ROADMAP M2: noCandidatesYieldsNothingStored).
    @Test func noCandidatesYieldsNothingStored() async {
        let counter = CallCounter()
        let service = QueryService(answerer: CountingAnswerer(.success(Answer(text: "x", sourceIDs: [])), counter))

        let outcome = await service.ask("was mag lisa", facts: [], entries: [], people: [lisa])

        guard case .nothingStored = outcome else {
            Issue.record("expected nothingStored"); return
        }
        #expect(counter.count == 0)
    }

    /// Private Treffer zeigen den Eintrag selbst, ohne KI — das Passwort geht nie an ein Modell
    /// (MEMORY.md, Vorstufe: Bei privaten Treffern zeigt die App den Eintrag selbst an).
    @Test func privateHitShowsEntryWithoutModel() async {
        let counter = CallCounter()
        let service = QueryService(answerer: CountingAnswerer(.success(Answer(text: "x", sourceIDs: [])), counter))
        let privateEntry = Entry(rawText: "wlan pw bei den eltern ist sonnenblume42", isPrivate: true)

        let outcome = await service.ask(
            "wie war das wlan pw bei meinen eltern",
            facts: [],
            entries: [privateEntry],
            people: [])

        guard case .privateEntries(let hits) = outcome else {
            Issue.record("expected privateEntries"); return
        }
        #expect(hits.count == 1 && hits.first === privateEntry)
        #expect(counter.count == 0)
    }

    /// Die Antwort trägt die Quell-Fakt-IDs (ROADMAP M2: answerCitesSourceEntries).
    @Test func answerCitesSourceEntries() async {
        let vase = Fact(statement: "Lisa wünscht sich eine Keramikvase.")
        vase.people = [lisa]
        let answer = Answer(text: "Eine Keramikvase.", sourceIDs: [vase.id])
        let service = QueryService(answerer: CountingAnswerer(.success(answer), CallCounter()))

        let outcome = await service.ask(
            "was wünscht sich meine freundin",
            facts: [vase],
            entries: [],
            people: [lisa])

        guard case .answered(let got) = outcome else {
            Issue.record("expected answered"); return
        }
        #expect(got == answer)
        #expect(got.sourceIDs == [vase.id])
    }

    /// Ohne Modell (manueller Modus): nur die Retriever-Treffer (ROADMAP M2, CONCEPT: Volltextsuche).
    @Test func manualModeReturnsMatchesOnly() async {
        let vase = Fact(statement: "Lisa wünscht sich eine Keramikvase.")
        vase.people = [lisa]
        let service = QueryService(answerer: nil)

        let outcome = await service.ask(
            "was wünscht sich meine freundin",
            facts: [vase],
            entries: [],
            people: [lisa])

        guard case .matches(let ids) = outcome else {
            Issue.record("expected matches"); return
        }
        #expect(ids == [vase.id])
    }

    /// Antwortfehler fallen auf die Treffer zurück — Abfragen blockieren nie (CONCEPT: Speichern nie blockiert).
    @Test func answerErrorFallsBackToMatches() async {
        let vase = Fact(statement: "Lisa wünscht sich eine Keramikvase.")
        vase.people = [lisa]
        let service = QueryService(answerer: CountingAnswerer(.failure(ClassifierError.http(status: 500, body: "")), CallCounter()))

        let outcome = await service.ask(
            "was wünscht sich meine freundin",
            facts: [vase],
            entries: [],
            people: [lisa])

        guard case .matches(let ids) = outcome else {
            Issue.record("expected matches"); return
        }
        #expect(ids == [vase.id])
    }
}
