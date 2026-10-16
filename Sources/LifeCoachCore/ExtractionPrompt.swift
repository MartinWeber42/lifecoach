import Foundation

/// Shared by every Extractor (wie ClassificationPrompt): beide Modelle werden gegen dieselben
/// Anweisungen gemessen. Enthält bekannte Personen (Vorstufe 2) und gespeicherte Fakten als Kontext.
public enum ExtractionPrompt {
    public static func instructions(facts: [Fact], people: [Person], now: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = DateFormatter()
        day.locale = Locale(identifier: "de_DE")
        day.timeZone = timeZone
        day.dateFormat = "EEEE, yyyy-MM-dd"
        let time = DateFormatter()
        time.timeZone = timeZone
        time.dateFormat = "HH:mm"

        let known = people.isEmpty ? "keine" : people.map { person in
            person.aliases.isEmpty ? person.name : person.name + " (= " + person.aliases.joined(separator: ", ") + ")"
        }.joined(separator: ", ")
        let saved = facts.isEmpty ? "keine" : facts.map { "#\($0.id.uuidString) \($0.statement)" }.joined(separator: "\n")

        return """
        Du extrahierst atomare Fakten aus Eingaben für ein persönliches Gedächtnis.
        Jetzt: \(day.string(from: now)), \(time.string(from: now)) Uhr.

        Bekannte Personen (mit bestätigten Aliasen): \(known)
        Gespeicherte Fakten:
        \(saved)

        Antworte mit facts, aliasSuggestions und supersedes:
        - facts: eine Aussage pro Fakt, in sich verständlich, Personen ausgeschrieben, Zeit absolut (eventDate: JJJJ-MM-TT oder null, wenn die Eingabe keinen Zeitpunkt nennt).
        - aliasSuggestions: nur wenn die Eingabe eine bekannte Person anders benennt (z. B. „meine freundin" für Lisa). Setze nie selbst Aliase.
        - supersedes: die UUIDs gespeicherter Fakten, die die neuen Fakten ersetzen (z. B. Wunsch geändert). Nie löschen — nur markieren.

        Beispiele:
        - „lisa wünscht sich zu weihnachten ne keramikvase" → fact „Lisa wünscht sich zu Weihnachten eine Keramikvase." (people: ["Lisa"])
        - „neuer nachbar heißt jonas, hat nen hund namens bello" → zwei facts („Der neue Nachbar heißt Jonas.", „Jonas hat einen Hund namens Bello.")
        - „gestern 5km gelaufen in 28 min" → fact „Ich bin 5 km in 28 Minuten gelaufen." eventDate = gestern
        - „meine freundin lisa mag keine rosen" → fact „Lisa mag keine Rosen." + aliasSuggestion „meine freundin" → Lisa
        - „lisa will doch lieber ein buch" (statt Kerze) → neuer fact + supersedes: [UUID der Kerze]
        """
    }
}
