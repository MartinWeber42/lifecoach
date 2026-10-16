import Foundation
import SwiftData

/// Nachverarbeitung (MEMORY.md Verarbeitung): offline gefallene Einträge (processedVersion == nil)
/// werden aus rawText neu klassifiziert und extrahiert — im Hintergrund, blockiert nie.
/// isPrivate-Einträge gehen nie an ein Modell (Vorstufe-Invariante).
@MainActor
public struct Reprocessor {
    public let classifier: (any Classifier)?
    public let extractor: (any Extractor)?

    public init(classifier: (any Classifier)?, extractor: (any Extractor)?) {
        self.classifier = classifier
        self.extractor = extractor
    }

    /// Verarbeitet ein Entry aus rawText neu; gibt Alias-Vorschläge zur Bestätigung zurück.
    public func reprocess(_ entry: Entry, facts: [Fact], people: [Person], in context: ModelContext) async -> [Extraction.AliasSuggestion] {
        guard !entry.isPrivate else { return [] } // nie an ein Modell
        // Klassifizierung neu (Frage bleibt als Notiz erhalten — nichts geht verloren)
        if let classifier, let c = try? await classifier.classify(entry.rawText, now: .now, timeZone: .current) {
            if c.kind != .question {
                entry.kind = c.kind
                entry.text = c.text
                entry.dueAt = c.due
            }
            entry.processedVersion = 1
        }
        // Extraktion + Abgleich
        var suggestions: [Extraction.AliasSuggestion] = []
        if let extractor, let extraction = try? await extractor.extract(entry.rawText, facts: facts, people: people, now: .now, timeZone: .current) {
            suggestions = (try? ExtractionApplier().apply(extraction, to: entry, in: context)) ?? []
        }
        return suggestions
    }
}
