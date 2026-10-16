import Foundation
import Testing
@testable import LifeCoachCore

/// Runs Evals/extraction.json against the real model. Off unless LIFECOACH_EVAL=haiku.
/// Prüft Personen, eventDate, Alias-Vorschläge und Abgleich — der Fakten-Text wird nicht exakt verglichen.
struct ExtractionEval {
    struct File: Decodable {
        struct Alias: Decodable { let alias: String; let person: String }
        struct Case: Decodable {
            let input: String
            let people: [String]
            let eventDate: String?
            let aliasSuggestions: [Alias]?
            let replaces: String?
        }
        let now: String
        let timeZone: String
        let aliases: [Alias]?
        let cases: [Case]
    }
    struct UnknownMode: Error {}

    static let mode = ProcessInfo.processInfo.environment["LIFECOACH_EVAL"]

    @Test(.enabled(if: mode != nil))
    @MainActor
    func extractionMeetsThresholds() async throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Evals/extraction.json")
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        let timeZone = try #require(TimeZone(identifier: file.timeZone))
        let now = try #require(DueDate.parse(file.now, timeZone: timeZone))
        let extractor = try await Self.extractor()

        var facts: [Fact] = [] // läuft mit, damit Abgleich-Fälle Kontext haben
        var peopleHits = 0
        var dateHits = 0
        var aliasHits = 0
        var updateHits = 0
        var dateCases = 0
        var aliasCases = 0
        var updateCases = 0
        var durations: [Duration] = []

        for testCase in file.cases {
            let start = ContinuousClock.now
            let knownPeople = (file.aliases ?? []).map { alias in
                Person(name: alias.person, aliases: [alias.alias])
            }
            let result: Extraction
            do {
                result = try await extractor.extract(testCase.input, facts: facts, people: knownPeople, now: now, timeZone: timeZone)
            } catch {
                print("FEHLER \(testCase.input): \(error)")
                continue
            }
            durations.append(ContinuousClock.now - start)

            let extractedPeople = Set(result.facts.flatMap(\.people).map { $0.lowercased() })
            if extractedPeople == Set(testCase.people.map { $0.lowercased() }) {
                peopleHits += 1
            } else {
                print("PEOPLE \(testCase.input): \(extractedPeople.sorted()) ≠ \(testCase.people)")
            }

            if let expected = testCase.eventDate {
                dateCases += 1
                let expectedDate = DueDate.parse(expected, timeZone: timeZone).map { Calendar.current.startOfDay(for: $0) }
                if result.facts.contains(where: { $0.eventDate.map({ Calendar.current.startOfDay(for: $0) }) == expectedDate }) {
                    dateHits += 1
                } else {
                    print("DATE \(testCase.input): \(result.facts.compactMap(\.eventDate)) ≠ \(expected)")
                }
            }

            if let expected = testCase.aliasSuggestions {
                aliasCases += 1
                let got = Set(result.aliasSuggestions.map { "\($0.alias.lowercased())→\($0.person.lowercased())" })
                let want = Set(expected.map { "\($0.alias.lowercased())→\($0.person.lowercased())" })
                if got == want {
                    aliasHits += 1
                } else {
                    print("ALIAS \(testCase.input): \(got.sorted()) ≠ \(want.sorted())")
                }
            }

            if let replaces = testCase.replaces {
                updateCases += 1
                if let old = facts.first(where: { $0.statement.contains(replaces) }), result.supersedes.contains(old.id) {
                    updateHits += 1
                } else {
                    print("UPDATE \(testCase.input): supersedes \(result.supersedes) enthält nicht „\(replaces)“")
                }
            }

            for fact in result.facts {
                let model = Fact(statement: fact.statement, eventDate: fact.eventDate)
                facts.append(model)
            }
        }

        let total = Double(file.cases.count)
        try #require(!durations.isEmpty, "alle Fälle fehlgeschlagen")
        let median = durations.sorted()[durations.count / 2]
        print("[haiku] people \(peopleHits)/\(file.cases.count) · date \(dateHits)/\(dateCases) · alias \(aliasHits)/\(aliasCases) · update \(updateHits)/\(updateCases) · Median \(median)")
        #expect(Double(peopleHits) / total >= 0.90)
        if dateCases > 0 { #expect(Double(dateHits) / Double(dateCases) >= 0.80) }
        if aliasCases > 0 { #expect(Double(aliasHits) / Double(aliasCases) >= 0.90) }
        if updateCases > 0 { #expect(Double(updateHits) / Double(updateCases) >= 0.90) }
    }

    @MainActor static func extractor() throws -> any Extractor {
        switch mode {
        case "haiku":
            return HaikuExtractor(apiKey: try #require(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], "ANTHROPIC_API_KEY fehlt"))
        default:
            throw UnknownMode()
        }
    }
}
