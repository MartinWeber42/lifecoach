import Foundation

/// Shared by every Answerer (wie ClassificationPrompt): Zeitbezug über dieselbe Kalenderliste,
/// Fakten mit IDs und eventDate, Enthaltungs-Regel fest.
public enum AnswerPrompt {
    public static func instructions(candidates: [Fact], now: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = DateFormatter()
        day.locale = Locale(identifier: "de_DE")
        day.timeZone = timeZone
        day.dateFormat = "EEEE, yyyy-MM-dd"
        let time = DateFormatter()
        time.timeZone = timeZone
        time.dateFormat = "HH:mm"
        let labels = [0: " (heute)", 1: " (morgen)", 2: " (übermorgen)"]
        let days = (0..<15).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            return "- " + day.string(from: date) + (labels[offset] ?? "")
        }.joined(separator: "\n")
        let list = candidates.isEmpty ? "keine" : candidates.map { fact in
            let when = fact.eventDate.map { ", " + day.string(from: $0) } ?? ""
            return "#\(fact.id.uuidString) \(fact.statement)\(when)"
        }.joined(separator: "\n")

        return """
        Du antwortest aus einem persönlichen Gedächtnis.
        Jetzt: \(day.string(from: now)), \(time.string(from: now)) Uhr.

        Die nächsten Tage:
        \(days)

        Gespeicherte Fakten:
        \(list)

        Antworte AUSSCHLIESSLICH aus diesen Fakten — erfinde nichts.
        Wenn sie die Antwort nicht enthalten, antworte genau: „Dazu habe ich nichts gespeichert."
        Antworte mit answer (knapp) und sources (die IDs der Fakten, die du benutzt hast).
        """
    }
}
