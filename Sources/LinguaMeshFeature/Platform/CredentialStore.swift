import Foundation
import Security

public protocol CredentialStore: Sendable {
    func store(_ credential: String, account: String) async throws
    func credential(account: String) async throws -> String?
    func containsCredential(account: String) async throws -> Bool
    func deleteCredential(account: String) async throws
}

public enum CredentialStoreError: Error, Equatable, Sendable {
    case invalidCredentialEncoding
    case unexpectedData
    case keychainStatus(OSStatus)
}

public actor KeychainCredentialStore: CredentialStore {
    public static let defaultService = "org.linguamesh.macos.provider-credentials"

    private let service: String

    public init(service: String = defaultService) {
        self.service = service
    }

    public func store(_ credential: String, account: String) async throws {
        guard let data = credential.data(using: .utf8) else {
            throw CredentialStoreError.invalidCredentialEncoding
        }
        let query = baseQuery(account: account)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw CredentialStoreError.keychainStatus(updateStatus)
        }
        var insert = query
        for (key, value) in attributes {
            insert[key] = value
        }
        let insertStatus = SecItemAdd(insert as CFDictionary, nil)
        guard insertStatus == errSecSuccess else {
            throw CredentialStoreError.keychainStatus(insertStatus)
        }
    }

    public func credential(account: String) async throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychainStatus(status)
        }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            throw CredentialStoreError.unexpectedData
        }
        return value
    }

    public func containsCredential(account: String) async throws -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnData] = kCFBooleanFalse
        query[kSecMatchLimit] = kSecMatchLimitOne
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecItemNotFound {
            return false
        }
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychainStatus(status)
        }
        return true
    }

    public func deleteCredential(account: String) async throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychainStatus(status)
        }
    }

    private func baseQuery(account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kCFBooleanFalse as Any,
        ]
    }
}
