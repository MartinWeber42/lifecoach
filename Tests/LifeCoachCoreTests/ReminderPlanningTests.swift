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

    /// Übersicht: fällige Erinnerungen oben, überfällige zuerst — "16 uhr rucola" steht weit oben.
    @Test func overviewGroupsRemindersFirst() {
        let rucola = Entry(rawText: "16 uhr rucola", kind: .reminder, dueAt: now.addingTimeInterval(5400), createdAt: now)
        let schinken = Entry(rawText: "schinken kaufen", kind: .note, createdAt: now.addingTimeInterval(-600))
        let overdue = Entry(rawText: "wäsche aufhängen", kind: .reminder, dueAt: now.addingTimeInterval(-3600), createdAt: now.addingTimeInterval(-7200))
        let done = Entry(rawText: "mama anrufen", kind: .reminder, dueAt: now.addingTimeInterval(3600), createdAt: now.addingTimeInterval(-300), doneAt: now)

        let overview = ReminderPlanning.overview([rucola, schinken, done, overdue], now: now)

        #expect(overview.reminders.map(\.rawText) == ["wäsche aufhängen", "16 uhr rucola"]) // überfällig zuerst
        #expect(overview.notes.map(\.rawText) == ["schinken kaufen", "mama anrufen"]) // neueste unten
    }

    /// Erledigte Erinnerungen wandern in den Rest, stehen nicht mehr oben.
    @Test func overviewHidesDoneRemindersFromTop() {
        let done = Entry(rawText: "mama anrufen", kind: .reminder, dueAt: now.addingTimeInterval(3600), doneAt: now)

        let overview = ReminderPlanning.overview([done], now: now)

        #expect(overview.reminders.isEmpty)
        #expect(overview.notes.map(\.rawText) == ["mama anrufen"])
    }
}
