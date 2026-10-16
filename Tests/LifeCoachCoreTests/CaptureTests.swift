import Foundation
import SwiftData
import Testing
@testable import LifeCoachCore

private struct FakeClassifier: Classifier {
    let result: Result<Classification, Error>
    let delay: TimeInterval

    init(_ result: Result<Classification, Error>, delay: TimeInterval = 0) {
        self.result = result
        self.delay = delay
    }

    func classify(_ input: String, now: Date, timeZone: TimeZone) async throws -> Classification {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        switch result {
        case .success(let c): return c
        case .failure(let e): throw e
        }
    }
}

@MainActor
struct CaptureTests {
    /// Classifier that takes longer than the timeout → entry saved as .note (ROADMAP: classifierTimeoutSavesAsNote).
    @Test func classifierTimeoutSavesAsNote() async {
        let slow = FakeClassifier(.success(Classification(kind: .reminder, text: "test", due: nil)), delay: 10)
        let service = CaptureService(classifier: slow, timeoutSeconds: 0.05)

        let entry = await service.classify("zu langsam")

        #expect(entry.kind == .note)
    }

    /// Kind can be changed on a persisted Entry after classification (ROADMAP: userCanChangeKindAfterClassification).
    @Test func userCanChangeKindAfterClassification() async throws {
        let container = try ModelContainer(
            for: Entry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let classifier = FakeClassifier(.success(Classification(kind: .note, text: "Keramikvase", due: nil)))
        let service = CaptureService(classifier: classifier)

        let entry = await service.classify("Lisa wünscht sich eine Keramikvase")
        context.insert(entry)
        try context.save()

        entry.kind = .reminder
        try context.save()

        let saved = try context.fetch(FetchDescriptor<Entry>())
        #expect(saved.first?.kind == .reminder)
    }

    /// No classifier → isManualMode true, entry saved as .note (ROADMAP: unavailableModelEntersManualMode).
    @Test func unavailableModelEntersManualMode() async {
        let service = CaptureService(classifier: nil)
        #expect(service.isManualMode)

        let entry = await service.classify("Milch kaufen")
        #expect(entry.kind == .note)
    }
}
