import Foundation
import UserNotifications
import SwiftData
import LifeCoachCore

/// Plant lokale Erinnerungen (CONCEPT Flow B): Berechtigung beim ersten reminder anfragen
/// (nicht beim App-Start), ersetzt beim Ändern, entfernt beim Löschen/Erledigen.
@MainActor
struct UNReminderScheduler: ReminderScheduler {
    func schedule(_ entry: Entry, now: Date) async {
        guard let due = entry.dueAt, due > now else { return }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        let identifier = Self.identifier(for: entry.id)
        center.removePendingNotificationRequests(withIdentifiers: [identifier]) // ersetzt beim Ändern
        let content = UNMutableNotificationContent()
        content.title = "Erinnerung"
        content.body = entry.text.isEmpty ? entry.rawText : entry.text
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancel(id: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: id)])
    }

    /// Re-Scheduling der nächsten 64 Fälligkeiten (CONCEPT Flow B: bei App-Start und nach Änderungen).
    func rescheduleAll(_ entries: [Entry], now: Date) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for entry in ReminderPlanning.planable(entries, now: now) {
            await schedule(entry, now: now)
        }
    }

    private static func identifier(for id: UUID) -> String {
        "reminder-\(id.uuidString)"
    }
}

/// Notification-Aktionen (CONCEPT Flow B): „Erledigt" setzt doneAt, „In 1 Stunde" verschiebt.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let raw = response.notification.request.identifier
        guard raw.hasPrefix("reminder-"), let id = UUID(uuidString: String(raw.dropFirst("reminder-".count))) else { return }
        let context = LiveCoachApp.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.id == id })
        guard let entry = try? context.fetch(descriptor).first else { return }
        switch response.actionIdentifier {
        case "snooze1h":
            entry.dueAt = Date.now.addingTimeInterval(3600)
            try? context.save()
            await UNReminderScheduler().schedule(entry, now: .now)
        case "markDone", UNNotificationDefaultActionIdentifier:
            entry.doneAt = .now
            try? context.save()
            await UNReminderScheduler().cancel(id: id)
        default:
            break
        }
    }
}
