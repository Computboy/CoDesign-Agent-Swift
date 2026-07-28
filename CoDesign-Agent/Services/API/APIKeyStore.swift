import Foundation
import Security

enum APIKeyStore {
    private static let account = "llmAPIKey"
    private static let legacyDefaultsKey = "llmAPIKey"

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "CoDesign-Agent"
    }

    static func load() -> String {
        if let data = keychainData(),
           let value = String(data: data, encoding: .utf8) {
            return value
        }

        let defaults = UserDefaults.standard
        guard let legacyValue = defaults.string(forKey: legacyDefaultsKey),
              !legacyValue.isEmpty else {
            return ""
        }

        if save(legacyValue) {
            defaults.removeObject(forKey: legacyDefaultsKey)
        }
        return legacyValue
    }

    @discardableResult
    static func save(_ value: String) -> Bool {
        guard !value.isEmpty else {
            return delete()
        }

        guard let data = value.data(using: .utf8) else {
            return false
        }

        let query = baseQuery
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            return true
        }

        guard updateStatus == errSecItemNotFound else {
            return false
        }

        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        if addStatus == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            return true
        }
        return false
    }

    @discardableResult
    static func delete() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func keychainData() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }
}
