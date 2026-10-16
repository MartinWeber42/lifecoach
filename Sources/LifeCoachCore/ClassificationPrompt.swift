import Foundation

/// Shared by every Classifier so models are measured against the same instructions.
public enum ClassificationPrompt {
    public static func instructions(now: Date, timeZone: TimeZone) -> String {
        let weekday = DateFormatter()
        weekday.locale = Locale(identifier: "de_DE")
        weekday.timeZone = timeZone
        weekday.dateFormat = "EEEE"
        return """
        Du sortierst Eingaben für ein persönliches Gedächtnis.
        Jetzt ist \(weekday.string(from: now)), \(DueDate.format(now, timeZone: timeZone)) (Zeitzone \(timeZone.identifier)).

        Antworte mit kind, text und due:
        - reminder: Der Nutzer will erinnert werden oder nennt einen Termin. due = Zeitpunkt als ISO 8601 mit Offset, z. B. 2026-01-05T10:00:00+01:00. Nennt die Eingabe keine Uhrzeit, nimm 09:00. due = null nur, wenn wirklich kein Zeitpunkt ableitbar ist.
        - question: Der Nutzer fragt etwas über gespeicherte Notizen. text = bereinigte Frage. due = null.
        - note: alles andere. due = null.
        text ist immer die Kernaussage, knapp.
        """
    }
}
