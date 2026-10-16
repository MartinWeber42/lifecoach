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
