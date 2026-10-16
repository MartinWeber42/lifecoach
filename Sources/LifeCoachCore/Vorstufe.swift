import Foundation

/// Shared tokenizer: lowercase word/number tokens (MEMORY.md, Vorstufe — deterministisch, ohne KI).
func tokenize(_ text: String) -> [String] {
    text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
}

/// Geheimnis-Filter (MEMORY.md, Vorstufe 1): Inputs mit diesen Wörtern gehen **nie** an ein Modell.
/// Gilt ab M1 — schon die Klassifizierung schickt Text an Haiku. Fehlalarme kosten nur die Sortierung.
public enum SecretFilter {
    public static let keywords: Set<String> = [
        "passwort", "kennwort", "pw", "pin", "puk", "tan", "code",
        "geheimzahl", "zugangsdaten", "login", "iban", "geheim",
    ]

    /// True when the text contains a keyword as a whole word ("pin 1234" ja, "pinnwand" nein).
    public static func isSecret(_ text: String) -> Bool {
        !Set(tokenize(text)).isDisjoint(with: keywords)
    }
}

/// Keyword lookup over rawText (MEMORY.md: private Treffer per Stichwort, ohne Modell).
/// M2b ersetzt das durch den vollständigen Retriever (Ranking, Personen, Zeitraum).
public enum KeywordSearch {
    /// True when every query token appears in the text ("wlan pw?" → rawText-Overlap).
    public static func matches(_ text: String, query: String) -> Bool {
        let needles = Set(tokenize(query))
        guard !needles.isEmpty else { return false }
        return needles.isSubset(of: Set(tokenize(text)))
    }
}

/// Personen-Vorerkennung (MEMORY.md, Vorstufe 2): bekannte Namen + bestätigte Aliase im Text finden.
/// Ein Stück Code, zwei Einsätze: Extraktions-Kontext und Frage-Kandidaten (Abfragen, Schritt 1).
public enum PersonDetection {
    /// Persons whose name or confirmed alias appears in the text (word-exact, case-insensitive).
    public static func detect(_ text: String, in people: [Person]) -> [Person] {
        let tokens = tokenize(text)
        return people.filter { person in
            ([person.name] + person.aliases).contains { identifier in
                containsPhrase(tokens, phrase: tokenize(identifier))
            }
        }
    }

    /// Consecutive token-subsequence match ("meine freundin" ⊂ [meine, freundin, mag, rosen]).
    private static func containsPhrase(_ tokens: [String], phrase: [String]) -> Bool {
        guard !phrase.isEmpty, tokens.count >= phrase.count else { return false }
        return (0 ... tokens.count - phrase.count).contains { start in
            Array(tokens[start ..< start + phrase.count]) == phrase
        }
    }
}
