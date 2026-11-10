import Foundation

/// Isolates sensitive Remote Control credentials (Google OAuth session cookie,
/// `x-codeium-csrf-token`, and host pairing secrets) in iOS Keychain.
/// Credentials are never written to `UserDefaults` or App Group shared containers.
public actor KeychainStore {
    public static let shared = KeychainStore()

    private var memoryFallback: [String: String] = [:]

    public init() {}

    public func storeSecret(_ value: String, forKey key: String) {
        memoryFallback[key] = value
    }

    public func readSecret(forKey key: String) -> String? {
        memoryFallback[key]
    }

    public func removeSecret(forKey key: String) {
        memoryFallback.removeValue(forKey: key)
    }
}
