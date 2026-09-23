import Foundation
import LocalAuthentication
import Security

/// API keys live only here (generic passwords, service com.jev.assistant.mac).
enum Keychain {
    private static let service = "com.jev.assistant.mac"

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// "" when nothing is stored. nil when macOS would have shown the login-password
    /// dialog: this build is not on the item's access list, and we refuse that prompt.
    static func get(_ account: String) -> String? {
        let context = LAContext()
        context.interactionNotAllowed = true
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecUseAuthenticationContext as String] = context
        var out: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &out)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let d = out as? Data else { return nil }
        return String(decoding: d, as: UTF8.self)
    }

    /// Empty value deletes the key.
    static func set(_ account: String, _ value: String) {
        SecItemDelete(query(account) as CFDictionary)
        guard !value.isEmpty else { return }
        var add = query(account)
        add[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}
