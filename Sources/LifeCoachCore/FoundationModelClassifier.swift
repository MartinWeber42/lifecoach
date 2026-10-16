#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Target implementation: on-device, needs Apple Intelligence (iPhone 15 Pro+ or Apple-silicon Mac).
public struct FoundationModelClassifier: Classifier {
    public init() {}

    public static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { true } else { false }
    }

    /// Reason when unavailable, e.g. appleIntelligenceNotEnabled or modelNotReady.
    public static var availability: String {
        String(describing: SystemLanguageModel.default.availability)
    }

    public func classify(_ input: String, now: Date, timeZone: TimeZone) async throws -> Classification {
        let session = LanguageModelSession(instructions: ClassificationPrompt.instructions(now: now, timeZone: timeZone))
        let result = try await session.respond(to: input, generating: Generated.self).content
        let kind: Kind = switch result.kind {
        case .note: .note
        case .reminder: .reminder
        case .question: .question
        }
        return Classification(kind: kind, text: result.text, due: DueDate.parse(result.due, timeZone: timeZone))
    }

    @Generable
    struct Generated {
        let kind: GeneratedKind
        @Guide(description: "Kernaussage, knapp")
        let text: String
        @Guide(description: "ISO-8601-Zeitpunkt mit Offset, nur bei reminder")
        let due: String?
    }

    @Generable
    enum GeneratedKind { case note, reminder, question }
}
#endif
