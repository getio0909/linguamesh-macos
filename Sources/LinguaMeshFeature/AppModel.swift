import Combine
import Foundation

@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var state: AppState

    private let core: any CoreClient
    private let credentialStore: any CredentialStore
    private let preferences: any UIPreferencesStore
    private let localizer = Localizer()
    private var operationTask: Task<Void, Never>?

    public init(
        core: any CoreClient,
        credentialStore: any CredentialStore,
        preferences: any UIPreferencesStore,
        initialState: AppState = .initial,
        startupFailure: ClientFailure? = nil
    ) {
        self.core = core
        self.credentialStore = credentialStore
        self.preferences = preferences
        var configuredState = initialState
        configuredState.theme = preferences.loadTheme()
        configuredState.uiLocale = preferences.loadLocale()
        configuredState.showsOnboarding = !preferences.hasCompletedOnboarding()
        if let startupFailure {
            configuredState.phase = .failed
            configuredState.presentedError = localizer.presentedError(
                kind: startupFailure.kind,
                locale: configuredState.uiLocale,
                providerName: configuredState.provider.displayName
            )
            configuredState.diagnostics.lastSafeErrorKind = startupFailure.kind
        }
        state = configuredState
    }

    public static func live() -> AppModel {
        let preferences = UserDefaultsUIPreferences()
        let credentials = KeychainCredentialStore()
        do {
            return AppModel(
                core: try NativeCoreClient(credentialStore: credentials),
                credentialStore: credentials,
                preferences: preferences
            )
        } catch {
            let failure = error as? ClientFailure ?? ClientFailure(
                kind: .abiIncompatible,
                safeMessage: "The embedded core could not be initialized."
            )
            return AppModel(
                core: UnavailableCoreClient(failure: failure),
                credentialStore: credentials,
                preferences: preferences,
                startupFailure: failure
            )
        }
    }

    public func prepare() async {
        state.diagnostics.coreCompatibility = await core.compatibility()
        do {
            state.provider.hasStoredCredential = try await credentialStore.containsCredential(
                account: state.provider.identifier
            )
        } catch {
            present(kind: .secureStorageUnavailable)
        }
    }

    public func setSourceText(_ value: String) {
        state.sourceText = value
    }

    public func setTargetLocale(_ value: String) {
        state.targetLocale = value
    }

    public func setProviderName(_ value: String) {
        guard !state.phase.isActive else {
            return
        }
        state.provider.displayName = value
    }

    public func setProviderEndpoint(_ value: String) {
        guard !state.phase.isActive else {
            return
        }
        state.provider.endpoint = value
    }

    public func selectModel(_ identifier: String) {
        guard !state.phase.isActive else {
            return
        }
        state.provider.modelIdentifier = identifier
    }

    public func setTheme(_ theme: ThemePreference) {
        state.theme = theme
        preferences.saveTheme(theme)
    }

    public func setLocale(_ locale: UILocale) {
        state.uiLocale = locale
        preferences.saveLocale(locale)
        if let error = state.presentedError {
            state.presentedError = localizer.presentedError(
                kind: error.kind,
                locale: locale,
                providerName: state.provider.displayName
            )
        }
    }

    public func completeOnboarding() {
        state.showsOnboarding = false
        preferences.saveOnboardingCompleted()
    }

    public func saveCredential(_ credential: String) async {
        guard !state.phase.isActive else {
            return
        }
        guard !credential.isEmpty else {
            present(kind: .invalidConfiguration)
            return
        }
        do {
            try await credentialStore.store(
                credential,
                account: state.provider.identifier
            )
            state.provider.hasStoredCredential = true
            state.presentedError = nil
        } catch {
            present(kind: .secureStorageUnavailable)
        }
    }

    public func deleteCredential() async {
        guard !state.phase.isActive else {
            return
        }
        do {
            try await credentialStore.deleteCredential(account: state.provider.identifier)
            state.provider.hasStoredCredential = false
            state.presentedError = nil
        } catch {
            present(kind: .secureStorageUnavailable)
        }
    }

    public func translate() {
        guard !state.phase.isActive else {
            return
        }
        guard !state.provider.displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            present(kind: .invalidConfiguration)
            return
        }
        let request = CoreTranslationRequest(
            endpoint: state.provider.endpoint,
            modelIdentifier: state.provider.modelIdentifier,
            sourceText: state.sourceText,
            targetLocale: state.targetLocale,
            secretReference: state.provider.hasStoredCredential
                ? "session:\(UUID().uuidString.lowercased())"
                : nil,
            credentialAccount: state.provider.hasStoredCredential
                ? state.provider.identifier
                : nil
        )
        state.translatedText = ""
        state.outputIsPartial = false
        state.presentedError = nil
        state.phase = .starting
        let core = core
        operationTask = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let events = try await core.translate(request)
                for try await event in events {
                    self.consume(event)
                }
            } catch let failure as ClientFailure {
                self.consumeFailure(failure)
            } catch is CancellationError {
                self.consume(.cancelled)
            } catch {
                self.consumeFailure(
                    ClientFailure(
                        kind: .internalFailure,
                        safeMessage: "The translation task failed unexpectedly."
                    )
                )
            }
        }
    }

    public func cancel() {
        guard state.phase.isActive, state.phase != .cancelling else {
            return
        }
        state.phase = .cancelling
        let core = core
        Task { [weak self] in
            do {
                try await core.cancel()
            } catch let failure as ClientFailure {
                self?.consumeFailure(failure)
            } catch {
                self?.consumeFailure(
                    ClientFailure(
                        kind: .internalFailure,
                        safeMessage: "The translation could not be cancelled."
                    )
                )
            }
        }
    }

    public func clear() {
        guard !state.phase.isActive else {
            return
        }
        state.sourceText = ""
        state.translatedText = ""
        state.outputIsPartial = false
        state.presentedError = nil
        state.phase = .idle
    }

    public func dismissError() {
        state.presentedError = nil
    }

    public func localized(
        _ key: String,
        fallback: String,
        arguments: [String] = []
    ) -> String {
        localizer.text(
            key,
            fallback: fallback,
            locale: state.uiLocale,
            arguments: arguments
        )
    }

    func waitForCurrentOperation() async {
        await operationTask?.value
    }

    private func consume(_ event: CoreTranslationEvent) {
        switch event {
        case .started:
            state.phase = .streaming
        case let .textDelta(text):
            state.translatedText.append(text)
            state.phase = .streaming
        case .completed:
            state.phase = .completed
            state.outputIsPartial = false
        case .cancelled:
            state.phase = .cancelled
            state.outputIsPartial = !state.translatedText.isEmpty
        case let .failed(kind, _):
            present(kind: kind)
            state.outputIsPartial = !state.translatedText.isEmpty
        }
    }

    private func consumeFailure(_ failure: ClientFailure) {
        present(kind: failure.kind)
        state.outputIsPartial = !state.translatedText.isEmpty
    }

    private func present(kind: ClientErrorKind) {
        state.phase = .failed
        state.presentedError = localizer.presentedError(
            kind: kind,
            locale: state.uiLocale,
            providerName: state.provider.displayName
        )
        state.diagnostics.lastSafeErrorKind = kind
    }
}
