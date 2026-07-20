import Foundation

public enum ThemePreference: String, CaseIterable, Hashable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

public enum UILocale: String, CaseIterable, Hashable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case korean = "ko"
    case portugueseBrazil = "pt-BR"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"
    case accentedPseudo = "en-XA"
    case bidirectionalPseudo = "ar-XB"

    public var id: String { rawValue }

    public var locale: Locale { Locale(identifier: rawValue) }

    public var isRightToLeft: Bool {
        self == .arabic || self == .bidirectionalPseudo
    }

    public var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .portugueseBrazil: "Português (Brasil)"
        case .russian: "Русский"
        case .arabic: "العربية"
        case .hindi: "हिन्दी"
        case .accentedPseudo: "Pseudo (accented)"
        case .bidirectionalPseudo: "Pseudo (bidirectional)"
        }
    }
}

public struct ProviderConfiguration: Equatable, Sendable {
    public var identifier: String
    public var displayName: String
    public var endpoint: String
    public var modelIdentifier: String
    public var hasStoredCredential: Bool

    public static let localDefault = ProviderConfiguration(
        identifier: "local-fake-provider",
        displayName: "Local test provider",
        endpoint: "http://127.0.0.1:40123/v1/",
        modelIdentifier: "fake-translator",
        hasStoredCredential: false
    )
}

public enum TranslationPhase: Equatable, Sendable {
    case idle
    case starting
    case streaming
    case cancelling
    case completed
    case cancelled
    case failed

    public var isActive: Bool {
        switch self {
        case .starting, .streaming, .cancelling:
            true
        case .idle, .completed, .cancelled, .failed:
            false
        }
    }
}

public enum ClientErrorKind: String, Equatable, Sendable {
    case authentication
    case invalidEndpoint = "invalid_endpoint"
    case network
    case timeout
    case modelUnavailable = "model_unavailable"
    case malformedResponse = "malformed_response"
    case cancellation
    case invalidConfiguration = "invalid_configuration"
    case secureStorageUnavailable = "secure_storage_unavailable"
    case abiIncompatible = "abi_incompatible"
    case protocolIncompatible = "protocol_incompatible"
    case eventBufferOverflow = "event_buffer_overflow"
    case internalFailure = "internal"
}

public struct PresentedError: Equatable, Sendable {
    public let kind: ClientErrorKind
    public let message: String
    public let recoverySuggestion: String
}

public struct CompatibilitySnapshot: Equatable, Sendable {
    public let abiMajor: UInt32
    public let protocolVersion: UInt32

    public static let requiredBaseline = CompatibilitySnapshot(abiMajor: 1, protocolVersion: 1)
}

public struct DiagnosticsSnapshot: Equatable, Sendable {
    public var appVersion: String
    public var coreCompatibility: CompatibilitySnapshot
    public var profilePersistence: String
    public var credentialTransport: String
    public var lastSafeErrorKind: ClientErrorKind?

    public static let initial = DiagnosticsSnapshot(
        appVersion: "0.1.0-alpha.1",
        coreCompatibility: .requiredBaseline,
        profilePersistence: "Session only",
        credentialTransport: "Unavailable in protocol version 1",
        lastSafeErrorKind: nil
    )
}

public struct AppState: Equatable, Sendable {
    public var provider: ProviderConfiguration
    public var sourceText: String
    public var translatedText: String
    public var targetLocale: String
    public var phase: TranslationPhase
    public var outputIsPartial: Bool
    public var theme: ThemePreference
    public var uiLocale: UILocale
    public var showsOnboarding: Bool
    public var presentedError: PresentedError?
    public var diagnostics: DiagnosticsSnapshot

    public static let initial = AppState(
        provider: .localDefault,
        sourceText: "",
        translatedText: "",
        targetLocale: "zh-CN",
        phase: .idle,
        outputIsPartial: false,
        theme: .system,
        uiLocale: .english,
        showsOnboarding: true,
        presentedError: nil,
        diagnostics: .initial
    )
}
