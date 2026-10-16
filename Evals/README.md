# Evals

Messdaten für M0 — gegen das echte Modell, nicht Teil der normalen Test-Suite.

Beide Dateien haben einen festen Stichtag `now` (Fr 16.10.2026 14:30, Europe/Berlin). Der Runner gibt dem Modell dieses Datum statt der echten Uhrzeit. Fälligkeiten nach dem 25.10. stehen in `+01:00` (Zeitumstellung).

## classification.json

`cases[]`: `input` → erwartetes `kind` und `due` (ISO mit Offset oder `null`).

- `kind` korrekt: exakter Vergleich.
- `due` korrekt: gleicher Zeitpunkt auf die Minute. Ohne Uhrzeit in der Eingabe gilt 09:00.
- `text` wird nicht bewertet.

## answering.json

`entries[]` ist das Gedächtnis, `cases[]` die Fragen.

- `expected: [..]` → korrekt, wenn die Antwort einen der Begriffe enthält (Groß/Klein egal).
- `expected: null` → korrekt nur, wenn die App „nichts gespeichert" meldet. Jede andere Antwort zählt als Halluzination.

## aliases (beide Dateien)

`aliases[]`: bestätigte Alias-Zuordnungen (wie nach der Alias-Bestätigung im Banner). Der Runner gibt sie dem Modell als bekannte Personen mit. `null`/fehlend = keine.

## extraction.json

`cases[]`: `input` → erwartete Extraktion (MEMORY.md: eigenes Schema, getrennt von der Klassifizierung).

- `people` korrekt: Vereinigung der Personen über alle Fakten, als Menge (Groß/Klein egal).
- `eventDate` korrekt: gleicher Tag. `null` = die Eingabe nennt keinen Zeitpunkt.
- `aliasSuggestions` korrekt: Menge aus alias→person. `null`/fehlend = keine erwartet.
- `replaces` korrekt: der String ist Teil des Statements des Fakts, das ersetzt werden muss (`supersedes` enthält dessen ID). `null`/fehlend = nichts ersetzen.
- Der **Text** der Fakten wird nicht exakt verglichen.

Schwellen: siehe `MEMORY.md` (Alias- und Update-Fälle ≥ 90 %).

## Ausführen (auf dem Mac)

## Ausführen (auf dem Mac)

```sh
swift test                                                   # Unit-Tests, ohne Modell
LIFECOACH_EVAL=haiku ANTHROPIC_API_KEY=… swift test --filter ClassificationEval
LIFECOACH_EVAL=apple swift test --filter ClassificationEval  # Apple Intelligence muss an sein
LIFECOACH_EVAL=haiku ANTHROPIC_API_KEY=… swift test --filter ExtractionEval
```

Ausgabe: jede falsche Klassifizierung als Zeile (`KIND`, `DUE`, `FEHLER`), am Ende Quoten und Median-Latenz. Kosten Haiku-Lauf: Bruchteil eines Cents. Den API-Key nie committen.
