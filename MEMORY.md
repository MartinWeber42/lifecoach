# LifeCoach — Gedächtnis-Architektur

Wie, wo, was und wann gespeichert wird, damit Fragen Wochen später richtig beantwortet werden.
Ergänzt `CONCEPT.md` (Datenmodell) und `ROADMAP.md` (M1/M2). Stand: 16.10.2026.

## Das Problem in einem Satz

Die Original-Story scheitert mit dem jetzigen Konzept: Gespeichert wird „**Lisa** wünscht sich eine Keramikvase", gefragt wird „Was wünscht sich **meine Freundin**?". Kein Wort überlappt — eine Stichwortsuche findet nichts. Qualität entsteht nicht durch die Datenbank (SwiftData reicht), sondern durch drei Dinge:

1. **Was beim Aufnehmen herausgezogen wird** (atomare Fakten, Personen, absolute Zeitpunkte)
2. **Wie Personen und Bezeichnungen zusammengeführt werden** (Aliase)
3. **Wie Widersprüche behandelt werden** (Lisa wünscht sich später doch ein Buch)

## Was die Forschung sagt (und was wir übernehmen)

| Quelle | Erkenntnis | Übernahme für LifeCoach |
|---|---|---|
| LongMemEval (ICLR 2025) | Gedächtnis = **Indexieren → Finden → Lesen**. Fünf Fähigkeiten: Faktenabfrage, mehrere Einträge verknüpfen, Zeitbezug, Wissens-Update, Enthaltung („weiß ich nicht"). Assistenten verlieren ~30 % Genauigkeit über lange Verläufe. Fakten als zusätzliche Suchschlüssel und zeitbewusste Anfrage-Erweiterung verbessern Treffer. | Eval-Kategorien 1:1 übernehmen. Fakten zusätzlich zum Rohtext indexieren. Zeitbezug der Frage („diese Woche") in einen Datumsfilter übersetzen. |
| Mem0 (2025) | Zweistufig: **Extraktion** von Kandidaten-Fakten, dann **Update**-Entscheidung gegen ähnliche bestehende Fakten (ADD / UPDATE / DELETE / NOOP). | Extraktion übernehmen. Update ja — aber **ohne DELETE** (siehe Zep). |
| Zep / Graphiti (2025) | Drei Schichten: **Roh-Episoden → Fakten/Entitäten → Zusammenfassungen**. **Bi-temporal**: wann etwas passierte vs. wann es gespeichert wurde. Widersprochene Fakten werden **nicht gelöscht**, sondern mit Ende-Zeitpunkt invalidiert. | Episoden = `Entry` (append-only), Fakten = `Fact`, Entitäten = `Person`. Zusammenfassungen: YAGNI. Invalidieren statt löschen. |
| Anthropic Contextual Retrieval | Hybrid aus Stichwort (BM25) + Embeddings senkt Fehlgriffe deutlich; Kontext vor dem Indexieren anreichern hilft weiter. | Fakten sind bereits „angereicherter Kontext" (Person + Aussage). Hybrid erst, wenn die Eval es verlangt. |
| Long Context vs. RAG | Kleine, private Korpora (< ~100k Tokens) gehen auch komplett ins Prompt — aber Fakten in der Mitte gehen eher verloren; „effektive" Kontextlänge ist kürzer als die beworbene. | Nicht alles schicken: gezielt Kandidaten wählen. Spart Datenabfluss (Brücke) und passt später ins 4096-Token-Fenster on-device. |
| PKM / Second Brain | Schnell roh erfassen, später verarbeiten; atomare Notiz = eine Aussage, die ohne Quelle verständlich ist. | Aufnahme blockiert nie. Verarbeitung läuft danach im Hintergrund und erzeugt atomare Fakten. |

## Architektur: drei Schichten

```
Eingabe ──► Entry (Rohtext, unveränderlich) ──► Vorstufe (lokal, ohne KI)
                                                   ├─ Geheimnis-Filter → privat: bleibt auf dem Gerät, Ende
                                                   └─ Personen-Vorerkennung → bekannte Personen als Kontext
                                               ──► Verarbeitung (LLM, Hintergrund)
                                                   ├─ Klassifizierung (bestehendes Schema)
                                                   ├─ Extraktion → Fact[] + Personen + Aliase
                                                   └─ Abgleich → ältere Fakten als „ersetzt" markieren

Frage ──► Kandidaten finden (Personen/Aliase, Stichworte, Zeitraum) ──► LLM antwortet nur daraus ──► Antwort + Quellen
```

### Vorstufe — lokal, ohne KI (entschieden 16.10.2026)

Läuft vor jedem KI-Aufruf, deterministisch, vollständig per Unit-Test abgedeckt. Sortiert **nicht** (Haiku sortiert 98 % richtig — eine Regel davor kann nur Fehler hinzufügen), sondern schützt Daten und gibt der KI Kontext.

**1. Geheimnis-Filter** — Einträge mit einem dieser Wörter (Wortgrenze, Groß/Klein egal) gehen **nie** an ein Modell:
`passwort`, `kennwort`, `pw`, `pin`, `puk`, `tan`, `code`, `geheimzahl`, `zugangsdaten`, `login`, `iban`, `geheim`
- Gespeichert als `note` mit `isPrivate = true`, keine Fakten, keine Klassifizierung.
- Wiederfinden nur per Stichwort über `rawText` („wie war das wlan pw" findet „wlan pw bei den eltern …"). Bei privaten Treffern zeigt die App den Eintrag selbst an, ohne KI-Antwort.
- Fehlalarme („code review morgen") kosten nur die Sortierung: Der Eintrag wird Notiz statt Erinnerung. Lieber zu vorsichtig als ein Passwort bei Anthropic.
- Gilt ab **M1**, weil schon die Klassifizierung Text an Haiku schickt.

**2. Personen-Vorerkennung** — bekannte Namen und bestätigte Aliase per Textvergleich im Rohtext finden und dem Extraktions-Aufruf mitgeben:
`Bekannte Personen: Lisa (= meine Freundin), Tom, Jonas (Nachbar)`
- Hält Namen einheitlich: Die KI ordnet „meine freundin" der vorhandenen Person Lisa zu, statt eine neue anzulegen.
- Dieselbe Funktion erkennt beim Fragen die Personen (siehe *Abfragen*, Schritt 1) — ein Stück Code, zwei Einsätze.

**3. Fragen-Abkürzung** — Eingabe endet auf „?" → direkt beantworten, ohne Klassifizierungs-Aufruf. **Zurückgestellt**, bis die Wartezeit bei Fragen stört.

**Unit-Tests (Swift Testing, vor dem Code):**
- `entryWithPasswordStaysOnDevice` — „wlan pw bei den eltern ist sonnenblume42" → `isPrivate`, kein `Classifier`-Aufruf
- `secretKeywordMatchesWholeWordOnly` — „pinnwand aufräumen" ist **nicht** privat, „pin 1234" schon
- `entryMarkedSecretStaysOnDevice` — „anna ist schwanger, noch geheim!" → privat
- `privateEntryIsFoundByKeyword` — Frage „wlan pw?" findet den privaten Eintrag ohne Modell
- `knownPersonIsDetectedByAlias` — Alias „meine Freundin" → Lisa wird in „meine freundin mag rosen" erkannt
- `unconfirmedAliasIsIgnored` — nur bestätigte Aliase zählen

### Schicht 1 — Rohspeicher (`Entry`)

- **Append-only.** `rawText` wird nie vom LLM verändert. Er ist die Wahrheit, alles andere ist abgeleitet und jederzeit neu erzeugbar.
- `processedVersion: Int?` — welche Version der Verarbeitung gelaufen ist (`nil` = noch nicht, z. B. offline). Wird der Prompt oder das Modell gewechselt (Haiku → Foundation Models), werden alle Einträge aus dem Rohtext neu verarbeitet.
- Nutzer kann Einträge löschen → abgeleitete Fakten werden mitgelöscht (das einzige echte Löschen).

### Schicht 2 — Fakten (`Fact`)

Eine Aussage pro Fakt, in sich verständlich, Personen ausgeschrieben, Zeit absolut:

| Eingabe | Fakten |
|---|---|
| „lisa wünscht sich zu weihnachten ne keramikvase" | „Lisa wünscht sich zu Weihnachten eine Keramikvase." |
| „neuer nachbar heißt jonas, hat nen hund namens bello" | „Der neue Nachbar heißt Jonas." · „Jonas hat einen Hund namens Bello." |
| „gestern 5km gelaufen in 28 min" | „Ich bin 5 km in 28 Minuten gelaufen." `eventDate` = 15.10.2026 |
| „meine freundin lisa mag keine rosen" | „Lisa mag keine Rosen." + Alias-Vorschlag „meine Freundin" → Lisa |

- **Bi-temporal:** `eventDate` = wann es passiert ist bzw. gilt (falls genannt), `createdAt` kommt vom Entry = wann es gespeichert wurde. „Wann war ich zuletzt joggen" nutzt `eventDate`, nicht das Speicherdatum.
- **Ersetzen statt löschen:** `supersededBy: Fact?`. Abfragen nutzen nur aktuelle Fakten, die UI kann die Historie zeigen („früher: Kerze").
- Reminder bekommen ebenfalls Fakten („Zahnarzttermin am 20.10. um 15:00"), damit „wann ist mein Zahnarzttermin" funktioniert.

### Schicht 3 — Personen (`Person`)

- `name` („Lisa") + `aliases` („meine Freundin", „Freundin", „Schatz").
- Der wichtigste Hebel für die Original-Story. Personen sind die häufigste Mehrdeutigkeit; Dinge („Fahrradschloss", „WLAN") werden meist gleich benannt und laufen über Stichworte.
- **Aliase werden nie still übernommen:** Die Extraktion *schlägt vor*, der Nutzer bestätigt mit einem Tipp („Ist ‚meine Freundin' = Lisa?"). Falsche Aliase vergiften jede spätere Antwort.
- Keine weiteren Entitätstypen (Orte, Themen) — YAGNI, bis die Eval Fehler zeigt.

## Datenmodell (ersetzt das in `CONCEPT.md`)

```
Entry (@Model)                 // Schicht 1
  rawText: String
  createdAt: Date
  kind: note | reminder        // aus der Klassifizierung, question wird nie gespeichert
  dueAt: Date?
  doneAt: Date?
  processedVersion: Int?
  isPrivate: Bool              // Geheimnis-Filter: nie an ein Modell
  facts: [Fact]                // cascade delete

Fact (@Model)                  // Schicht 2
  statement: String
  people: [Person]
  eventDate: Date?
  supersededBy: Fact?
  entry: Entry

Person (@Model)                // Schicht 3
  name: String
  aliases: [String]            // nur bestätigte
```

## Verarbeitung: wann passiert was

| Zeitpunkt | Was | Wo | Blockiert UI? |
|---|---|---|---|
| Absenden | `Entry` mit `rawText` speichern | SwiftData | nein, sofort |
| direkt danach | **Geheimnis-Filter** — bei Treffer `isPrivate`, Verarbeitung endet hier | Vorstufe | nein |
| direkt danach | **Personen-Vorerkennung** für den Extraktions-Kontext | Vorstufe | nein |
| direkt danach | Klassifizierung (bestehendes Schema, unverändert) | `Classifier` | nein, Ergebnis erscheint in der Zeile |
| direkt danach | **Extraktion**: Fakten, Personen, `eventDate`, Alias-Vorschläge | `Extractor` (neu) | nein |
| direkt danach | **Abgleich**: aktuelle Fakten derselben Personen laden, LLM entscheidet, welche ersetzt werden | `Extractor` (gleicher Aufruf) | nein |
| App-Start / wieder online | Einträge mit `processedVersion == nil` nachverarbeiten | Hintergrund | nein |
| Versionswechsel | alles aus `rawText` neu verarbeiten | Hintergrund | nein |
| bei Bedarf (Nutzer) | Alias-Vorschläge bestätigen, ersetzte Fakten ansehen | UI | — |

**Extraktion und Klassifizierung bleiben getrennt.** Das Klassifizierungs-Schema ist laut `AGENTS.md` Regel 5 fest — die Extraktion ist ein eigener, zweiter Aufruf mit eigenem Schema:

```json
{
  "facts": [{"statement": "…", "people": ["Lisa"], "eventDate": "2026-10-15" | null}],
  "aliasSuggestions": [{"alias": "meine Freundin", "person": "Lisa"}],
  "supersedes": ["<id eines bestehenden Fakts>"]
}
```

Kosten Brücke [Schätzung]: ~600 Tokens pro Eingabe → bei 50 Eingaben/Tag deutlich unter 1 € im Monat.

## Abfragen: wie gefunden wird

1. **Personen erkennen** — deterministisch: Namen und bestätigte Aliase der Frage per Textvergleich (kleingeschrieben, ohne Satzzeichen). Kein LLM nötig, kein Fehler möglich.
2. **Zeitraum erkennen** — „diese Woche", „gestern", „zuletzt": im Antwort-Prompt mit derselben Kalenderliste wie bei der Klassifizierung; bei „zuletzt" nach `eventDate` sortieren.
3. **Kandidaten** = aktuelle Fakten der erkannten Personen ∪ Stichwort-Treffer über alle aktuellen Fakten (normalisierte Tokens, Stoppwörter raus) ∪ Fakten im Zeitraum.
4. **Budget**: höchstens ~2.500 Tokens Kandidaten, die besten zuerst *und* zuletzt im Prompt (gegen „lost in the middle"). Gilt auch für die Brücke — gleiche Logik wie später on-device, weniger Datenabfluss.
5. **Antwort** nur aus Kandidaten, mit Fakt-IDs als Quellen; ohne passende Kandidaten: „Dazu habe ich nichts gespeichert." Die UI zeigt die Quell-Einträge.
6. **Embeddings** (`NLContextualEmbedding`, Latin-Modell, on-device) **erst**, wenn die Eval zeigt, dass Stichworte + Aliase nicht reichen.

## Eval-Erweiterung (vor dem Code, TDD)

`answering.json` deckt bisher nur Faktenabfrage und Enthaltung ab. Neu, angelehnt an LongMemEval:

| Kategorie | Beispiel | Prüft |
|---|---|---|
| Alias | Eintrag „Lisa wünscht sich …" + Alias Freundin→Lisa; Frage „was wünscht sich meine freundin" | Schicht 3 |
| Wissens-Update | „lisa wünscht sich ne kerze" (Sept.), „lisa will doch lieber ein buch" (Okt.); Frage → „Buch" | `supersededBy` |
| Zeitbezug | „gestern 5km gelaufen" (15.10.), „heute wieder gelaufen" (16.10.); „wann war ich zuletzt joggen" → 16.10. | `eventDate` |
| Mehrere Einträge | „was weiß ich über jonas" → Nachbar + Bello + 50 € | Personen-Kandidaten |
| Enthaltung mit Falle | „welche schuhgröße hat tom" (nur Lisas gespeichert) | keine Halluzination |

Plus `Evals/extraction.json`: Eingabe → erwartete Personen, `eventDate`, Alias-Vorschläge (Text der Fakten wird nicht exakt verglichen).

**Schwellen:** Antworten ≥ 80 % korrekt, **0** Halluzinationen bei Enthaltung, Alias- und Update-Fälle ≥ 90 %.

## Wann: Einordnung in die Roadmap

| Schritt | Inhalt | Meilenstein |
|---|---|---|
| 1 | `Entry` append-only mit `rawText`, `processedVersion`, `isPrivate` | **M1** (läuft) |
| 1b | Geheimnis-Filter vor der Klassifizierung | **M1** |
| 2 | Eval-Fälle: `extraction.json` + erweiterte `answering.json` | **M2a** |
| 3 | Personen-Vorerkennung, `Extractor` (Haiku) + `Fact` + `Person`, Abgleich mit `supersededBy` | **M2a** |
| 4 | Alias-Bestätigung in der UI (ein Banner, kein eigener Screen) | **M2a** |
| 5 | Retriever (Personen + Stichworte + Zeitraum), `Answerer`, Antwort mit Quellen | **M2b** |
| 6 | Nachverarbeitung offline / nach Versionswechsel | **M2b** |
| 7 | Embeddings, nur falls Eval < Schwelle | nach MVP |

## Bewusst nicht

Wissensgraph mit Kanten und Gemeinschafts-Zusammenfassungen (Zep), Vektor-Datenbank, eigene FTS-Engine (GRDB/FTS5), automatische Wochen-Zusammenfassungen, weitere Entitätstypen. Bei einem Nutzer und wenigen tausend Fakten bringt das Komplexität ohne messbaren Gewinn — die Eval entscheidet, ob etwas davon nötig wird.

## Risiken

| Risiko | Gegenmaßnahme |
|---|---|
| Geheimnis-Filter übersieht etwas („mein schlüssel liegt unter der matte") | Liste ist bewusst erweiterbar; Nutzer kann später einen Eintrag manuell als privat markieren (nach MVP) |
| LLM markiert einen Fakt fälschlich als ersetzt | Nie löschen, nur markieren; Historie sichtbar; Update-Fälle in der Eval |
| Falscher Alias vergiftet Antworten | Aliase nur nach Bestätigung |
| Extraktion verliert Details | `rawText` bleibt Quelle; Neuverarbeitung jederzeit möglich; Antwort zeigt Original-Eintrag |
| Doppelter LLM-Aufruf pro Eingabe (Kosten/Latenz) | Läuft im Hintergrund; Cent-Beträge |
| Apple-Modell später schwächer bei Extraktion | Gleiche Eval vor dem Wechsel; Neuverarbeitung aus Rohtext |

## Quellen

- [LongMemEval (Wu et al., ICLR 2025)](https://arxiv.org/abs/2410.10813)
- [Mem0 (Chhikara et al., 2025)](https://arxiv.org/pdf/2504.19413)
- [Zep: A Temporal Knowledge Graph Architecture for Agent Memory](https://arxiv.org/html/2501.13956v1)
- [Contextual Retrieval — Zusammenfassung der Ergebnisse](https://gradientflow.com/contextual-retrieval-rag/)
- [Long-Context vs. RAG — Entscheidungsrahmen](https://tianpan.co/blog/2026-04-09-long-context-vs-rag-production-decision-framework)
- [Apple NLContextualEmbedding](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding.md) · [WWDC23: Multilingual Models](https://wwdcnotes.com/documentation/wwdc23-10042-explore-natural-language-multilingual-models/)
- [Atomic Notes](https://www.notelyn.com/blog/atomic-notes) · [Knowledge Funnel: Capture → Process](https://www.dsebastien.net/the-knowledge-ingestion-process/)
