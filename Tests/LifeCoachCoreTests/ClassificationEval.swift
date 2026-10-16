import Foundation
import Testing
@testable import LifeCoachCore

/// Runs Evals/classification.json against a real model. Off unless LIFECOACH_EVAL=haiku|apple.
struct ClassificationEval {
    struct File: Decodable { let now: String; let timeZone: String; let cases: [Case] }
    struct Case: Decodable { let input: String; let kind: Kind; let due: String? }
    struct UnknownMode: Error {}

    static let mode = ProcessInfo.processInfo.environment["LIFECOACH_EVAL"]

    @Test(.enabled(if: mode != nil))
    func classificationMeetsThresholds() async throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Evals/classification.json")
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        let timeZone = try #require(TimeZone(identifier: file.timeZone))
        let now = try #require(DueDate.parse(file.now, timeZone: timeZone))
        let classifier = try Self.classifier()
        let show = { (date: Date?) in date.map { DueDate.format($0, timeZone: timeZone) } ?? "null" }

        var kindHits = 0, dueHits = 0, durations: [Duration] = []
        let reminders = file.cases.filter { $0.kind == .reminder }.count
        for testCase in file.cases {
            let start = ContinuousClock.now
            guard let result = try? await classifier.classify(testCase.input, now: now, timeZone: timeZone) else {
                print("FEHLER \(testCase.input)")
                continue
            }
            durations.append(ContinuousClock.now - start)
            if result.kind == testCase.kind { kindHits += 1 } else { print("KIND   \(testCase.input): \(result.kind) statt \(testCase.kind)") }
            guard testCase.kind == .reminder else { continue }
            let expected = DueDate.parse(testCase.due, timeZone: timeZone)
            if result.due == expected { dueHits += 1 } else { print("DUE    \(testCase.input): \(show(result.due)) statt \(show(expected))") }
        }

        let kindRate = Double(kindHits) / Double(file.cases.count)
        let dueRate = Double(dueHits) / Double(reminders)
        try #require(!durations.isEmpty, "kein einziger Aufruf erfolgreich")
        let median = durations.sorted()[durations.count / 2]
        print("[\(Self.mode!)] kind \(kindHits)/\(file.cases.count) · due \(dueHits)/\(reminders) · Median \(median)")
        #expect(kindRate >= 0.90)
        #expect(dueRate >= 0.85)
    }

    static func classifier() throws -> any Classifier {
        switch mode {
        case "haiku":
            return HaikuClassifier(apiKey: try #require(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], "ANTHROPIC_API_KEY fehlt"))
        #if canImport(FoundationModels)
        case "apple":
            try #require(FoundationModelClassifier.isAvailable, "Apple Intelligence nicht verfügbar: \(FoundationModelClassifier.availability)")
            return FoundationModelClassifier()
        #endif
        default:
            throw UnknownMode()
        }
    }
}
