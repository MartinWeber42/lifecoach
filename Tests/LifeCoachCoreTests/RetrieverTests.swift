import Foundation
import Testing
@testable import LifeCoachCore

struct RetrieverTests {
    private let lisa = Person(name: "Lisa", aliases: ["meine Freundin"])

    /// Der passende Eintrag kommt zuerst, Nebensächliches fliegt raus
    /// (ROADMAP M2: retrieverRanksMatchingEntryFirst).
    @Test func retrieverRanksMatchingEntryFirst() {
        let vase = Fact(statement: "Lisa wünscht sich eine Keramikvase.")
        vase.people = [lisa]
        let wein = Fact(statement: "Papa trinkt gern Grauburgunder.")

        let candidates = Retriever().candidates(
            for: "was wünscht sich lisa zu weihnachten",
            facts: [wein, vase],
            people: [lisa])

        #expect(candidates.first === vase)
        #expect(!candidates.contains(where: { $0 === wein }))
    }

    /// Ersetzte Fakten werden nicht mehr gefunden (MEMORY.md: Wissens-Update, supersededBy).
    @Test func supersededFactsAreNotRetrieved() {
        let kerze = Fact(statement: "Lisa wünscht sich eine Kerze.")
        kerze.people = [lisa]
        let buch = Fact(statement: "Lisa wünscht sich ein Buch.")
        buch.people = [lisa]
        kerze.supersededByID = buch.id

        let candidates = Retriever().candidates(
            for: "was wünscht sich meine freundin",
            facts: [kerze, buch],
            people: [lisa])

        #expect(candidates.map(\.id) == [buch.id]) // nur aktuelle Fakten
    }

    /// Personen-Fakten kommen über den Alias rein, auch ohne Wort-Overlap — der Original-Story-Pfad
    /// (MEMORY.md Abfragen Schritt 1+3).
    @Test func personFactsAreRetrievedByAlias() {
        let vase = Fact(statement: "Lisa wünscht sich eine Keramikvase.")
        vase.people = [lisa]

        let candidates = Retriever().candidates(
            for: "was wünscht sich meine freundin zu weihnachten",
            facts: [vase],
            people: [lisa])

        #expect(candidates.map(\.id) == [vase.id])
    }

    /// Das Kandidaten-Budget (~2.500 Tokens) hält (ROADMAP M2: retrieverRespectsTokenBudget).
    @Test func retrieverRespectsTokenBudget() {
        let facts = (1...200).map { i in
            Fact(statement: "Eintrag nummer \(i): " + (1...60).map { "wort\($0)" }.joined(separator: " "))
        }

        let candidates = Retriever().candidates(for: "wort1 wort2", facts: facts, people: [])

        let words = candidates.reduce(0) { $0 + $1.statement.split(separator: " ").count }
        #expect(words * 4 / 3 <= 2500) // Budget gehalten
        #expect(candidates.count < 200) // gekürzt
    }
}
