import Foundation
import Testing
@testable import LifeCoachCore

let berlin = TimeZone(identifier: "Europe/Berlin")!
let fridayAfternoon = DueDate.parse("2026-10-16T14:30:00+02:00", timeZone: berlin)!

struct ClassificationPromptTests {
    @Test func promptStatesWeekdayAndCurrentTime() {
        let prompt = ClassificationPrompt.instructions(now: fridayAfternoon, timeZone: berlin)
        #expect(prompt.contains("Freitag"))
        #expect(prompt.contains("2026-10-16T14:30:00+02:00"))
    }
}

struct DueDateTests {
    @Test func dueWithOffsetIsParsed() {
        #expect(DueDate.parse("2026-10-20T15:00:00+02:00", timeZone: berlin) == DueDate.parse("2026-10-20T13:00:00Z", timeZone: berlin))
    }

    @Test func dueWithoutOffsetUsesDeviceTimeZone() {
        #expect(DueDate.parse("2026-10-20T15:00:00", timeZone: berlin) == DueDate.parse("2026-10-20T15:00:00+02:00", timeZone: berlin))
        #expect(DueDate.parse("2026-10-30T09:00:00", timeZone: berlin) == DueDate.parse("2026-10-30T09:00:00+01:00", timeZone: berlin))
    }

    @Test func missingDueIsNil() {
        #expect(DueDate.parse(nil, timeZone: berlin) == nil)
        #expect(DueDate.parse("", timeZone: berlin) == nil)
    }
}

struct HaikuClassifierTests {
    @Test func requestAsksHaikuForSchemaOutput() throws {
        let request = try HaikuClassifier(apiKey: "test-key").request(for: "morgen 10 uhr mama anrufen", now: fridayAfternoon, timeZone: berlin)
        let httpBody = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: httpBody) as? [String: Any])
        let format = (body["output_config"] as? [String: Any])?["format"] as? [String: Any]
        #expect(body["model"] as? String == "claude-haiku-5-5")
        #expect(format?["type"] as? String == "json_schema")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
    }

    @Test func reminderIsParsedPastThinkingBlock() throws {
        let response = #"""
        {"content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\"kind\":\"reminder\",\"text\":\"Mama anrufen\",\"due\":\"2026-10-17T10:00:00+02:00\"}"}],"stop_reason":"end_turn"}
        """#
        let result = try HaikuClassifier.parse(Data(response.utf8), timeZone: berlin)
        #expect(result == Classification(kind: .reminder, text: "Mama anrufen", due: DueDate.parse("2026-10-17T10:00:00+02:00", timeZone: berlin)))
    }

    @Test func noteHasNoDue() throws {
        let response = #"""
        {"content":[{"type":"text","text":"{\"kind\":\"note\",\"text\":\"Lisa wünscht sich eine Keramikvase\",\"due\":null}"}],"stop_reason":"end_turn"}
        """#
        #expect(try HaikuClassifier.parse(Data(response.utf8), timeZone: berlin).due == nil)
    }

    @Test func refusalIsReported() {
        let response = #"{"content":[],"stop_reason":"refusal"}"#
        #expect(throws: ClassifierError.refusal) { try HaikuClassifier.parse(Data(response.utf8), timeZone: berlin) }
    }
}
