import Foundation

/// Abfrage-Flow (CONCEPT Flow C): private Treffer zuerst (ohne KI), dann Kandidaten, dann Antwort.
@MainActor
public struct QueryService {
    public let answerer: (any Answerer)?

    public init(answerer: (any Answerer)?) {
        self.answerer = answerer
    }

    public func ask(_ question: String, facts: [Fact], entries: [Entry], people: [Person], now: Date = .now, timeZone: TimeZone = .current) async -> QueryOutcome {
        // 1. Private Treffer: Eintrag selbst zeigen, OHNE KI
        // (MEMORY.md, Vorstufe — private Inhalte gehen nie an ein Modell).
        let privateHits = entries.filter { $0.isPrivate && KeywordSearch.matches($0.rawText, query: question) }
        if !privateHits.isEmpty { return .privateEntries(privateHits) }
        // 2. Kandidaten aus aktuellen Fakten.
        let candidates = Retriever().candidates(for: question, facts: facts, people: people)
        if candidates.isEmpty { return .nothingStored }
        // 3. Ohne Modell (manueller Modus): nur die Treffer (CONCEPT: Abfrage = Volltextsuche).
        guard let answerer else { return .matches(candidates.map(\.id)) }
        do {
            return .answered(try await answerer.answer(question, candidates: candidates, now: now, timeZone: timeZone))
        } catch {
            // Abfragen blockieren nie: Fehler → Treffer statt Antwort.
            return .matches(candidates.map(\.id))
        }
    }
}

/// Ergebnis einer Abfrage (CONCEPT Flow C).
public enum QueryOutcome {
    /// KI-Antwort mit Quellen.
    case answered(Answer)
    /// Enthaltung: nichts Passendes gespeichert.
    case nothingStored
    /// Ohne Modell / bei Fehler: nur die Treffer (Suche).
    case matches([UUID])
    /// Privat: Einträge direkt zeigen, nie an ein Modell.
    case privateEntries([Entry])
}
