# LifeCoach — MVP-Roadmap

**MVP-Ziel:** Die Original-User-Story funktioniert auf dem eigenen iPhone über TestFlight — aufnehmen, erinnert werden, Wochen später fragen und eine belegte Antwort bekommen. Ein Nutzer, ein Gerät, Deutsch.

**Reihenfolge-Prinzip:** Risiko zuerst. Das größte Risiko ist nicht die UI, sondern ob das On-Device-Modell auf Deutsch gut genug klassifiziert und antwortet. Deshalb startet die Roadmap mit einem Mess-Spike (M0), und der Abfrage-Pfad kommt vor dem Feinschliff der Erinnerungen.

Jeder Meilenstein ist ein **vertikaler Slice**: am Ende läuft etwas Benutzbares auf dem Gerät, TDD mit Swift Testing.

---

## M0 — Machbarkeits-Spike (Go/No-Go) — ✅ Go für Haiku (16.10.2026)

**Frage:** Trägt Apple Foundation Models das Konzept?

- Xcode-Projekt + Swift-Testing-Target anlegen (iOS 26).
- **Misst beide Modelle mit denselben Daten:** Haiku (Brücke, läuft auf dem iPhone 13) und Foundation Models (Ziel, nur auf dem Mac messbar). So ist der Abstand bekannt, bevor die Brücke abgelöst wird.
- Eval-Datensatz `Evals/classification.json` ✅ (67 Fälle, Format in `Evals/README.md`): ≥ 60 deutsche Eingaben, umgangssprachlich, mit Tippfehlern, ~⅓ je `kind`; davon ≥ 20 mit relativen Datumsangaben („übermorgen", „nächsten Di um 3", „in zwei Wochen").
- Eval-Datensatz `Evals/answering.json` ✅ (16 Fälle): ≥ 15 Fälle (Einträge + Frage + erwartete Antwort), davon ≥ 5, bei denen die richtige Antwort „nichts gespeichert" ist.
- Swift-Paket `LifeCoachCore` ✅ (ungetestet kompiliert — erster Build auf dem Mac): `HaikuClassifier` und `FoundationModelClassifier` hinter `Classifier`.
- Eval-Runner ✅ (`ClassificationEval`, nur mit `LIFECOACH_EVAL` gesetzt), gibt Trefferquoten aus. Aufruf siehe `Evals/README.md`.
- Abfrage-Eval (`answering.json`) folgt mit dem `Answerer` in M2.

**Exit-Kriterien:**
| Metrik | Schwelle |
|---|---|
| `kind` korrekt | ≥ 90 % |
| `due` korrekt (± 0 min bei expliziter Zeit, richtiger Tag bei Tagesangabe) | ≥ 85 % |
| Antwort korrekt **oder** korrekt „nichts gespeichert" | ≥ 80 % |
| Halluzinierte Antwort bei „nichts gespeichert"-Fällen | 0 |
| Klassifizierungs-Latenz (Median, Gerät) | ≤ 2 s |

**Schwellen gelten für das Modell, mit dem die App gerade läuft** (zunächst Haiku). Foundation-Models-Zahlen sind die Entscheidungsgrundlage für den späteren Wechsel.

**Wenn verfehlt:** `due` zu schlecht → deterministische Vorstufe mit `NSDataDetector`, LLM nur für `kind`/`text`. `kind` zu schlecht → Prompt/Few-Shot iterieren, erst dann über Schema reden (Regel 5: nur mit Absprache). Antworten zu schlecht → Retrieval enger, Antwortformat strikter.

**Ergebnis Klassifizierung (Mac M4 Pro, 16.10.2026, Prompt-Stand `9527e82`):**

| Modell | kind | due | Median | Urteil |
|---|---|---|---|---|
| Claude Haiku 5.5 (Lauf 1 / 2) | 66/67 · 67/67 | 24/25 · 24/25 | 1,3 s · 1,2 s | ✅ alle Schwellen |
| Apple Foundation Models | 52/67 (78 %) | 12/25 (48 %) | 1,0 s | ❌ |

Befunde Apple-Modell (für den späteren Wechsel):
- Datumsrechnung unzuverlässig, auch mit Kalenderliste: Wochentage um einen Tag verschoben, „in 30 min" = jetzt, falsches Jahr. → Wechsel nur mit deterministischer Datums-Vorstufe (`NSDataDetector`), LLM dann nur für `kind`/`text`.
- Fragen weiterhin oft als `note` erkannt.
- **Guardrail-Fehlalarme** bei harmlosen Eingaben („hab jonas 50€ geliehen", „versicherung kündigen", „welcher italiener war gut") — 4/67 blockiert. Für ein Gedächtnis, das alles aufnehmen soll, ein eigenes Risiko.
- Bewusst **kein weiteres Prompt-Tuning** für das Apple-Modell jetzt: Es läuft auf dem iPhone 13 ohnehin nicht. Neu messen, wenn ein neues iPhone ansteht.

Haiku-Restfehler sind uneinheitlich zwischen Läufen (nicht-deterministisch) und echte Mehrdeutigkeiten („nächste woche mittwoch") — abgedeckt durch die Bestätigung des Zeitpunkts in der UI (M1/M3).

Abfrage-Eval (`answering.json`) steht noch aus → M2.

---

## M1 — Aufnehmen & Liste (Slice: tippen → sehen)

- `Entry`-Modell (SwiftData) laut Konzept.
- Ein Eingabefeld unten, chronologische Liste oben (neueste unten, Chat-artig).
- Klassifizierung beim Absenden; Typ-Icon + Fälligkeit in der Zeile.
- Korrigieren: Typ umschalten, Fälligkeit per DatePicker, Löschen per Swipe.
- Fallback: LLM nicht verfügbar / Timeout 3 s → als `note` speichern; manueller Modus bei fehlender Apple Intelligence.

**Tests (Beispiele):** `captureIsSavedAsEntry`, `classifierTimeoutSavesAsNote`, `userCanChangeKindAfterClassification`, `unavailableModelEntersManualMode`.

**Done:** Auf dem Gerät 1 Tag lang echte Eingaben gemacht, nichts verloren.

---

## M2 — Abfragen (Slice: fragen → belegte Antwort)

> Aufgeteilt in **M2a Gedächtnis** (Extraktion, Fakten, Personen/Aliase) und **M2b Abfragen** (Retriever, Answerer) — Details und Reihenfolge in `MEMORY.md`.

*Vorgezogen, weil es der Kern der User-Story ist.*

- `question` wird erkannt und **nicht** gespeichert, sondern beantwortet.
- `Retriever`: lexikalisches Ranking (normalisierte Tokens, Stoppwörter raus, Overlap-Score) über `rawText` + `text`, Top-N passend ins Token-Budget.
- `FoundationModelAnswerer`: Antwort nur aus Kandidaten; „Dazu habe ich nichts gespeichert" als erlaubte Antwort.
- Antwort-Bubble mit aufklappbaren Quell-Einträgen (Datum + Text).
- Ohne Modell: Abfrage zeigt nur die Retriever-Treffer (Suche).

**Tests:** `questionIsNotPersisted`, `retrieverRanksMatchingEntryFirst`, `retrieverRespectsTokenBudget`, `answerCitesSourceEntries`, `noCandidatesYieldsNothingStored`.

**Done:** Original-Story auf dem Gerät durchgespielt („Keramikvase"). Eval-Antwortquote aus M0 hält mit echtem Retriever.

---

## M3 — Erinnern (Slice: Termin tippen → Notification kommt)

- Notification-Berechtigung beim ersten `reminder` anfragen (nicht beim App-Start).
- `ReminderScheduler`: plant beim Speichern, ersetzt beim Ändern, entfernt beim Löschen/Erledigen.
- Re-Scheduling der nächsten 64 Fälligkeiten bei App-Start und nach Änderungen.
- Notification-Aktionen „Erledigt" und „In 1 Stunde".
- `reminder` ohne `due` → Nachfrage per DatePicker.
- `due` in der Vergangenheit → Hinweis, nicht stillschweigend planen.

**Tests:** `savingReminderSchedulesNotification`, `deletingReminderRemovesNotification`, `markingDoneCancelsNotification`, `onlyNext64RemindersAreScheduled`, `pastDueIsRejected`, `reminderWithoutTimeAsksForDueDate`.

**Done:** Eine Erinnerung für „in 5 Minuten" kommt bei geschlossener App und gesperrtem Gerät an; „Erledigt" aus der Notification heraus hakt den Eintrag ab.

---

## M4 — MVP-Release (TestFlight)

- JSON-Export über Share-Sheet.
- `NSFileProtectionComplete` für den Store.
- Leerer Zustand mit 2–3 Beispiel-Eingaben als Hilfe.
- App-Icon, Name, Privacy-Manifest (Brücke: Eingaben gehen an Anthropic zur Verarbeitung).
- TestFlight-Build, 2 Wochen Eigennutzung.

**MVP ist erreicht, wenn:**
1. Original-User-Story auf dem Gerät nach ≥ 2 Wochen echter Nutzung funktioniert.
2. Keine verlorene Eingabe, keine verpasste Erinnerung in diesen 2 Wochen.
3. Die App spricht mit keinem Endpunkt außer `api.anthropic.com`.

---

## Nach dem MVP (nur wenn Nutzung es verlangt)

| Kandidat | Auslöser, ab dem es sich lohnt |
|---|---|
| Embeddings-Retrieval (`NLEmbedding`) | Fragen finden reale Einträge nicht, weil andere Wörter benutzt wurden |
| Voice-Input | Eingaben werden unterwegs ausgelassen, weil Tippen zu langsam ist |
| Siri / App Intents / Widget | Öffnen der App ist der Engpass |
| Wiederkehrende Erinnerungen | ≥ 3 wiederkehrende Dinge werden manuell immer neu angelegt |
| Wechsel Haiku → Foundation Models | Neues iPhone da und M0-Zahlen von Foundation Models reichen (Nutzer-Entscheidung) |

## Risiken

| Risiko | Wirkung | Gegenmaßnahme |
|---|---|---|
| Modell klassifiziert Deutsch schlecht | Kern bricht | M0 misst vor jedem UI-Code |
| Falsche Datumsrechnung | Erinnerung zur falschen Zeit | Bestätigung in UI, `NSDataDetector`-Vorstufe als Plan B |
| Halluzinierte Antworten | Vertrauensverlust | Antwort nur aus Kandidaten, Quellen sichtbar, Eval-Fälle „nichts gespeichert" |
| 4096-Token-Kontext | Abfragen versagen mit wachsendem Bestand | Retrieval mit Token-Budget ab M2 |
| Apple ändert Modell per OS-Update | Qualität schwankt | Eval-Suite nach jedem iOS-Update erneut laufen lassen |
| Datenverlust | Gehirn weg | iOS-Backup + JSON-Export |
