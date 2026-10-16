import Foundation

/// Antwort-Brücke (CONCEPT Flow C). Dasselbe Muster wie HaikuClassifier/HaikuExtractor —
/// beim Wechsel auf on-device nur der Transport.
public struct HaikuAnswerer: Answerer {
    static let model = "claude-haiku-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    let apiKey: String
    let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func answer(_ question: String, candidates: [Fact], now: Date, timeZone: TimeZone) async throws -> Answer {
        let (data, response) = try await session.data(for: request(for: question, candidates: candidates, now: now, timeZone: timeZone))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw ClassifierError.http(status: status, body: String(decoding: data, as: UTF8.self))
        }
        return try Self.parse(data)
    }

    func request(for question: String, candidates: [Fact], now: Date, timeZone: TimeZone) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 1024,
            "thinking": ["type": "disabled"],
            "system": AnswerPrompt.instructions(candidates: candidates, now: now, timeZone: timeZone),
            "messages": [["role": "user", "content": question]],
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
            "answer": ["type": "string"],
            "sources": ["type": "array", "items": ["type": "string"]],
        ],
        "required": ["answer", "sources"],
        "additionalProperties": false,
    ] }

    static func parse(_ data: Data) throws -> Answer {
        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
            let stop_reason: String?
        }
        struct Raw: Decodable { let answer: String; let sources: [String]! }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.stop_reason != "refusal" else { throw ClassifierError.refusal }
        guard let text = response.content.first(where: { $0.type == "text" })?.text else { throw ClassifierError.noText }
        let raw = try JSONDecoder().decode(Raw.self, from: Data(text.utf8))
        return Answer(
            text: raw.answer,
            sourceIDs: (raw.sources ?? []).compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespaces)) })
    }
}
