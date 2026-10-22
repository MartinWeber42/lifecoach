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

/// Übersicht (App-Start): fällige Erinnerungen oben — überfällige zuerst; Notizen + Erledigtes darunter.
extension ReminderPlanning {
    public static func overview(_ entries: [Entry], now: Date) -> (reminders: [Entry], notes: [Entry]) {
        let reminders = entries
            .filter { $0.kind == .reminder && $0.doneAt == nil }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        let notes = entries
            .filter { !($0.kind == .reminder && $0.doneAt == nil) }
            .sorted { $0.createdAt < $1.createdAt }
        return (reminders, notes)
    }
}

/// Plant Erinnerungen in der Erinnerungen-App (CONCEPT Flow B, jetzt via EventKit): plant beim
/// Speichern, ersetzt beim Ändern,
/// entfernt beim Löschen/Erledigen. UNReminderScheduler ist die echte Implementierung.
@MainActor
public protocol ReminderScheduler: Sendable {
    /// Plant (oder ersetzt) die Notification für die Erinnerung.
    func schedule(_ entry: Entry, now: Date) async
    /// Entfernt die Erinnerung (Löschen/Erledigen).
    func cancel(_ entry: Entry) async
    /// Re-Scheduling der nächsten 64 Fälligkeiten (App-Start und nach Änderungen).
    func rescheduleAll(_ entries: [Entry], now: Date) async
}
