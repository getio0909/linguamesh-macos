import Foundation
@testable import LinguaMeshFeature
import XCTest

@MainActor
final class AppModelTests: XCTestCase {
    func testStreamedTranslationAndLocaleSwitchRetainState() async {
        let core = ScriptedCoreClient(
            events: [.started, .textDelta("你"), .textDelta("好"), .completed]
        )
        let preferences = MemoryPreferences()
        let model = AppModel(
            core: core,
            credentialStore: MemoryCredentialStore(),
            preferences: preferences
        )
        model.setSourceText("Hello")
        model.translate()
        await model.waitForCurrentOperation()

        XCTAssertEqual(model.state.phase, .completed)
        XCTAssertEqual(model.state.translatedText, "你好")
        model.setLocale(.arabic)
        XCTAssertEqual(model.state.sourceText, "Hello")
        XCTAssertEqual(model.state.translatedText, "你好")
        XCTAssertEqual(model.state.uiLocale, .arabic)
        XCTAssertEqual(preferences.loadLocale(), .arabic)
    }

    func testCancellationRetainsPartialOutput() async {
        let core = CancellableCoreClient()
        let model = AppModel(
            core: core,
            credentialStore: MemoryCredentialStore(),
            preferences: MemoryPreferences()
        )
        model.setSourceText("Cancel this stream")
        model.selectModel("fake-slow-translator")
        model.translate()
        await waitUntil { model.state.translatedText == "partial" }
        model.cancel()
        await model.waitForCurrentOperation()

        XCTAssertEqual(model.state.phase, .cancelled)
        XCTAssertEqual(model.state.translatedText, "partial")
        XCTAssertTrue(model.state.outputIsPartial)
        let cancellationCount = await core.cancellationCount()
        XCTAssertEqual(cancellationCount, 1)
    }

    func testCredentialIsStoredOutsidePreferences() async {
        let credentials = MemoryCredentialStore()
        let preferences = MemoryPreferences()
        let model = AppModel(
            core: ScriptedCoreClient(events: []),
            credentialStore: credentials,
            preferences: preferences
        )
        await model.saveCredential("test-value")

        XCTAssertTrue(model.state.provider.hasStoredCredential)
        let stored = try? await credentials.credential(
            account: model.state.provider.identifier
        )
        XCTAssertEqual(stored, "test-value")
        XCTAssertFalse(String(describing: model.state).contains("test-value"))
        XCTAssertNil(preferences.defaults.object(forKey: "credential"))
        XCTAssertFalse(
            preferences.defaults.dictionaryRepresentation().values.contains { value in
                String(describing: value).contains("test-value")
            }
        )
    }

    func testTypedAuthenticationErrorUsesSelectedLocale() async {
        let core = ScriptedCoreClient(
            events: [
                .started,
                .failed(
                    kind: .authentication,
                    safeMessage: "Authentication failed."
                ),
            ]
        )
        let model = AppModel(
            core: core,
            credentialStore: MemoryCredentialStore(),
            preferences: MemoryPreferences()
        )
        model.setLocale(.simplifiedChinese)
        model.setSourceText("Hello")
        model.translate()
        await model.waitForCurrentOperation()

        XCTAssertEqual(model.state.phase, .failed)
        XCTAssertEqual(model.state.presentedError?.kind, .authentication)
        XCTAssertNotEqual(
            model.state.presentedError?.message,
            "Check the credentials for Local test provider and try again."
        )
        XCTAssertFalse(model.state.presentedError?.message.contains("%1$@") ?? true)
        XCTAssertTrue(model.state.presentedError?.message.contains("Local test provider") ?? false)
        XCTAssertEqual(model.state.diagnostics.lastSafeErrorKind, .authentication)
    }

    func testOnboardingCompletionDoesNotChangeTranslationState() {
        let preferences = MemoryPreferences()
        let model = AppModel(
            core: ScriptedCoreClient(events: []),
            credentialStore: MemoryCredentialStore(),
            preferences: preferences
        )
        model.setSourceText("Keep this text")
        model.completeOnboarding()

        XCTAssertFalse(model.state.showsOnboarding)
        XCTAssertEqual(model.state.sourceText, "Keep this text")
        XCTAssertTrue(preferences.hasCompletedOnboarding())
    }

    func testThemeSwitchPersistsWithoutChangingTranslationState() {
        var initialState = AppState.initial
        initialState.sourceText = "Hello"
        initialState.translatedText = "你好"
        initialState.phase = .completed
        let preferences = MemoryPreferences()
        let model = AppModel(
            core: ScriptedCoreClient(events: []),
            credentialStore: MemoryCredentialStore(),
            preferences: preferences,
            initialState: initialState
        )
        model.setTheme(.dark)

        XCTAssertEqual(model.state.theme, .dark)
        XCTAssertEqual(model.state.sourceText, "Hello")
        XCTAssertEqual(model.state.translatedText, "你好")
        XCTAssertEqual(preferences.loadTheme(), .dark)
    }

    func testQuickModelSwitchChangesTheNextCoreRequest() async {
        let core = RecordingCoreClient()
        let model = AppModel(
            core: core,
            credentialStore: MemoryCredentialStore(),
            preferences: MemoryPreferences()
        )
        model.setSourceText("Hello")
        model.selectModel("fake-slow-translator")
        model.translate()
        await model.waitForCurrentOperation()

        let request = await core.lastRequest()
        XCTAssertEqual(request?.modelIdentifier, "fake-slow-translator")
    }

    func testBlankProviderNameIsRejectedBeforeCoreSubmission() async {
        let core = RecordingCoreClient()
        let model = AppModel(
            core: core,
            credentialStore: MemoryCredentialStore(),
            preferences: MemoryPreferences()
        )
        model.setProviderName("   ")
        model.setSourceText("Hello")
        model.translate()

        XCTAssertEqual(model.state.phase, .failed)
        XCTAssertEqual(model.state.presentedError?.kind, .invalidConfiguration)
        let request = await core.lastRequest()
        XCTAssertNil(request)
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<200 {
            if condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Condition did not become true.")
    }
}

private actor ScriptedCoreClient: CoreClient {
    let events: [CoreTranslationEvent]

    init(events: [CoreTranslationEvent]) {
        self.events = events
    }

    func compatibility() async -> CompatibilitySnapshot {
        CompatibilitySnapshot(abiMajor: 1, protocolVersion: 1)
    }

    func translate(
        _ request: CoreTranslationRequest
    ) async throws -> AsyncThrowingStream<CoreTranslationEvent, Error> {
        let events = events
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func cancel() async throws {}
    func shutdown() async throws {}
}

private actor CancellableCoreClient: CoreClient {
    private var cancelled = false
    private var cancelCount = 0
    private var waiter: CheckedContinuation<Void, Never>?

    func compatibility() async -> CompatibilitySnapshot {
        CompatibilitySnapshot(abiMajor: 1, protocolVersion: 1)
    }

    func translate(
        _ request: CoreTranslationRequest
    ) async throws -> AsyncThrowingStream<CoreTranslationEvent, Error> {
        let client = self
        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.textDelta("partial"))
            Task {
                await client.waitForCancellation()
                continuation.yield(.cancelled)
                continuation.finish()
            }
        }
    }

    func cancel() async throws {
        cancelCount += 1
        cancelled = true
        waiter?.resume()
        waiter = nil
    }

    func shutdown() async throws {}

    func cancellationCount() -> Int {
        cancelCount
    }

    private func waitForCancellation() async {
        if cancelled {
            return
        }
        await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }
}

private actor RecordingCoreClient: CoreClient {
    private var recordedRequest: CoreTranslationRequest?

    func compatibility() async -> CompatibilitySnapshot {
        CompatibilitySnapshot(abiMajor: 1, protocolVersion: 1)
    }

    func translate(
        _ request: CoreTranslationRequest
    ) async throws -> AsyncThrowingStream<CoreTranslationEvent, Error> {
        recordedRequest = request
        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.completed)
            continuation.finish()
        }
    }

    func cancel() async throws {}
    func shutdown() async throws {}

    func lastRequest() -> CoreTranslationRequest? {
        recordedRequest
    }
}

private actor MemoryCredentialStore: CredentialStore {
    private var values: [String: String] = [:]

    func store(_ credential: String, account: String) async throws {
        values[account] = credential
    }

    func credential(account: String) async throws -> String? {
        values[account]
    }

    func containsCredential(account: String) async throws -> Bool {
        values[account] != nil
    }

    func deleteCredential(account: String) async throws {
        values[account] = nil
    }
}

@MainActor
private final class MemoryPreferences: UIPreferencesStore {
    let defaults: UserDefaults

    init() {
        let suite = "org.linguamesh.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
    }

    func loadTheme() -> ThemePreference {
        defaults.string(forKey: "theme").flatMap(ThemePreference.init(rawValue:)) ?? .system
    }

    func loadLocale() -> UILocale {
        defaults.string(forKey: "locale").flatMap(UILocale.init(rawValue:)) ?? .english
    }

    func hasCompletedOnboarding() -> Bool {
        defaults.bool(forKey: "onboarding")
    }

    func saveTheme(_ theme: ThemePreference) {
        defaults.set(theme.rawValue, forKey: "theme")
    }

    func saveLocale(_ locale: UILocale) {
        defaults.set(locale.rawValue, forKey: "locale")
    }

    func saveOnboardingCompleted() {
        defaults.set(true, forKey: "onboarding")
    }
}
