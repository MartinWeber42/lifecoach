import Foundation
import Testing
@testable import LifeCoachCore

@MainActor
struct HaikuExtractorTests {
    static let berlin = TimeZone(identifier: "Europe/Berlin")!
    var now: Date { DueDate.parse("2026-10-16T14:30:00+02:00", timeZone: Self.berlin)! }

    @Test func requestAsksHaikuForExtractionSchema() throws {
        let request = try HaikuExtractor(apiKey: "test-key").request(
            for: "lisa will doch lieber ein buch",
            facts: [],
            people: [Person(name: "Lisa", aliases: ["meine Freundin"])],
            now: now, timeZone: Self.berlin)

        let httpBody = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        let format = (body["output_config"] as? [String: Any])?["format"] as? [String: Any]
        #expect(body["model"] as? String == "claude-haiku-5-5")
        #expect(format?["type"] as? String == "json_schema")
        #expect((body["max_tokens"] as? Int ?? 0) >= 512)
        // Bekannte Personen mit bestätigten Aliasen als Kontext (MEMORY.md, Vorstufe 2)
        let system = body["system"] as? String ?? ""
        #expect(system.contains("Lisa (= meine Freundin)"))
    }

    @Test func extractionIsParsed() throws {
        let response = #"""
        {"content":[{"type":"text","text":"{\"facts\":[{\"statement\":\"Lisa wünscht sich ein Buch.\",\"people\":[\"Lisa\"],\"eventDate\":\"2026-10-16\"}],\"aliasSuggestions\":[{\"alias\":\"meine Freundin\",\"person\":\"Lisa\"}],\"supersedes\":[\"7C4A8DFF-2A5F-4B6C-9E1D-3F2A5B6C7D8E\"]}"}],"stop_reason":"end_turn"}
        """#

        let result = try HaikuExtractor.parse(Data(response.utf8), timeZone: Self.berlin)

        #expect(result.facts.count == 1)
        #expect(result.facts.first?.statement == "Lisa wünscht sich ein Buch.")
        #expect(result.facts.first?.people == ["Lisa"])
        #expect(result.facts.first?.eventDate == DueDate.parse("2026-10-16T00:00:00+02:00", timeZone: Self.berlin))
        #expect(result.aliasSuggestions == [.init(alias: "meine Freundin", person: "Lisa")])
        #expect(result.supersedes == [UUID(uuidString: "7C4A8DFF-2A5F-4B6C-9E1D-3F2A5B6C7D8E")])
    }

    @Test func missingKeysYieldEmpty() throws {
        let response = #"""
        {"content":[{"type":"text","text":"{}"}],"stop_reason":"end_turn"}
        """#

        let result = try HaikuExtractor.parse(Data(response.utf8), timeZone: Self.berlin)

        #expect(result.facts.isEmpty)
        #expect(result.aliasSuggestions.isEmpty)
        #expect(result.supersedes.isEmpty)
    }

    @Test func refusalIsReported() {
        let response = #"{"content":[],"stop_reason":"refusal"}"#
        #expect(throws: ClassifierError.refusal) { try HaikuExtractor.parse(Data(response.utf8), timeZone: Self.berlin) }
    }
}
