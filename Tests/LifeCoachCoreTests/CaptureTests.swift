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

        guard case .entry(let entry) = await service.capture("zu langsam") else {
            Issue.record("expected entry"); return
        }

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

        guard case .entry(let entry) = await service.capture("Lisa wünscht sich eine Keramikvase") else {
            Issue.record("expected entry"); return
        }
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

        guard case .entry(let entry) = await service.capture("Milch kaufen") else {
            Issue.record("expected entry"); return
        }
        #expect(entry.kind == .note)
    }

    /// question is answered, never persisted (ROADMAP M2: questionIsNotPersisted).
    @Test func questionIsNotPersisted() async {
        let service = CaptureService(classifier: FakeClassifier(
            .success(Classification(kind: .question, text: "was mag lisa", due: nil))))

        guard case .question(let q) = await service.capture("was mag lisa für blumen") else {
            Issue.record("expected question"); return
        }
        #expect(q == "was mag lisa")
    }
}
