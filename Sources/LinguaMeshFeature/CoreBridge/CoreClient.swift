import Foundation

public struct CoreTranslationRequest: Equatable, Sendable {
    public let endpoint: String
    public let modelIdentifier: String
    public let sourceText: String
    public let targetLocale: String
    public let secretReference: String?
    public let credentialAccount: String?

    public init(
        endpoint: String,
        modelIdentifier: String,
        sourceText: String,
        targetLocale: String,
        secretReference: String? = nil,
        credentialAccount: String? = nil
    ) {
        self.endpoint = endpoint
        self.modelIdentifier = modelIdentifier
        self.sourceText = sourceText
        self.targetLocale = targetLocale
        self.secretReference = secretReference
        self.credentialAccount = credentialAccount
    }
}

public enum CoreTranslationEvent: Equatable, Sendable {
    case started
    case textDelta(String)
    case completed
    case cancelled
    case failed(kind: ClientErrorKind, safeMessage: String)
}

public struct ClientFailure: Error, Equatable, Sendable {
    public let kind: ClientErrorKind
    public let safeMessage: String

    public init(kind: ClientErrorKind, safeMessage: String) {
        self.kind = kind
        self.safeMessage = safeMessage
    }
}

public protocol CoreClient: Sendable {
    func compatibility() async -> CompatibilitySnapshot
    func translate(
        _ request: CoreTranslationRequest
    ) async throws -> AsyncThrowingStream<CoreTranslationEvent, Error>
    func cancel() async throws
    func shutdown() async throws
}

public struct UnavailableCoreClient: CoreClient {
    private let failure: ClientFailure

    public init(failure: ClientFailure) {
        self.failure = failure
    }

    public func compatibility() async -> CompatibilitySnapshot {
        .requiredBaseline
    }

    public func translate(
        _ request: CoreTranslationRequest
    ) async throws -> AsyncThrowingStream<CoreTranslationEvent, Error> {
        throw failure
    }

    public func cancel() async throws {
        throw failure
    }

    public func shutdown() async throws {}
}
