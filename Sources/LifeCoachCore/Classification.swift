import Foundation

public enum Kind: String, Codable, Sendable, CaseIterable {
    case note, reminder, question
}

public struct Classification: Equatable, Sendable {
    public let kind: Kind
    public let text: String
    public let due: Date?

    public init(kind: Kind, text: String, due: Date?) {
        self.kind = kind
        self.text = text
        self.due = due
    }
}

public protocol Classifier: Sendable {
    func classify(_ input: String, now: Date, timeZone: TimeZone) async throws -> Classification
}

/// ISO-8601 parsing for `due`. Accepts a missing offset (small models drop it) by assuming the device time zone.
public enum DueDate {
    public static func parse(_ string: String?, timeZone: TimeZone) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let withOffset = ISO8601DateFormatter()
        if let date = withOffset.date(from: string) { return date }
        let local = ISO8601DateFormatter()
        local.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        local.timeZone = timeZone
        return local.date(from: string)
    }

    public static func format(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
