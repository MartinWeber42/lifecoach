# LifeCoach — Konzept

## Vision

Ein mobiles Gehirn. Alles, was am Tag erlebt und gestaltet wird — Gedanken, Termine, Erinnerungen, Wünsche — wird in der App aufgenommen. Ein lokales KI-Modell sortiert es, trägt Erinnerungen ein und beantwortet später Fragen dazu. Keine Cloud, kein Server, keine Daten verlassen das Handy.

## User-Story (das Original-Beispiel)

> Meine Freundin sagt mir an einem Tag, was sie sich zu Weihnachten wünscht. Ich tippe es in die App. Sie notiert es. Wochen später frage ich: „Was wünscht sich meine Freundin zu Weihnachten?" — und die App antwortet: „Eine Keramikvase."

## Kernfunktionen

1. **Aufnehmen** — Text rein (später: Voice), App sortiert automatisch
2. **Sortieren** — on-device LLM klassifiziert: Notiz, Erinnerung/Termin, oder Frage
3. **Erinnern** — fällige Erinnerungen als lokale iOS-Notification (funktioniert bei geschlossener App, ohne Server)
4. **Abfragen** — Fragen über gespeicherte Notizen, beantwortet aus dem eigenen Gehirn

## Architektur

- **Native iOS-App** (SwiftUI)
- **LLM on-device:** Apple Foundation Models (iOS 26+, gratis, kein Model-Download) — Fallback für ältere Geräte: MLX-Swift oder llama.cpp mit quantisiertem 3B-Modell (Gemma 3n, Llama 3.2 3B; laut Recherche reichen 3B für Klassifizierungs-Aufgaben, 7–8B brauchen 12+ GB RAM)
- **Speicher:** SwiftData
- **Erinnerungen:** UNUserNotificationCenter — kein laufender Server nötig
- **Kein Cloud-Inference.** DSGVO by design.

## Warum kein Telegram-Bot (verworfen)

Ein Bot läuft serverseitig: Nachrichten gehen an einen Rechner, der an sein muss; Erinnerungen kommen nur dann. On-device-KI auf dem Smartphone geht nur in nativen Apps. Datenschutz: Notizen gehen bei Telegram eh über Telegram-Server — der LLM-Schritt war nie der Engpass. Der Bot wurde als Tracer Bullet gebaut und verworfen; seine bewiesene Kernlogik (unten) wird 1:1 portiert.

## Bewiesene Kernlogik: Klassifizierungs-Schema

Aus dem Bot-Prototyp verifiziert (8/8 Tests grün). Das LLM bekommt: heutiges Datum + Nutzernachricht, antwortet NUR mit JSON:

```json
{"kind": "note" | "reminder" | "question", "text": "<Kernaussage, knapp>", "due": "<ISO-Datum oder null>"}
```

Regeln:
- `reminder`: Nutzer will erinnert werden oder nennt einen Termin → `due` = ISO-Zeitpunkt (z. B. „morgen 10 Uhr" → ISO); `null` nur, wenn wirklich kein Zeitpunkt ableitbar
- `question`: Nutzer fragt etwas über gespeicherte Notizen → `text` = bereinigte Frage
- `note`: alles andere → `due` = null

## Datenmodell

```
Note
  id: Int
  text: String          // Kernaussage
  kind: note | reminder | question
  dueAt: Date?          // nur bei reminder
  createdAt: Date
  sentAt: Date?         // Notification bereits gefeuert
```

## Meilensteine

1. **M1 — Grundgerüst:** Xcode-Projekt, SwiftData-Modell, Text-Eingabe, Notizen speichern/listen
2. **M2 — Sortierung:** on-device Klassifizierung nach Schema (note/reminder/question)
3. **M3 — Erinnerungen:** Datumsextraktion, Notifications für fällige Erinnerungen
4. **M4 — Fragen:** Antworten aus gespeicherten Notizen
5. **M5 — optional:** Voice-Input, Siri, Widgets

## Offene Fragen

- Minimum iOS-Version: iOS 26 (Foundation Models direkt) vs. iOS 17 + llama.cpp-Fallback?
- Wie gut klassifiziert das Foundation Model deutsches, umgangssprachliches Input? (im M2 messen)
- Lokale Suche über Notizen: mitwachsende Notizenmenge → einfache Inklusion ins Prompt vs. Embeddings?
