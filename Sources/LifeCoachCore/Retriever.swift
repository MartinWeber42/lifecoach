import Foundation

/// Kandidaten zu einer Frage (MEMORY.md, Abfragen): aktuelle Fakten der erkannten Personen
/// ∪ Stichwort-Treffer über alle aktuellen Fakten — Ranking nach Overlap, Budget ~2.500 Tokens.
public struct Retriever {
    /// Deutsche Stoppwörter (minimal): tragen nichts zum Wiederfinden bei.
    public static let stopwords: Set<String> = [
        "der", "die", "das", "den", "dem", "des", "ein", "eine", "einen", "einem", "einer",
        "und", "oder", "aber", "ist", "war", "sind", "hat", "hatte", "hab", "habe", "haben",
        "ich", "mir", "mich", "meine", "mein", "meinen", "meiner", "sich", "nicht",
        "was", "wie", "wo", "wann", "wer", "für", "mit", "von", "vom", "zur", "zum",
        "im", "in", "am", "an", "auf", "noch", "schon",
    ]

    public init() {}

    public func candidates(for question: String, facts: [Fact], people: [Person]) -> [Fact] {
        let current = facts.filter { $0.supersededByID == nil } // Ersetzte ausgeschlossen (Wissens-Update)
        let detectedNames = Set(PersonDetection.detect(question, in: people).map { $0.name.lowercased() })
        let questionTokens = Set(tokenize(question)).subtracting(Self.stopwords)

        var scored: [(fact: Fact, score: Int)] = []
        for fact in current {
            var score = questionTokens.intersection(Set(tokenize(fact.statement))).count
            // Personen-Fakten kommen über Namen/Aliase rein, auch ohne Wort-Overlap (Original-Story-Pfad)
            if fact.people.contains(where: { detectedNames.contains($0.name.lowercased()) }) {
                score += 2
            }
            if score > 0 { scored.append((fact, score)) }
        }
        return budget(scored.sorted { $0.score > $1.score }.map(\.fact))
    }

    /// ~2.500 Tokens Budget (MEMORY.md Abfragen, Schritt 4): Wörter × 4/3 geschätzt.
    private func budget(_ candidates: [Fact]) -> [Fact] {
        var kept: [Fact] = []
        var words = 0
        for fact in candidates {
            let cost = fact.statement.split(separator: " ").count * 4 / 3
            if words + cost > 2500 { break }
            kept.append(fact)
            words += cost
        }
        return kept
    }
}
