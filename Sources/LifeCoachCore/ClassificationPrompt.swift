import Foundation

/// Shared by every Classifier so models are measured against the same instructions.
/// Small models miscount weekdays and copy today's UTC offset across DST, so the prompt lists
/// the next days explicitly and asks for local time without offset (parsed in the device time zone).
public enum ClassificationPrompt {
    public static func instructions(now: Date, timeZone: TimeZone) -> String {
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

        return """
        Du sortierst Eingaben für ein persönliches Gedächtnis.
        Jetzt: \(day.string(from: now)), \(time.string(from: now)) Uhr.

        Die nächsten Tage:
        \(days)

        Antworte mit kind, text und due:
        - reminder: Der Nutzer will erinnert werden oder nennt etwas, das er zu einem Zeitpunkt in der Zukunft tun muss.
        - question: Der Nutzer fragt nach etwas, das er gespeichert hat — auch ohne Fragezeichen. Eine Frage nach einem Termin ist question, keine neue Erinnerung.
        - note: alles andere, auch Ideen und Vergangenes.

        due nur bei reminder, sonst null:
        - Format: lokale Zeit ohne Zeitzone, JJJJ-MM-TTTHH:MM:SS, z. B. 2026-01-05T10:00:00.
        - Wochentage und „morgen"/„übermorgen" immer aus der Liste oben ablesen, nicht selbst rechnen.
        - Konkretes Datum („am 3.11.", „20.12."), auch außerhalb der Liste: direkt übernehmen; ohne Jahr das nächste Vorkommen.
        - „in 30 min", „in 2 stunden": von der aktuellen Uhrzeit aus rechnen.
        - „in 3 tagen", „in 2 wochen": Datum ausrechnen, Uhrzeit 09:00.
        - Sonst keine Uhrzeit genannt: 09:00.
        - Kein Zeitpunkt ableitbar („irgendwann", „muss dran denken"): null.

        text ist immer die Kernaussage, knapp.

        Beispiele:
        - „in 20 min nudeln abgießen" → reminder
        - „dienstag 18 uhr yoga" → reminder, Datum des Dienstags aus der Liste, 18:00
        - „irgendwann fenster putzen" → reminder, due null
        - „oma mag lilien" → note
        - „idee: buch über bienen schreiben" → note
        - „war gestern beim bäcker, brot war alt" → note
        - „was mag oma für blumen" → question
        - „wann ist das yoga nochmal" → question
        """
    }
}
