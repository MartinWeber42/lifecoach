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

Schwellen: siehe `ROADMAP.md`, M0.

## Ausführen (auf dem Mac)

```sh
swift test                                                   # Unit-Tests, ohne Modell
LIFECOACH_EVAL=haiku ANTHROPIC_API_KEY=… swift test --filter ClassificationEval
LIFECOACH_EVAL=apple swift test --filter ClassificationEval  # Apple Intelligence muss an sein
```

Ausgabe: jede falsche Klassifizierung als Zeile (`KIND`, `DUE`, `FEHLER`), am Ende Quoten und Median-Latenz. Kosten Haiku-Lauf: Bruchteil eines Cents. Den API-Key nie committen.
