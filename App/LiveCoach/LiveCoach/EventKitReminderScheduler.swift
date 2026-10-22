import Foundation
import EventKit
import SwiftData
import LifeCoachCore

/// Schreibt echte Erinnerungen in die Erinnerungen-App (CONCEPT Flow B via EventKit):
/// Berechtigung beim ersten reminder anfragen, ersetzt beim Ändern, entfernt beim Löschen/Erledigen.
/// Die Notifications übernimmt das System (Alarm auf der EKReminder) — auch bei gesperrtem Gerät.
@MainActor
struct EventKitReminderScheduler: ReminderScheduler {
    private let store = EKEventStore()

    func schedule(_ entry: Entry, now: Date) async {
        guard let due = entry.dueAt, due > now else { return }
        guard (try? await requestAccess()) == true else { return }
        let reminder: EKReminder
        if let externalID = entry.reminderExternalID,
           let existing = store.calendarItem(withIdentifier: externalID) as? EKReminder {
            reminder = existing // ersetzt beim Ändern: aktualisieren
        } else {
            reminder = EKReminder(eventStore: store)
            reminder.calendar = Self.coachList(in: store)
        }
        reminder.title = entry.text.isEmpty ? entry.rawText : entry.text
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        reminder.alarms?.forEach { reminder.removeAlarm($0) }
        reminder.addAlarm(EKAlarm(absoluteDate: due)) // Notification kommt vom System
        try? store.save(reminder, commit: true)
        entry.reminderExternalID = reminder.calendarItemExternalIdentifier
    }

    func cancel(_ entry: Entry) async {
        guard let externalID = entry.reminderExternalID,
              let reminder = store.calendarItem(withIdentifier: externalID) as? EKReminder else { return }
        try? store.remove(reminder, commit: true)
        entry.reminderExternalID = nil
    }

    /// Re-Scheduling + Sync zurück: in der Erinnerungen-App abgehakte Erinnerungen setzen doneAt.
    func rescheduleAll(_ entries: [Entry], now: Date) async {
        guard (try? await requestAccess()) == true else { return }
        for entry in entries where entry.reminderExternalID != nil {
            if let reminder = store.calendarItem(withIdentifier: entry.reminderExternalID!) as? EKReminder,
               reminder.isCompleted, entry.doneAt == nil {
                entry.doneAt = .now // Erledigt in der Erinnerungen-App → zurück in die App
            }
        }
        for entry in ReminderPlanning.planable(entries, now: now) {
            await schedule(entry, now: now)
        }
    }

    private func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToReminders()
    }

    /// Eigene Liste "LifeCoach" in der Erinnerungen-App (falls fehlend, anlegen).
    private static func coachList(in store: EKEventStore) -> EKCalendar {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == "LifeCoach" }) {
            return existing
        }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = "LifeCoach"
        list.source = store.defaultCalendarForNewReminders()?.source
        try? store.saveCalendar(list, commit: true)
        return list
    }
}
