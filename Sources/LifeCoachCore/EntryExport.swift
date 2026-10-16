import Foundation

/// JSON-Export (CONCEPT Datenschutz: „Handy weg = Gehirn weg" — manueller Export über das Share-Sheet).
public enum EntryExport {
    public struct DTO: Codable, Equatable {
        public let rawText: String
        public let text: String
        public let kind: Kind
        public let dueAt: Date?
        public let createdAt: Date
        public let doneAt: Date?
        public let isPrivate: Bool

        public init(rawText: String, text: String, kind: Kind, dueAt: Date?, createdAt: Date, doneAt: Date?, isPrivate: Bool) {
            self.rawText = rawText
            self.text = text
            self.kind = kind
            self.dueAt = dueAt
            self.createdAt = createdAt
            self.doneAt = doneAt
            self.isPrivate = isPrivate
        }
    }

    public static func jsonData(_ entries: [Entry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries.map(dto))
    }

    public static func decode(_ data: Data) throws -> [DTO] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([DTO].self, from: data)
    }

    private static func dto(_ entry: Entry) -> DTO {
        DTO(rawText: entry.rawText, text: entry.text, kind: entry.kind, dueAt: entry.dueAt,
            createdAt: entry.createdAt, doneAt: entry.doneAt, isPrivate: entry.isPrivate)
    }
}
