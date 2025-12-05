import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    // ADD THIS LINE - enables sharing between app and extension
    private let accessGroup = "group.com.hongkeilung.radar"
    
    func saveAccessToken(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecValueData as String: token.data(using: .utf8)!,
            kSecAttrAccessGroup as String: accessGroup  // ADD THIS LINE
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func readAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecReturnData as String: true,
            kSecAttrAccessGroup as String: accessGroup  // ADD THIS LINE
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func deleteAccessToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecAttrAccessGroup as String: accessGroup  // ADD THIS LINE
        ]
        SecItemDelete(query as CFDictionary)
    }
}
