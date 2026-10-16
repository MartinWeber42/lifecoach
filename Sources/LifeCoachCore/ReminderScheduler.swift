import Foundation

/// Die nächsten planbaren Erinnerungen (CONCEPT Flow B): max. 64, nur zukünftige, nicht erledigte.
public enum ReminderPlanning {
    /// iOS-Limit: max. 64 ausstehende lokale Notifications pro App.
    public static let limit = 64

    /// Entries, die eine Notification bekommen, sortiert nach Fälligkeit.
    public static func planable(_ entries: [Entry], now: Date) -> [Entry] {
        Array(entries
            .filter { $0.kind == .reminder && $0.doneAt == nil }
            .filter { entry in
                guard let due = entry.dueAt else { return false }
                return due > now
            }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
            .prefix(limit))
    }
}

/// Plant lokale Erinnerungen (CONCEPT Flow B): plant beim Speichern, ersetzt beim Ändern,
/// entfernt beim Löschen/Erledigen. UNReminderScheduler ist die echte Implementierung.
@MainActor
public protocol ReminderScheduler: Sendable {
    /// Plant (oder ersetzt) die Notification für die Erinnerung.
    func schedule(_ entry: Entry, now: Date) async
    /// Entfernt die Notification (Löschen/Erledigen).
    func cancel(id: UUID) async
    /// Re-Scheduling der nächsten 64 Fälligkeiten (App-Start und nach Änderungen).
    func rescheduleAll(_ entries: [Entry], now: Date) async
}
