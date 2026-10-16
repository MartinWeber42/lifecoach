<!-- harness:apis -->
## Saved APIs

The user can save API connections in Harness → Models → APIs on this computer.
Run `harness api list --json` to discover the current connections; the list contains no keys.
Use `harness api request <id> <path> --method POST --data @request.json` for JSON APIs,
or `harness api run <id> -- <command> [args]` for a provider SDK/tool. The latter supplies
the connection's documented key variable and HARNESS_API_BASE_URL to that tool only.
Use these APIs when needed for the user's task. Never print, paste, or save API keys in a project.
Adding an API does not change this harness's model or subscription.

<!-- harness:project -->
## Project: LifeCoach

**Vision:** Mobiles Gehirn als native iOS-App mit on-device LLM — Gedanken, Termine, Erinnerungen aufnehmen, lokal sortieren lassen, per Notification erinnert werden. Keine Cloud, kein Server, keine Daten verlassen das Handy.

**Entscheidung (bewusst):** Telegram-Bot wurde verworfen — Server-Abhängigkeit, Mac muss laufen, DSGVO-Argument greift nicht. Statt dessen native iOS-App; Apple Developer Account vorhanden, Deploy via TestFlight.

**Regeln für Agents:**
1. TDD: Test zuerst (Swift Testing), dann Code. Vertikale Slices, kein Horizontal-Slicing.
2. Ponytail-Prinzip: YAGNI, Stdlib vor Custom-Libraries, kürzest mögliche Lösung. Jede Zeile muss sein.
3. Ziel ist on-device-Inference (Apple Foundation Models). **Brücke (bewusst, befristet):** bis ein Apple-Intelligence-fähiges iPhone da ist, läuft das LLM über Claude Haiku (`claude-haiku-5-5`) per API — ausschließlich hinter den Protokollen `Classifier`/`Answerer`, damit der Wechsel auf on-device nur eine Implementierung tauscht. Kein anderer Cloud-Dienst, kein eigener Server. Wann die Brücke endet, entscheidet der Nutzer anhand der M0-Messwerte.
4. Konzept und Domänen-Sprache stehen in `CONCEPT.md`, die Gedächtnis-Architektur in `MEMORY.md` — vor jeder Aufgabe lesen, Testnamen an der Domäne orientieren.
5. Klassifizierungs-Schema (note/reminder/question) ist die bewiesene Kernlogik — nicht ohne Absprache ändern.
6. Deutsche UI-Sprache, Code und Identifier auf Englisch.

