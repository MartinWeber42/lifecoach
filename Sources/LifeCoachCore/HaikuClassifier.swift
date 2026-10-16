import Foundation

public enum ClassifierError: Error, Equatable {
    case http(status: Int, body: String)
    case refusal
    case noText
}

/// Bridge until an Apple-Intelligence device is available (AGENTS.md, rule 3).
public struct HaikuClassifier: Classifier {
    static let model = "claude-haiku-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    let apiKey: String
    let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func classify(_ input: String, now: Date, timeZone: TimeZone) async throws -> Classification {
        let (data, response) = try await session.data(for: request(for: input, now: now, timeZone: timeZone))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw ClassifierError.http(status: status, body: String(decoding: data, as: UTF8.self))
        }
        return try Self.parse(data, timeZone: timeZone)
    }

    func request(for input: String, now: Date, timeZone: TimeZone) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 512,
            "thinking": ["type": "disabled"],
            "system": ClassificationPrompt.instructions(now: now, timeZone: timeZone),
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
            "kind": ["type": "string", "enum": Kind.allCases.map(\.rawValue)],
            "text": ["type": "string"],
            "due": ["anyOf": [["type": "string"], ["type": "null"]]],
        ],
        "required": ["kind", "text", "due"],
        "additionalProperties": false,
    ] }

    static func parse(_ data: Data, timeZone: TimeZone) throws -> Classification {
        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
            let stop_reason: String?
        }
        struct Raw: Decodable { let kind: Kind; let text: String; let due: String? }

        let response = try JSONDecoder().decode(Response.self, from: data)
        if response.stop_reason == "refusal" { throw ClassifierError.refusal }
        guard let text = response.content.first(where: { $0.type == "text" })?.text else { throw ClassifierError.noText }
        let raw = try JSONDecoder().decode(Raw.self, from: Data(text.utf8))
        return Classification(kind: raw.kind, text: raw.text, due: DueDate.parse(raw.due, timeZone: timeZone))
    }
}
