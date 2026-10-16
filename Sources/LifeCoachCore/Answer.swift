import Foundation

/// Antwort + Liste der Quell-Fakten (CONCEPT: Antwort / Answer).
public struct Answer: Equatable, Sendable {
    public let text: String
    public let sourceIDs: [UUID]

    public init(text: String, sourceIDs: [UUID]) {
        self.text = text
        self.sourceIDs = sourceIDs
    }
}

/// Antwort nur aus Kandidaten (CONCEPT: Findet die App nichts, sagt sie das — sie erfindet nichts).
@MainActor
public protocol Answerer: Sendable {
    func answer(_ question: String, candidates: [Fact], now: Date, timeZone: TimeZone) async throws -> Answer
}
