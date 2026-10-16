import Foundation
import Testing
@testable import LifeCoachCore

struct EntryExportTests {
    /// Export enthält rawText unverändert (CONCEPT: rawText wird nie verändert gespeichert).
    @Test func exportEncodesRawTextUnchanged() throws {
        let entry = Entry(rawText: "  lisa wünscht sich eine keramikvase  ", text: "Lisa wünscht sich eine Keramikvase.")

        let data = try EntryExport.jsonData([entry])

        #expect(String(decoding: data, as: UTF8.self).contains("lisa wünscht sich eine keramikvase"))
    }

    /// Export ist ISO-8601-codiert und wieder dekodierbar („Handy weg = Gehirn weg" — Gegenmaßnahme).
    @Test func exportRoundtripsThroughJSON() throws {
        let due = DueDate.parse("2026-10-17T10:00:00+02:00", timeZone: .current)!
        let entry = Entry(rawText: "morgen 10 uhr mama anrufen", text: "Mama anrufen", kind: .reminder, dueAt: due)

        let dtos = try EntryExport.decode(try EntryExport.jsonData([entry]))

        #expect(dtos.count == 1)
        #expect(dtos.first?.rawText == "morgen 10 uhr mama anrufen")
        #expect(dtos.first?.kind == .reminder)
        #expect(dtos.first?.dueAt == due)
        #expect(dtos.first?.isPrivate == false)
    }

    /// Der Geheimnis-Filter-Marker kommt mit — private Einträge bleiben im Export erkennbar.
    @Test func exportMarksPrivateEntries() throws {
        let entry = Entry(rawText: "wlan pw ist sonnenblume42", isPrivate: true)

        let dtos = try EntryExport.decode(try EntryExport.jsonData([entry]))

        #expect(dtos.first?.isPrivate == true)
    }
}
