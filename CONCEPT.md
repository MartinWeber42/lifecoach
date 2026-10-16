# LifeCoach — Konzept

## Vision

Ein mobiles Gehirn. Alles, was am Tag erlebt und gestaltet wird — Gedanken, Termine, Erinnerungen, Wünsche — wird in der App aufgenommen. Ein lokales KI-Modell sortiert es, trägt Erinnerungen ein und beantwortet später Fragen dazu. Keine Cloud, kein Server, keine Daten verlassen das Handy.

## User-Story (das Original-Beispiel)

> Meine Freundin sagt mir an einem Tag, was sie sich zu Weihnachten wünscht. Ich tippe es in die App. Sie notiert es. Wochen später frage ich: „Was wünscht sich meine Freundin zu Weihnachten?" — und die App antwortet: „Eine Keramikvase."

**Was die Story eigentlich beweist:** Der Wert liegt im *Wiederfinden* (Abfragen), nicht im Sortieren. Sortieren ist Mittel zum Zweck. Die Roadmap priorisiert deshalb den Abfrage-Pfad früh (siehe `ROADMAP.md`).

## Zielgruppe & Abgrenzung

- **Nutzer:** eine Person, ein iPhone. Kein Teilen, keine Accounts, kein Multi-Device.
- **Kein Ersatz für** Kalender, Erinnerungen-App oder Notizen-App — LifeCoach ist der *Eingang* („einfach reintippen, nicht einsortieren") und das *Gedächtnis* („frag mich später").
- **Erfolgskriterium:** Der Nutzer tippt Dinge lieber in LifeCoach als in Apple Notizen, weil er sie dort wiederfindet, ohne sich zu erinnern, *wo* er sie abgelegt hat.

## Domänen-Sprache

Testnamen und Identifier orientieren sich an diesen Begriffen.

| Begriff (DE / Code) | Bedeutung |
|---|---|
| Eingabe / `Capture` | Rohtext, den der Nutzer eintippt. Wird nicht verändert gespeichert (`rawText`). |
| Klassifizierung / `Classification` | Ergebnis des LLM nach Schema: `kind`, `text`, `due`. |
| Notiz / `note` | Etwas Merkenswertes ohne Zeitpunkt („Lisa wünscht sich eine Keramikvase"). |
| Erinnerung / `reminder` | Etwas mit Zeitpunkt, an das die App aktiv erinnern soll. |
| Frage / `question` | Anfrage an das Gedächtnis. Wird beantwortet, **nicht** als Eintrag gespeichert. |
| Eintrag / `Entry` | Gespeicherte Notiz oder Erinnerung (persistiert). |
| Antwort / `Answer` | Text + Liste der Quell-Einträge, auf die sie sich stützt. |
| Fälligkeit / `dueAt` | Zeitpunkt einer Erinnerung, vom Nutzer bestätigt. |
| Erledigt / `doneAt` | Nutzer hat die Erinnerung abgehakt. |

## Kernfunktionen

1. **Aufnehmen** — ein Textfeld, kein Formular. App sortiert automatisch (später: Voice).
2. **Sortieren** — on-device LLM klassifiziert nach Schema. Ergebnis ist sichtbar und **korrigierbar** (Typ ändern, Zeitpunkt ändern).
3. **Erinnern** — beim Speichern einer Erinnerung wird eine lokale Notification geplant. Kein Polling, kein Server.
4. **Abfragen** — Fragen werden aus den eigenen Einträgen beantwortet, **mit Quellenangabe**. Findet die App nichts, sagt sie das — sie erfindet nichts.

## Kern-Flows

### Flow A — Aufnehmen

```
Eingabe → Klassifizierung (LLM) → Vorschau-Zeile → Speichern
                                       │
                                       └─ Nutzer kann Typ/Zeitpunkt korrigieren
```

- Klassifizierung läuft beim Absenden, Ergebnis erscheint als Zeile mit Typ-Icon und ggf. Zeitpunkt.
- **Reminder ohne ableitbaren Zeitpunkt** (`due = null`): App fragt nach („Wann soll ich dich erinnern?") — DatePicker, kein zweiter LLM-Call.
- **Speichern ist nie blockiert:** Fällt das LLM aus oder dauert > 3 s, wird als `note` gespeichert und kann nachträglich umklassifiziert werden.

### Flow B — Erinnern

- Speichern einer Erinnerung mit `dueAt` in der Zukunft → `UNCalendarNotificationTrigger` wird geplant (Identifier = Entry-ID).
- Ändern/Löschen eines Eintrags → Notification wird ersetzt/entfernt.
- Notification-Aktionen: „Erledigt", „In 1 Stunde". 
- **iOS-Limit:** max. 64 ausstehende lokale Notifications pro App. MVP plant die nächsten 64 Fälligkeiten; beim App-Start und nach jeder Änderung wird neu geplant.

### Flow C — Abfragen

```
Frage → Retrieval (Kandidaten-Einträge finden) → LLM antwortet nur aus Kandidaten → Antwort + Quellen
```

- Das LLM bekommt **nicht** alle Einträge, sondern nur die relevantesten (siehe *Retrieval*).
- Prompt-Regel: „Antworte ausschließlich aus den folgenden Einträgen. Wenn sie die Antwort nicht enthalten, antworte: ‚Dazu habe ich nichts gespeichert.'"
- Die UI zeigt unter der Antwort die Quell-Einträge mit Datum — der Nutzer kann die Antwort selbst prüfen.

## Architektur

- **Native iOS-App** (SwiftUI), Mindestversion **iOS 26**.
- **LLM, Ziel:** Apple Foundation Models Framework (on-device, kein Download, gratis).
- **LLM, Brücke (jetzt):** Claude Haiku (`claude-haiku-5-5`) per Messages API, direkt aus der App via `URLSession` (kein offizielles Swift-SDK). Strukturierte Ausgabe über `output_config.format` (JSON-Schema) — dasselbe Schema wie on-device. API-Key gibt der Nutzer in den Einstellungen ein, gespeichert in der Keychain, nie im Code/Repo. Ausgabenlimit in der Anthropic Console.
  - Strukturierte Ausgabe über **Guided Generation** (`@Generable`) statt freiem JSON-Parsing. Das Schema (`kind`/`text`/`due`) bleibt identisch, nur der Transport wird robuster.
  - **Kein** Private-Cloud-Compute-Modell, kein weiterer Cloud-Dienst neben der Haiku-Brücke.
- **Speicher:** SwiftData.
- **Erinnerungen:** `UNUserNotificationCenter`.
- **Retrieval:** zunächst lexikalisch (Stichwort-/Token-Overlap über `rawText` + `text`), Embeddings (`NLEmbedding`) erst wenn die Eval-Suite zeigt, dass es nötig ist.
- **Datums-Logik:** LLM liefert `due`; die App validiert (parsebar, nicht in der Vergangenheit) und zeigt es zur Bestätigung. Relative Ausdrücke („übermorgen", „nächsten Dienstag") werden in der Eval-Suite explizit gemessen.

### Modul-Schnitt (minimal)

```
LifeCoachApp (SwiftUI Views)
 ├─ Classifier        protocol  → FoundationModelClassifier | FakeClassifier (Tests)
 ├─ Answerer          protocol  → FoundationModelAnswerer   | FakeAnswerer   (Tests)
 ├─ Retriever         struct    → Kandidaten zu einer Frage aus [Entry]
 ├─ ReminderScheduler protocol  → UNReminderScheduler        | FakeScheduler  (Tests)
 └─ Entry             @Model    (SwiftData)
```

Protokolle nur dort, wo ein System-Seiteneffekt (LLM, Notifications) im Test ersetzt werden muss — sonst keine Abstraktion.

### Harte Grenzen des On-Device-Modells

- **Kontextfenster: 4096 Tokens, geteilt zwischen Eingabe und Ausgabe.** „Alle Notizen ins Prompt" funktioniert nur für wenige hundert kurze Einträge. Deshalb ist Retrieval Pflicht, nicht Optimierung.
- **Verfügbarkeit:** Nur auf Apple-Intelligence-fähigen Geräten mit aktivierter Apple Intelligence. Die App prüft `SystemLanguageModel.default.availability` und fällt sonst in den **manuellen Modus** (Nutzer wählt Typ selbst, Abfrage = Volltextsuche).
- **Modellgröße ~3B:** stark bei Klassifizierung, schwach bei Datumsrechnung und Weltwissen — darum Datum bestätigen lassen und Antworten an Quellen binden.

## Bewiesene Kernlogik: Klassifizierungs-Schema

Aus dem Bot-Prototyp verifiziert (8/8 Tests grün). Das LLM bekommt: heutiges Datum + Nutzernachricht, antwortet NUR mit JSON:

```json
{"kind": "note" | "reminder" | "question", "text": "<Kernaussage, knapp>", "due": "<ISO-Datum oder null>"}
```

Regeln:
- `reminder`: Nutzer will erinnert werden oder nennt einen Termin → `due` = ISO-Zeitpunkt (z. B. „morgen 10 Uhr" → ISO); `null` nur, wenn wirklich kein Zeitpunkt ableitbar
- `question`: Nutzer fragt etwas über gespeicherte Notizen → `text` = bereinigte Frage
- `note`: alles andere → `due` = null

**Einschränkung:** „Bewiesen" heißt: mit dem Modell des Bot-Prototyps und 8 Beispielen. Für Apple Foundation Models auf Deutsch ist das Schema **nicht** bewiesen — das wird in M0 mit einer Eval-Suite (≥ 60 Beispiele) gemessen. Das Schema selbst bleibt unverändert (Regel 5).

**Ergänzungen der Regeln (Klarstellung, kein Schema-Change):**
- Erinnerungen haben immer eine Uhrzeit. Nennt die Eingabe keine („am Freitag"), setzt das Modell 09:00 Ortszeit; die App zeigt die Uhrzeit vorausgewählt zur Bestätigung.
- Zeitzone: immer die aktuelle Gerätezeitzone; das Prompt enthält Datum, Wochentag und Uhrzeit.

## Datenmodell

```
Entry (@Model)
  rawText: String       // Originaleingabe, unverändert
  text: String          // Kernaussage aus der Klassifizierung
  kind: note | reminder // question wird nicht persistiert
  dueAt: Date?          // nur bei reminder, vom Nutzer bestätigt
  createdAt: Date
  doneAt: Date?         // Erinnerung abgehakt
```

Änderungen gegenüber dem Bot-Datenmodell und warum:

| Bot | iOS | Grund |
|---|---|---|
| `id: Int` | entfällt | SwiftData liefert `persistentModelID`; Notification-ID wird daraus abgeleitet. |
| `kind` inkl. `question` | nur `note`/`reminder` | Fragen sind keine Erinnerungen ans Gehirn — gespeichert würden sie das Retrieval verschmutzen. |
| `sentAt` | ersetzt durch `doneAt` | Der Bot musste per Polling wissen, was schon verschickt wurde. iOS plant Notifications vorab; relevant ist nur, ob der Nutzer erledigt hat. |
| — | `rawText` neu | Kernaussage ist verlustbehaftet; Retrieval und Neu-Klassifizierung brauchen das Original. |

## Datenschutz & Datensicherheit

- Einziger Netzwerk-Endpunkt: `api.anthropic.com` (Haiku-Brücke). Mit dem Wechsel auf on-device entfällt auch dieser.
- **Bewusst akzeptiert (Brücke):** Eingaben und bei Fragen die relevanten Einträge gehen an Anthropic — auch Informationen über Dritte. Der Nutzer hat das entschieden; on-device bleibt das Ziel.
- Offline: Eingabe wird als `note` gespeichert und nachklassifiziert, sobald Netz da ist.
- Kein Analytics, kein Crash-Reporting außer dem, was Apple über TestFlight liefert (Opt-in des Nutzers).
- **Spannungsfeld Datenverlust:** „Nichts verlässt das Handy" heißt auch: Handy weg = Gehirn weg. MVP-Entscheidung: App-Daten sind Teil des normalen iOS-Geräte-Backups (Default, vom Nutzer kontrolliert, mit Advanced Data Protection Ende-zu-Ende-verschlüsselt). Zusätzlich manueller **JSON-Export** über das Share-Sheet. Kein eigener Sync.
- Dateischutz: `NSFileProtectionComplete` für den SwiftData-Store.

## Teststrategie

Zwei Ebenen, weil LLM-Ausgaben nicht deterministisch sind:

1. **Unit-Tests (Swift Testing, deterministisch, laufen immer):** Domänenlogik mit Fakes — Speichern, Umklassifizieren, Notification-Planung, Retriever-Ranking, Datumsvalidierung, Antwort-ohne-Treffer.
2. **Eval-Suite (gegen das echte Modell, auf Mac/Gerät mit Apple Intelligence):** Tabelle aus Eingabe → erwartetes `kind`/`due`, bzw. Frage + Einträge → erwartete Antwort. Ergebnis ist eine Quote, kein Grün/Rot pro Fall. Schwellen siehe Roadmap.

Testnamen in Domänensprache, z. B. `reminderWithoutTimeAsksForDueDate`, `questionIsNotPersisted`, `answerCitesSourceEntries`.

## Bewusst nicht im MVP

Voice-Input, Siri/App Intents, Widgets, wiederkehrende Erinnerungen („jeden Montag"), Tags/Ordner, Sync zwischen Geräten, Fallback-LLM (MLX/llama.cpp), Embeddings, Bearbeitung durch das LLM („ändere die Vase auf Blumen"). Begründung jeweils: YAGNI, bis Nutzung zeigt, dass es fehlt.

## Entscheidungen (getroffen)

- **Hardware:** Test-iPhone ist ein iPhone 13 (iOS 26.6) — **kein** Apple Intelligence, Foundation Models läuft darauf nicht. Mac M4 Pro (macOS 26.2) kann es; dort laufen die Evals für beide Modelle.
- **Haiku-Brücke statt MLX/llama.cpp.** Ein lokales Ersatzmodell auf 4 GB RAM wäre ein eigenes Projekt mit schwächeren Ergebnissen. Die Brücke läuft hinter denselben Protokollen wie später Foundation Models. Wann gewechselt wird: Nutzer-Entscheidung, sobald ein neues iPhone da ist, auf Basis der M0-Zahlen beider Modelle.
- **iOS 26 als Minimum.** Ohne Netz und ohne Apple Intelligence läuft die App im manuellen Modus.
- **Retrieval vor Embeddings:** lexikalisch starten, messen, erst dann Embeddings.

## Offene Fragen

- Erreicht das Foundation Model auf deutschem, umgangssprachlichem Input die Eval-Schwellen? (M0)
- Rechnet das Modell relative Datumsangaben zuverlässig, oder braucht es eine deterministische Vorstufe (`NSDataDetector`)? (M0)
- Ab wie vielen Einträgen versagt lexikalisches Retrieval bei realen Fragen? (nach 4 Wochen Nutzung messen)
- Sollen erledigte Erinnerungen beim Abfragen mitgezählt werden? („Wann war ich beim Zahnarzt?" → ja, vermutlich)
