import Foundation
import SwiftData

/// Wendet ein Extraction-Ergebnis an (MEMORY.md, Verarbeitung): Fakten anlegen, Personen auflösen oder
/// neu anlegen, ersetzte Fakten **markieren statt löschen**. Alias-Vorschläge werden zurückgegeben und
/// nie still übernommen — die UI bestätigt (M2a, Banner).
@MainActor
public struct ExtractionApplier {
    public init() {}

    /// Wendet Fakten + Abgleich an, gibt die Alias-Vorschläge zur Bestätigung zurück.
    public func apply(_ extraction: Extraction, to entry: Entry, in context: ModelContext) throws -> [Extraction.AliasSuggestion] {
        var created: [Fact] = []
        for suggested in extraction.facts {
            let fact = Fact(statement: suggested.statement, eventDate: suggested.eventDate)
            fact.entry = entry
            fact.people = suggested.people.map { resolve(name: $0, in: context) }
            context.insert(fact)
            created.append(fact)
        }
        if let replacement = created.first, !extraction.supersedes.isEmpty {
            // Coarse mapping: jeder ersetzte Fakt zeigt auf den ersten neuen Fakt dieses Aufrufs
            // (deckt den 1:1-Update-Fall exakt ab; Verfeinerung nur wenn die Eval es zeigt).
            for fact in try context.fetch(FetchDescriptor<Fact>()) where extraction.supersedes.contains(fact.id) {
                fact.supersededByID = replacement.id
            }
        }
        return extraction.aliasSuggestions
    }

    /// Findet eine Person exakt beim Namen oder legt sie an (nur Name; Aliase nur per Bestätigung).
    private func resolve(name: String, in context: ModelContext) -> Person {
        let descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.name == name })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let person = Person(name: name)
        context.insert(person)
        return person
    }
}
