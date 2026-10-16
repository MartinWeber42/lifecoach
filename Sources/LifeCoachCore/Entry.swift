import Foundation
import SwiftData

/// A persisted capture: a note or reminder (CONCEPT: Datenmodell).
/// `question` is never stored, so an Entry is only ever `.note` or `.reminder`.
@Model
public final class Entry {
    /// Stable identifier (notification identifier; persistentModelID ist nicht laufstabil).
    public var id: UUID = UUID()
    /// Original input, stored unchanged for retrieval and re-classification.
    public var rawText: String
    /// Core statement from the classification.
    public var text: String
    public var kind: Kind
    /// Only set for reminders, confirmed by the user.
    public var dueAt: Date?
    public var createdAt: Date
    /// Set when the user marks a reminder done.
    public var doneAt: Date?

    /// Processing version that ran on this entry (1 = Klassifizierung). `nil` = noch nicht verarbeitet
    /// (offline/Fallback); die Nachverarbeitung (M2b) überspringt `isPrivate`-Einträge.
    public var processedVersion: Int?
    /// Geheimnis-Filter (MEMORY.md, Vorstufe): nie an ein Modell, Wiederfinden nur per Stichwort über `rawText`.
    public var isPrivate: Bool = false
    /// Schicht 2 (MEMORY.md): abgeleitete Fakten, cascade delete mit dem Entry.
    @Relationship(deleteRule: .cascade, inverse: \Fact.entry)
    public var facts: [Fact] = []

    public init(
        rawText: String,
        text: String = "",
        kind: Kind = .note,
        dueAt: Date? = nil,
        createdAt: Date = .now,
        doneAt: Date? = nil,
        isPrivate: Bool = false,
        processedVersion: Int? = nil
    ) {
        self.rawText = rawText
        self.text = text
        self.kind = kind
        self.dueAt = dueAt
        self.createdAt = createdAt
        self.doneAt = doneAt
        self.isPrivate = isPrivate
        self.processedVersion = processedVersion
    }
}
