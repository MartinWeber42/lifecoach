import Foundation
import SwiftData

/// Schicht 2 (MEMORY.md): eine atomare Aussage, Personen ausgeschrieben, Zeit absolut.
@Model
public final class Fact {
    /// Stabile ID für den Abgleich-Vertrag ("supersedes" aus der Extraktion).
    public var id: UUID = UUID()
    /// Eine Aussage, ohne Quelle verständlich ("Lisa wünscht sich zu Weihnachten eine Keramikvase.").
    public var statement: String
    /// Bi-temporal: wann es gilt (falls genannt); entry.createdAt = wann es gespeichert wurde.
    public var eventDate: Date?
    /// Ersetzen statt löschen (MEMORY.md): wird vom Abgleich gesetzt. Als ID statt Relationship —
    /// SwiftData paart self-referencing Relationships automatisch (falsche Inverse).
    public var supersededByID: UUID?
    public var people: [Person] = []
    /// Quelle (inverse über Entry.facts, cascade delete).
    public var entry: Entry?

    public init(statement: String, eventDate: Date? = nil) {
        self.statement = statement
        self.eventDate = eventDate
    }
}
