import Foundation
import Testing
@testable import LifeCoachCore

struct ReminderPlanningTests {
    var now: Date { DueDate.parse("2026-10-16T14:30:00+02:00", timeZone: .current)! }

    /// Erinnerung mit zukünftiger Fälligkeit wird geplant (CONCEPT Flow B).
    @Test func reminderWithFutureDueGetsScheduled() {
        let entry = Entry(rawText: "mama anrufen", kind: .reminder, dueAt: now.addingTimeInterval(3600))

        #expect(ReminderPlanning.planable([entry], now: now).count == 1)
    }

    /// Vergangene Fälligkeit wird nicht geplant.
    @Test func pastDueIsNotScheduled() {
        let entry = Entry(rawText: "mama anrufen", kind: .reminder, dueAt: now.addingTimeInterval(-3600))

        #expect(ReminderPlanning.planable([entry], now: now).isEmpty)
    }

    /// Erledigte Erinnerungen werden nicht mehr geplant (CONCEPT: doneAt).
    @Test func doneRemindersAreNotScheduled() {
        let entry = Entry(rawText: "mama anrufen", kind: .reminder,
                          dueAt: now.addingTimeInterval(3600), doneAt: now)

        #expect(ReminderPlanning.planable([entry], now: now).isEmpty)
    }

    /// Notizen werden nie geplant.
    @Test func notesAreNeverScheduled() {
        let entry = Entry(rawText: "lisa mag rosen", kind: .note)

        #expect(ReminderPlanning.planable([entry], now: now).isEmpty)
    }

    /// iOS-Limit: nur die nächsten 64 Fälligkeiten, die nächstliegende zuerst (CONCEPT Flow B).
    @Test func onlyNextSixtyFourArePlanned() {
        let entries = (1...70).map { i in
            Entry(rawText: "eintrag \(i)", kind: .reminder, dueAt: now.addingTimeInterval(Double(i) * 3600))
        }

        let planned = ReminderPlanning.planable(entries, now: now)

        #expect(planned.count == 64)
        #expect(planned.first?.dueAt == now.addingTimeInterval(3600))
    }
}
