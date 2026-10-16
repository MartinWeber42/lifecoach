import Foundation
import SwiftData

/// Schicht 3 (MEMORY.md): Person mit nur bestätigten Aliasen — der wichtigste Hebel für die Original-Story.
@Model
public final class Person {
    public var name: String
    /// Nur bestätigte Aliase (Extraktion schlägt vor, Nutzer bestätigt — nie still übernommen).
    public var aliases: [String] = []

    /// Bestätigt einen Alias (M2a-Banner): hängt an, ohne Duplikate (Groß/Klein egal).
    public func confirm(_ alias: String) {
        let lowered = alias.lowercased()
        guard !aliases.contains(where: { $0.lowercased() == lowered }) else { return }
        aliases.append(alias)
    }

    public init(name: String, aliases: [String] = []) {
        self.name = name
        self.aliases = aliases
    }
}
