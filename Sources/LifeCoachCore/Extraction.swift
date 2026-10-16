import Foundation
import SwiftData

/// Ergebnis des Extraktions-Aufrufs (MEMORY.md: eigenes Schema, getrennt von der Klassifizierung).
public struct Extraction: Equatable, Sendable {
    public struct SuggestedFact: Equatable, Sendable {
        public let statement: String
        public let people: [String]
        public let eventDate: Date?

        public init(statement: String, people: [String], eventDate: Date?) {
            self.statement = statement
            self.people = people
            self.eventDate = eventDate
        }
    }

    public struct AliasSuggestion: Equatable, Sendable {
        public let alias: String
        public let person: String

        public init(alias: String, person: String) {
            self.alias = alias
            self.person = person
        }
    }

    public let facts: [SuggestedFact]
    public let aliasSuggestions: [AliasSuggestion]
    /// IDs bestehender Fakten, die ersetzt werden (nie gelöscht — MEMORY.md: supersededBy).
    public let supersedes: [UUID]

    public init(facts: [SuggestedFact], aliasSuggestions: [AliasSuggestion], supersedes: [UUID]) {
        self.facts = facts
        self.aliasSuggestions = aliasSuggestions
        self.supersedes = supersedes
    }
}

/// Extraktion als eigener Aufruf hinter einem Protokoll (wie Classifier/Answerer) —
/// Haiku jetzt, on-device später; nur der Transport tauscht.
@MainActor
public protocol Extractor: Sendable {
    func extract(_ input: String, facts: [Fact], people: [Person], now: Date, timeZone: TimeZone) async throws -> Extraction
}
