import Foundation

/// Classifies raw text and creates a new (not yet persisted) Entry.
/// Falls back to `.note` on classifier error or timeout (CONCEPT: Flow A, Fallback).
public struct CaptureService: Sendable {
    public let classifier: (any Classifier)?
    let timeoutSeconds: Double

    public init(classifier: (any Classifier)?, timeoutSeconds: Double = 3.0) {
        self.classifier = classifier
        self.timeoutSeconds = timeoutSeconds
    }

    /// True when no classifier is configured — user sets kind manually (CONCEPT: manueller Modus).
    public var isManualMode: Bool { classifier == nil }

    @MainActor
    public func classify(_ rawText: String, now: Date = .now, timeZone: TimeZone = .current) async -> Entry {
        guard let classifier else {
            return Entry(rawText: rawText, kind: .note, createdAt: now)
        }
        do {
            let c: Classification = try await withTimeout(seconds: timeoutSeconds) {
                try await classifier.classify(rawText, now: now, timeZone: timeZone)
            }
            let kind: Kind = c.kind == .question ? .note : c.kind
            return Entry(rawText: rawText, text: c.text, kind: kind, dueAt: c.due, createdAt: now)
        } catch {
            return Entry(rawText: rawText, kind: .note, createdAt: now)
        }
    }
}

private struct TimeoutError: Error {}

private func withTimeout<T: Sendable>(
    seconds: Double,
    work: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else { throw TimeoutError() }
        return result
    }
}
