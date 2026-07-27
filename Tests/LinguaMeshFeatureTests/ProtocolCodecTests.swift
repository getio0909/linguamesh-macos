import Foundation
@testable import LinguaMeshFeature
import XCTest

final class ProtocolCodecTests: XCTestCase {
    func testTranslationEnvelopeRoundTrips() throws {
        let request = CoreTranslationRequest(
            endpoint: "http://127.0.0.1:40123/v1/",
            modelIdentifier: "fake-translator",
            sourceText: "Hello",
            targetLocale: "zh-CN"
        )
        let encoded = try ProtocolCodec.encodeTranslationCommand(
            request: request,
            operationIdentifier: "operation",
            correlationIdentifier: "correlation"
        )
        let envelope = try ProtocolCodec.decodeEnvelope(encoded)
        XCTAssertEqual(envelope.protocolVersion, 1)
        XCTAssertEqual(envelope.operationIdentifier, "operation")
        XCTAssertEqual(envelope.correlationIdentifier, "correlation")
        XCTAssertEqual(envelope.sequence, 0)
        XCTAssertEqual(envelope.messageType, ProtocolMessageType.translateText)
        XCTAssertFalse(envelope.payload.isEmpty)
    }

    func testHostSecretMessagesRoundTripWithinBounds() throws {
        let request = CoreTranslationRequest(
            endpoint: "http://127.0.0.1:40123/v1/",
            modelIdentifier: "fake-translator",
            sourceText: "Hello",
            targetLocale: "zh-CN",
            secretReference: "session:11111111-1111-4111-8111-111111111111",
            credentialAccount: "provider-account"
        )
        let command = try ProtocolCodec.encodeTranslationCommand(
            request: request,
            operationIdentifier: "operation",
            correlationIdentifier: "correlation"
        )
        let envelope = try ProtocolCodec.decodeEnvelope(command)
        XCTAssertEqual(envelope.messageType, ProtocolMessageType.translateText)

        let response = try ProtocolCodec.encodeHostSecretResponse(
            operationIdentifier: "operation",
            correlationIdentifier: "correlation",
            requestIdentifier: "request",
            resolution: .provided,
            secret: "test-secret"
        )
        let responseEnvelope = try ProtocolCodec.decodeEnvelope(response)
        XCTAssertEqual(responseEnvelope.messageType, ProtocolMessageType.hostSecretResponse)
        let required = try ProtocolCodec.decodeSecretRequired(
            Data([0x0a, 0x07]) + Data("request".utf8) + Data([0x12, 0x2c]) + Data("session:11111111-1111-4111-8111-111111111111".utf8)
        )
        XCTAssertEqual(required.requestIdentifier, "request")
        XCTAssertEqual(required.secretReference, "session:11111111-1111-4111-8111-111111111111")
    }

    func testTextDeltaAndFailurePayloadsDecode() throws {
        let delta = try ProtocolCodec.decodeTextDelta(lengthDelimited(field: 1, value: "你好"))
        XCTAssertEqual(delta, "你好")

        var failureData = lengthDelimited(field: 1, value: "authentication")
        failureData.append(lengthDelimited(field: 2, value: "Authentication failed."))
        let failure = try ProtocolCodec.decodeFailure(failureData)
        XCTAssertEqual(failure.kind, "authentication")
        XCTAssertEqual(failure.safeMessage, "Authentication failed.")
    }

    func testIncompatibleProtocolIsRejected() throws {
        let data = try ProtocolCodec.encodeEnvelope(
            ProtocolEnvelope(
                protocolVersion: 2,
                operationIdentifier: "operation",
                correlationIdentifier: "correlation",
                sequence: 0,
                messageType: ProtocolMessageType.started,
                payload: Data()
            )
        )
        XCTAssertThrowsError(try ProtocolCodec.decodeEnvelope(data)) { error in
            XCTAssertEqual(
                error as? ProtocolCodecError,
                .incompatibleVersion(actual: 2)
            )
        }
    }

    func testTruncatedPayloadIsRejected() {
        XCTAssertThrowsError(try ProtocolCodec.decodeEnvelope(Data([0x0a, 0xff])))
    }

    func testOversizedTranslationCommandIsRejected() {
        let request = CoreTranslationRequest(
            endpoint: "http://127.0.0.1:40123/v1/",
            modelIdentifier: "fake-translator",
            sourceText: String(
                repeating: "a",
                count: ProtocolCodec.maximumMessageBytes
            ),
            targetLocale: "zh-CN"
        )
        XCTAssertThrowsError(
            try ProtocolCodec.encodeTranslationCommand(
                request: request,
                operationIdentifier: "operation",
                correlationIdentifier: "correlation"
            )
        ) { error in
            XCTAssertEqual(error as? ProtocolCodecError, .messageTooLarge)
        }
    }

    private func lengthDelimited(field: UInt8, value: String) -> Data {
        let bytes = Array(value.utf8)
        precondition(bytes.count < 128)
        return Data([(field << 3) | 2, UInt8(bytes.count)] + bytes)
    }
}
