import Foundation
import SwiftData

/// A persisted capture: a note or reminder (CONCEPT: Datenmodell).
/// `question` is never stored, so an Entry is only ever `.note` or `.reminder`.
@Model
public final class Entry {
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

    public init(
        rawText: String,
        text: String = "",
        kind: Kind = .note,
        dueAt: Date? = nil,
        createdAt: Date = .now,
        doneAt: Date? = nil
    ) {
        self.rawText = rawText
        self.text = text
        self.kind = kind
        self.dueAt = dueAt
        self.createdAt = createdAt
        self.doneAt = doneAt
    }
}
