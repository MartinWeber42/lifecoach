import Foundation
import Testing
@testable import LifeCoachCore

private final class CallCounter: @unchecked Sendable {
    var count = 0
}

private struct CountingClassifier: Classifier {
    let result: Result<Classification, Error>
    let counter: CallCounter

    init(_ result: Result<Classification, Error>, _ counter: CallCounter) {
        self.result = result
        self.counter = counter
    }

    func classify(_ input: String, now: Date, timeZone: TimeZone) async throws -> Classification {
        counter.count += 1
        switch result {
        case .success(let c): return c
        case .failure(let e): throw e
        }
    }
}

@MainActor
struct SecretFilterTests {
    /// Secret inputs never reach a model: saved as private note, classifier untouched
    /// (MEMORY.md, Vorstufe 1: entryWithPasswordStaysOnDevice).
    @Test func entryWithPasswordStaysOnDevice() async {
        let counter = CallCounter()
        let service = CaptureService(classifier: CountingClassifier(
            .success(Classification(kind: .reminder, text: "sonnenblume42", due: nil)), counter))

        let entry = await service.classify("wlan pw bei den eltern ist sonnenblume42")

        #expect(entry.isPrivate)
        #expect(entry.kind == .note)
        #expect(counter.count == 0)
    }

    /// Keyword matching respects word boundaries: "pinnwand" is not secret, "pin 1234" is
    /// (MEMORY.md: secretKeywordMatchesWholeWordOnly).
    @Test func secretKeywordMatchesWholeWordOnly() {
        #expect(!SecretFilter.isSecret("pinnwand aufräumen"))
        #expect(SecretFilter.isSecret("pin 1234"))
        #expect(SecretFilter.isSecret("WLAN-PW bei den eltern"))
        #expect(SecretFilter.isSecret("meine iban steht im brief"))
    }

    /// "geheim" marks the entry private, no classification call
    /// (MEMORY.md: entryMarkedSecretStaysOnDevice).
    @Test func entryMarkedSecretStaysOnDevice() async {
        let counter = CallCounter()
        let service = CaptureService(classifier: CountingClassifier(
            .success(Classification(kind: .note, text: "schwanger", due: nil)), counter))

        let entry = await service.classify("anna ist schwanger, noch geheim!")

        #expect(entry.isPrivate)
        #expect(counter.count == 0)
    }

    /// Private entries are findable by keyword over rawText, without any model
    /// (MEMORY.md: privateEntryIsFoundByKeyword).
    @Test func privateEntryIsFoundByKeyword() {
        let entry = Entry(rawText: "wlan pw bei den eltern ist sonnenblume42", isPrivate: true)

        #expect(KeywordSearch.matches(entry.rawText, query: "wlan pw?"))
        #expect(!KeywordSearch.matches(entry.rawText, query: "keramikvase"))
    }
}
