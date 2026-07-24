import Foundation
import LinguaMeshCore

// 生成的包装层通过内部条件锁保护句柄和并发 ABI 调用。
private final class CoreSession: @unchecked Sendable {
    private let engine: LinguaMeshEngine
    let compatibility: CompatibilitySnapshot

    init() throws {
        let actual = LinguaMeshEngine.queryCompatibility()
        compatibility = CompatibilitySnapshot(
            abiMajor: actual.abiMajor,
            protocolVersion: actual.protocolVersion
        )
        engine = try LinguaMeshEngine(
            expectedABI: LinguaMeshEngine.abiVersionMajor,
            expectedProtocol: ProtocolCodec.version
        )
    }

    deinit {
        try? engine.close()
    }

    func submit(_ command: Data) throws {
        try engine.submit(command)
    }

    func pollEvent(timeoutMilliseconds: UInt32) throws -> Data {
        try engine.pollEvent(timeoutMilliseconds: timeoutMilliseconds)
    }

    func cancel() throws {
        try engine.cancel()
    }

    func sendHostResponse(_ response: Data) throws {
        try engine.sendHostResponse(response)
    }

    func shutdown() throws {
        try engine.shutdown()
    }
}

// 终止标记允许 actor 在接受下一次请求前等待对应工作任务完成清理。
private final class StreamTerminationSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var terminated = false

    func markTerminated() {
        lock.lock()
        terminated = true
        lock.unlock()
    }

    func isTerminated() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminated
    }
}

public actor NativeCoreClient: CoreClient {
    private var session: CoreSession
    private var activeOperationIdentifier: String?
    private var activeWorker: Task<Void, Never>?
    private var activeTerminationSignal: StreamTerminationSignal?
    private let credentialStore: any CredentialStore

    public init(credentialStore: any CredentialStore = KeychainCredentialStore()) throws {
        self.credentialStore = credentialStore
        do {
            session = try CoreSession()
        } catch {
            throw Self.mapBoundaryError(error)
        }
    }

    public func compatibility() async -> CompatibilitySnapshot {
        session.compatibility
    }

    public func translate(
        _ request: CoreTranslationRequest
    ) async throws -> AsyncThrowingStream<CoreTranslationEvent, Error> {
        try Self.validate(request)
        if activeTerminationSignal?.isTerminated() == true,
           let activeWorker
        {
            await activeWorker.value
        }
        guard activeOperationIdentifier == nil else {
            throw ClientFailure(
                kind: .invalidConfiguration,
                safeMessage: "A translation operation is already active."
            )
        }
        let operationIdentifier = UUID().uuidString.lowercased()
        let correlationIdentifier = UUID().uuidString.lowercased()
        let command: Data
        do {
            command = try ProtocolCodec.encodeTranslationCommand(
                request: request,
                operationIdentifier: operationIdentifier,
                correlationIdentifier: correlationIdentifier
            )
        } catch ProtocolCodecError.messageTooLarge {
            throw ClientFailure(
                kind: .invalidConfiguration,
                safeMessage: "The translation request exceeds the client size limit."
            )
        } catch {
            throw Self.mapBoundaryError(error)
        }
        do {
            try session.submit(command)
        } catch {
            throw Self.mapBoundaryError(error)
        }
        activeOperationIdentifier = operationIdentifier
        return makeEventStream(
            operationIdentifier: operationIdentifier,
            correlationIdentifier: correlationIdentifier,
            secretReference: request.secretReference,
            credentialAccount: request.credentialAccount
        )
    }

    public func cancel() async throws {
        guard activeOperationIdentifier != nil else {
            return
        }
        do {
            try session.cancel()
        } catch {
            throw Self.mapBoundaryError(error)
        }
    }

    public func shutdown() async throws {
        activeWorker?.cancel()
        do {
            try session.shutdown()
            activeOperationIdentifier = nil
            activeWorker = nil
            activeTerminationSignal = nil
        } catch {
            throw Self.mapBoundaryError(error)
        }
    }

    private func makeEventStream(
        operationIdentifier: String,
        correlationIdentifier: String,
        secretReference: String?,
        credentialAccount: String?
    ) -> AsyncThrowingStream<CoreTranslationEvent, Error> {
        let session = session
        let credentialStore = credentialStore
        let terminationSignal = StreamTerminationSignal()
        let streamAndContinuation = AsyncThrowingStream<CoreTranslationEvent, Error>.makeStream(
            bufferingPolicy: .bufferingOldest(128)
        )
        let continuation = streamAndContinuation.continuation
        let worker = Task.detached(priority: .userInitiated) { [weak self, credentialStore] in
            var previousSequence: UInt64?
            do {
                while !Task.isCancelled {
                    if terminationSignal.isTerminated() {
                        try? session.cancel()
                        _ = Self.drainOperation(
                            session: session,
                            operationIdentifier: operationIdentifier,
                            correlationIdentifier: correlationIdentifier
                        )
                        await self?.operationFinished(
                            operationIdentifier,
                            session: session,
                            recreateSession: true
                        )
                        continuation.finish()
                        return
                    }
                    let data = try session.pollEvent(timeoutMilliseconds: 100)
                    if data.isEmpty {
                        continue
                    }
                    let envelope = try ProtocolCodec.decodeEnvelope(data)
                    guard envelope.operationIdentifier == operationIdentifier,
                          envelope.correlationIdentifier == correlationIdentifier
                    else {
                        throw ClientFailure(
                            kind: .malformedResponse,
                            safeMessage: "The core returned an event for another request."
                        )
                    }
                    if let previousSequence, envelope.sequence <= previousSequence {
                        throw ClientFailure(
                            kind: .malformedResponse,
                            safeMessage: "The core returned an out-of-order event."
                        )
                    }
                    previousSequence = envelope.sequence
                    if envelope.messageType == ProtocolMessageType.secretRequired {
                        let required = try ProtocolCodec.decodeSecretRequired(envelope.payload)
                        guard let secretReference,
                              let credentialAccount,
                              required.secretReference == secretReference
                        else {
                            throw ClientFailure(
                                kind: .malformedResponse,
                                safeMessage: "The core requested an unexpected secret reference."
                            )
                        }
                        try await Self.resolveHostSecret(
                            session: session,
                            operationIdentifier: operationIdentifier,
                            correlationIdentifier: correlationIdentifier,
                            requestIdentifier: required.requestIdentifier,
                            credentialAccount: credentialAccount,
                            credentialStore: credentialStore
                        )
                        continue
                    }
                    let event = try Self.decodeEvent(envelope)
                    switch continuation.yield(event) {
                    case .enqueued:
                        break
                    case .dropped:
                        throw ClientFailure(
                            kind: .eventBufferOverflow,
                            safeMessage: "The client event buffer reached its safe limit."
                        )
                    case .terminated:
                        try? session.cancel()
                        if !event.isTerminal {
                            _ = Self.drainOperation(
                                session: session,
                                operationIdentifier: operationIdentifier,
                                correlationIdentifier: correlationIdentifier
                            )
                        }
                        await self?.operationFinished(
                            operationIdentifier,
                            session: session,
                            recreateSession: true
                        )
                        return
                    @unknown default:
                        throw ClientFailure(
                            kind: .internalFailure,
                            safeMessage: "The client received an unknown stream state."
                        )
                    }
                    if event.isTerminal {
                        await self?.operationFinished(
                            operationIdentifier,
                            session: session,
                            recreateSession: event.requiresFreshSession
                        )
                        continuation.finish()
                        return
                    }
                }
                try? session.cancel()
                _ = Self.drainOperation(
                    session: session,
                    operationIdentifier: operationIdentifier,
                    correlationIdentifier: correlationIdentifier
                )
                await self?.operationFinished(
                    operationIdentifier,
                    session: session,
                    recreateSession: true
                )
                continuation.finish(throwing: CancellationError())
            } catch {
                try? session.cancel()
                _ = Self.drainOperation(
                    session: session,
                    operationIdentifier: operationIdentifier,
                    correlationIdentifier: correlationIdentifier
                )
                await self?.operationFinished(
                    operationIdentifier,
                    session: session,
                    recreateSession: true
                )
                continuation.finish(throwing: Self.mapBoundaryError(error))
            }
        }
        activeWorker = worker
        activeTerminationSignal = terminationSignal
        continuation.onTermination = { @Sendable termination in
            if case .cancelled = termination {
                terminationSignal.markTerminated()
                try? session.cancel()
            }
        }
        return streamAndContinuation.stream
    }

    private static func resolveHostSecret(
        session: CoreSession,
        operationIdentifier: String,
        correlationIdentifier: String,
        requestIdentifier: String,
        credentialAccount: String,
        credentialStore: any CredentialStore
    ) async throws {
        let response: Data
        do {
            guard let value = try await credentialStore.credential(account: credentialAccount),
                  !value.isEmpty
            else {
                response = try ProtocolCodec.encodeHostSecretResponse(
                    operationIdentifier: operationIdentifier,
                    correlationIdentifier: correlationIdentifier,
                    requestIdentifier: requestIdentifier,
                    resolution: .unavailable
                )
                try session.sendHostResponse(response)
                return
            }
            var secret = value
            defer { secret.removeAll(keepingCapacity: false) }
            response = try ProtocolCodec.encodeHostSecretResponse(
                operationIdentifier: operationIdentifier,
                correlationIdentifier: correlationIdentifier,
                requestIdentifier: requestIdentifier,
                resolution: .provided,
                secret: secret
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            response = try ProtocolCodec.encodeHostSecretResponse(
                operationIdentifier: operationIdentifier,
                correlationIdentifier: correlationIdentifier,
                requestIdentifier: requestIdentifier,
                resolution: .secureStorageUnavailable
            )
        }
        try session.sendHostResponse(response)
    }

    private func operationFinished(
        _ operationIdentifier: String,
        session finishedSession: CoreSession,
        recreateSession: Bool
    ) {
        if activeOperationIdentifier == operationIdentifier {
            if recreateSession,
               session === finishedSession,
               let replacement = try? CoreSession()
            {
                session = replacement
            }
            activeOperationIdentifier = nil
            activeWorker = nil
            activeTerminationSignal = nil
        }
    }

    private static func drainOperation(
        session: CoreSession,
        operationIdentifier: String,
        correlationIdentifier: String
    ) -> Bool {
        for _ in 0..<20 {
            guard let data = try? session.pollEvent(timeoutMilliseconds: 100) else {
                return false
            }
            if data.isEmpty {
                continue
            }
            guard let envelope = try? ProtocolCodec.decodeEnvelope(data),
                  envelope.operationIdentifier == operationIdentifier,
                  envelope.correlationIdentifier == correlationIdentifier
            else {
                continue
            }
            switch envelope.messageType {
            case ProtocolMessageType.completed,
                 ProtocolMessageType.cancelled,
                 ProtocolMessageType.failed:
                return true
            default:
                continue
            }
        }
        return false
    }

    private static func decodeEvent(_ envelope: ProtocolEnvelope) throws -> CoreTranslationEvent {
        switch envelope.messageType {
        case ProtocolMessageType.started:
            return .started
        case ProtocolMessageType.textDelta:
            return .textDelta(try ProtocolCodec.decodeTextDelta(envelope.payload))
        case ProtocolMessageType.completed:
            return .completed
        case ProtocolMessageType.cancelled:
            return .cancelled
        case ProtocolMessageType.failed:
            let failure = try ProtocolCodec.decodeFailure(envelope.payload)
            return .failed(
                kind: mapErrorKind(failure.kind),
                safeMessage: failure.safeMessage
            )
        default:
            throw ClientFailure(
                kind: .malformedResponse,
                safeMessage: "The core returned an unsupported event type."
            )
        }
    }

    private static func validate(_ request: CoreTranslationRequest) throws {
        guard !request.sourceText.isEmpty,
              !request.modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.targetLocale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw ClientFailure(
                kind: .invalidConfiguration,
                safeMessage: "Source text, model, and target locale are required."
            )
        }
        guard let url = URL(string: request.endpoint),
              let scheme = url.scheme?.lowercased(),
              let host = url.host,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil
        else {
            throw ClientFailure(
                kind: .invalidEndpoint,
                safeMessage: "The provider endpoint is invalid."
            )
        }
        let loopbackHosts = Set(["localhost", "127.0.0.1", "::1"])
        let isLoopback = loopbackHosts.contains(host.lowercased())
        guard scheme == "https" || (scheme == "http" && isLoopback) else {
            throw ClientFailure(
                kind: .invalidEndpoint,
                safeMessage: "Remote providers require HTTPS."
            )
        }
    }

    private static func mapErrorKind(_ rawValue: String) -> ClientErrorKind {
        switch rawValue {
        case "authentication": .authentication
        case "invalid_endpoint": .invalidEndpoint
        case "network": .network
        case "timeout": .timeout
        case "model_unavailable": .modelUnavailable
        case "malformed_response": .malformedResponse
        case "cancelled": .cancellation
        case "protocol_incompatible": .protocolIncompatible
        default: .internalFailure
        }
    }

    private static func mapBoundaryError(_ error: Error) -> ClientFailure {
        if let failure = error as? ClientFailure {
            return failure
        }
        if let compatibilityError = error as? CoreCompatibilityError {
            if compatibilityError.actual.abiMajor == compatibilityError.expected.abiMajor {
                return ClientFailure(
                    kind: .protocolIncompatible,
                    safeMessage: "The embedded core protocol is incompatible with this client."
                )
            }
            return ClientFailure(
                kind: .abiIncompatible,
                safeMessage: "The embedded core is incompatible with this client."
            )
        }
        if let coreError = error as? CoreError {
            switch CoreResult(rawValue: coreError.rawValue) {
            case .protocolIncompatible:
                return ClientFailure(
                    kind: .protocolIncompatible,
                    safeMessage: "The core protocol is incompatible with this client."
                )
            case .invalidArgument:
                return ClientFailure(
                    kind: .invalidEndpoint,
                    safeMessage: "The core rejected the provider endpoint."
                )
            case .malformedMessage, .unsupportedMessage:
                return ClientFailure(
                    kind: .invalidConfiguration,
                    safeMessage: "The core rejected the translation request."
                )
            case .busy:
                return ClientFailure(
                    kind: .invalidConfiguration,
                    safeMessage: "A translation operation is already active."
                )
            case .resourceExhausted:
                return ClientFailure(
                    kind: .eventBufferOverflow,
                    safeMessage: "The core event buffer reached its safe limit."
                )
            case .shutdown:
                return ClientFailure(
                    kind: .internalFailure,
                    safeMessage: "The translation engine is shut down."
                )
            case .panic, .internal, .ok, nil:
                return ClientFailure(
                    kind: .internalFailure,
                    safeMessage: "The translation engine reported an internal failure."
                )
            }
        }
        if let protocolError = error as? ProtocolCodecError {
            if case .incompatibleVersion = protocolError {
                return ClientFailure(
                    kind: .protocolIncompatible,
                    safeMessage: "The core event protocol is incompatible with this client."
                )
            }
            return ClientFailure(
                kind: .malformedResponse,
                safeMessage: "The core returned a malformed event."
            )
        }
        if error is CancellationError {
            return ClientFailure(
                kind: .cancellation,
                safeMessage: "The translation was cancelled."
            )
        }
        return ClientFailure(
            kind: .internalFailure,
            safeMessage: "The client encountered an internal failure."
        )
    }
}

private extension CoreTranslationEvent {
    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed:
            true
        case .started, .textDelta:
            false
        }
    }

    var requiresFreshSession: Bool {
        switch self {
        case .cancelled:
            false
        case .started, .textDelta, .completed, .failed:
            false
        }
    }
}
