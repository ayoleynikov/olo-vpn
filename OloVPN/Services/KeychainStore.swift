import Foundation
import Security

enum KeychainStore {
    private static let service = "app.olo.vpn.secrets"

    static func saveSecret(serverID: UUID, password: String, uuid: String) {
        let payload: [String: String] = [
            "password": password,
            "uuid": uuid
        ]
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let account = serverID.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func loadSecret(serverID: UUID) -> (password: String, uuid: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return ("", "")
        }
        return (dict["password"] ?? "", dict["uuid"] ?? "")
    }

    static func deleteSecret(serverID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
