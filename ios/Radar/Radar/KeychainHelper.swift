import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    // ADD THIS LINE - enables sharing between app and extension
    private let accessGroup = "group.com.hongkeilung.radar"
    
    func saveAccessToken(_ token: String) {
        // Delete old token WITHOUT access group (if it exists)
        let oldQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token"
        ]
        SecItemDelete(oldQuery as CFDictionary)
        
        // Delete old token WITH access group (if it exists)
        let groupQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "access_token",
            kSecAttrAccessGroup as String: accessGroup
        ]
        SecItemDelete(groupQuery as CFDictionary)
        
        // Save new token WITH access group
        var saveQuery = groupQuery
        saveQuery[kSecValueData as String] = token.data(using: .utf8)!
        let status = SecItemAdd(saveQuery as CFDictionary, nil)
        
        print("[Keychain] Save token status: \(status) (0 = success)")
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
