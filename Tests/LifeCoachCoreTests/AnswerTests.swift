import Foundation
import Testing
@testable import LifeCoachCore

@MainActor
struct HaikuAnswererTests {
    static let berlin = TimeZone(identifier: "Europe/Berlin")!
    var now: Date { DueDate.parse("2026-10-16T14:30:00+02:00", timeZone: Self.berlin)! }

    @Test func requestAsksHaikuForAnswerSchema() throws {
        let request = try HaikuAnswerer(apiKey: "test-key").request(
            for: "was wünscht sich meine freundin",
            candidates: [],
            now: now, timeZone: Self.berlin)

        let httpBody = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        let format = (body["output_config"] as? [String: Any])?["format"] as? [String: Any]
        #expect(body["model"] as? String == "claude-haiku-5-5")
        #expect(format?["type"] as? String == "json_schema")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
    }

    @Test func answerIsParsed() throws {
        let response = #"""
        {"content":[{"type":"text","text":"{\"answer\":\"Eine Keramikvase.\",\"sources\":[\"7C4A8DFF-2A5F-4B6C-9E1D-3F2A5B6C7D8E\"]}"}],"stop_reason":"end_turn"}
        """#

        let result = try HaikuAnswerer.parse(Data(response.utf8))

        #expect(result.text == "Eine Keramikvase.")
        #expect(result.sourceIDs == [UUID(uuidString: "7C4A8DFF-2A5F-4B6C-9E1D-3F2A5B6C7D8E")])
    }

    /// Ohne Treffer antwortet das Modell mit der Enthaltung — keine Halluzination (MEMORY.md: Schwellen 0).
    @Test func nothingStoredIsParsed() throws {
        let response = #"""
        {"content":[{"type":"text","text":"{\"answer\":\"Dazu habe ich nichts gespeichert.\",\"sources\":[]}"}],"stop_reason":"end_turn"}
        """#

        let result = try HaikuAnswerer.parse(Data(response.utf8))

        #expect(result.text == "Dazu habe ich nichts gespeichert.")
        #expect(result.sourceIDs.isEmpty)
    }

    @Test func refusalIsReported() {
        let response = #"{"content":[],"stop_reason":"refusal"}"#
        #expect(throws: ClassifierError.refusal) { try HaikuAnswerer.parse(Data(response.utf8)) }
    }
}
