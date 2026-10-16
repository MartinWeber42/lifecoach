import Foundation

/// Extraction-Brücke (zweiter Aufruf neben der Klassifizierung, MEMORY.md Verarbeitung).
/// Dasselbe Muster wie HaikuClassifier — beim Wechsel auf on-device nur der Transport.
public struct HaikuExtractor: Extractor {
    static let model = "claude-haiku-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    let apiKey: String
    let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func extract(_ input: String, facts: [Fact], people: [Person], now: Date, timeZone: TimeZone) async throws -> Extraction {
        let (data, response) = try await session.data(for: request(for: input, facts: facts, people: people, now: now, timeZone: timeZone))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw ClassifierError.http(status: status, body: String(decoding: data, as: UTF8.self))
        }
        return try Self.parse(data, timeZone: timeZone)
    }

    func request(for input: String, facts: [Fact], people: [Person], now: Date, timeZone: TimeZone) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 1024,
            "thinking": ["type": "disabled"],
            "system": ExtractionPrompt.instructions(facts: facts, people: people, now: now, timeZone: timeZone),
            "messages": [["role": "user", "content": input]],
            "output_config": [
                "effort": "low",
                "format": ["type": "json_schema", "schema": Self.schema],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static var schema: [String: Any] { [
        "type": "object",
        "properties": [
            "facts": ["type": "array", "items": [
                "type": "object",
                "properties": [
                    "statement": ["type": "string"],
                    "people": ["type": "array", "items": ["type": "string"]],
                    "eventDate": ["anyOf": [["type": "string"], ["type": "null"]]],
                ],
                "required": ["statement", "people", "eventDate"],
                "additionalProperties": false,
            ]],
            "aliasSuggestions": ["type": "array", "items": [
                "type": "object",
                "properties": [
                    "alias": ["type": "string"],
                    "person": ["type": "string"],
                ],
                "required": ["alias", "person"],
                "additionalProperties": false,
            ]],
            "supersedes": ["type": "array", "items": ["type": "string"]],
        ],
        "required": ["facts", "aliasSuggestions", "supersedes"],
        "additionalProperties": false,
    ] }

    static func parse(_ data: Data, timeZone: TimeZone) throws -> Extraction {
        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
            let stop_reason: String?
        }
        struct Raw: Decodable {
            struct RawFact: Decodable { let statement: String; let people: [String]!; let eventDate: String? }
            struct RawAlias: Decodable { let alias: String; let person: String }
            let facts: [RawFact]!
            let aliasSuggestions: [RawAlias]!
            let supersedes: [String]!
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.stop_reason != "refusal" else { throw ClassifierError.refusal }
        guard let text = response.content.first(where: { $0.type == "text" })?.text else { throw ClassifierError.noText }
        let raw = try JSONDecoder().decode(Raw.self, from: Data(text.utf8))
        return Extraction(
            facts: (raw.facts ?? []).map {
                .init(statement: $0.statement, people: $0.people ?? [], eventDate: parseDate($0.eventDate, timeZone: timeZone))
            },
            aliasSuggestions: (raw.aliasSuggestions ?? []).map { .init(alias: $0.alias, person: $0.person) },
            supersedes: (raw.supersedes ?? []).compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespaces)) })
    }

    /// eventDate: JJJJ-MM-TT (oder voller Zeitpunkt) in der Gerätezeitzone.
    private static func parseDate(_ string: String?, timeZone: TimeZone) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let date = DueDate.parse(string, timeZone: timeZone) { return date }
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate]
        dateOnly.timeZone = timeZone
        return dateOnly.date(from: string)
    }
}
