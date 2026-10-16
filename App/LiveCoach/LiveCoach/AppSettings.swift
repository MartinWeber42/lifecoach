import Foundation
import LifeCoachCore
import Observation

@Observable @MainActor
final class AppSettings {
    var apiKey: String {
        didSet { KeychainStore.save(apiKey, forKey: .haikuAPIKey) }
    }

    init() {
        // Dev convenience: ANTHROPIC_API_KEY env var overrides Keychain (set in Xcode scheme)
        apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
            ?? KeychainStore.load(forKey: .haikuAPIKey)
            ?? ""
    }

    var classifier: (any Classifier)? {
        apiKey.isEmpty ? nil : HaikuClassifier(apiKey: apiKey)
    }

    var extractor: (any Extractor)? {
        apiKey.isEmpty ? nil : HaikuExtractor(apiKey: apiKey)
    }

    var answerer: (any Answerer)? {
        apiKey.isEmpty ? nil : HaikuAnswerer(apiKey: apiKey)
    }

    var isManualMode: Bool { classifier == nil }
}

enum KeychainStore {
    enum Key: String { case haikuAPIKey = "haiku-api-key" }
    private static let service = "LifeCoach"

    static func save(_ value: String, forKey key: Key) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                       kSecAttrService: service,
                                       kSecAttrAccount: key.rawValue]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var attrs = query
        attrs[kSecValueData] = Data(value.utf8)
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load(forKey key: Key) -> String? {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
                                       kSecAttrService: service,
                                       kSecAttrAccount: key.rawValue,
                                       kSecReturnData: true,
                                       kSecMatchLimit: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
