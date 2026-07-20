import Foundation
@testable import LinguaMeshFeature
import XCTest

@MainActor
final class KeychainCredentialStoreTests: XCTestCase {
    func testCredentialLifecycleUsesIsolatedKeychainService() async throws {
        let service = "org.linguamesh.tests.\(UUID().uuidString)"
        let account = "provider-\(UUID().uuidString)"
        let store = KeychainCredentialStore(service: service)

        let initiallyStored = try await store.containsCredential(account: account)
        XCTAssertFalse(initiallyStored)
        try await store.store("test-value", account: account)
        let stored = try await store.containsCredential(account: account)
        let value = try await store.credential(account: account)
        XCTAssertTrue(stored)
        XCTAssertEqual(value, "test-value")
        try await store.deleteCredential(account: account)
        let remains = try await store.containsCredential(account: account)
        XCTAssertFalse(remains)
    }
}
