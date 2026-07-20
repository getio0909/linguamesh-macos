import Foundation

enum ProtocolMessageType {
    static let translateText = "translate_text"
    static let started = "started"
    static let textDelta = "text_delta"
    static let completed = "completed"
    static let cancelled = "cancelled"
    static let failed = "failed"
}

struct ProtocolEnvelope: Equatable, Sendable {
    let protocolVersion: UInt32
    let operationIdentifier: String
    let correlationIdentifier: String
    let sequence: UInt64
    let messageType: String
    let payload: Data
}

struct ProtocolFailure: Equatable, Sendable {
    let kind: String
    let safeMessage: String
}

enum ProtocolCodecError: Error, Equatable, Sendable {
    case messageTooLarge
    case truncated
    case malformedVarint
    case invalidWireType
    case invalidUTF8
    case missingRequiredField
    case incompatibleVersion(actual: UInt32)
}

enum ProtocolCodec {
    static let version: UInt32 = 1
    static let maximumMessageBytes = 1_048_576

    static func encodeTranslationCommand(
        request: CoreTranslationRequest,
        operationIdentifier: String,
        correlationIdentifier: String
    ) throws -> Data {
        var payload = ProtobufWriter()
        try payload.appendString(field: 1, value: request.endpoint)
        try payload.appendString(field: 2, value: request.modelIdentifier)
        try payload.appendString(field: 3, value: request.sourceText)
        try payload.appendString(field: 4, value: request.targetLocale)
        let envelope = ProtocolEnvelope(
            protocolVersion: version,
            operationIdentifier: operationIdentifier,
            correlationIdentifier: correlationIdentifier,
            sequence: 0,
            messageType: ProtocolMessageType.translateText,
            payload: payload.data
        )
        return try encodeEnvelope(envelope)
    }

    static func encodeEnvelope(_ envelope: ProtocolEnvelope) throws -> Data {
        var writer = ProtobufWriter()
        writer.appendVarint(field: 1, value: UInt64(envelope.protocolVersion))
        try writer.appendString(field: 2, value: envelope.operationIdentifier)
        try writer.appendString(field: 3, value: envelope.correlationIdentifier)
        writer.appendVarint(field: 4, value: envelope.sequence)
        try writer.appendString(field: 5, value: envelope.messageType)
        try writer.appendBytes(field: 6, value: envelope.payload)
        guard writer.data.count <= maximumMessageBytes else {
            throw ProtocolCodecError.messageTooLarge
        }
        return writer.data
    }

    static func decodeEnvelope(_ data: Data) throws -> ProtocolEnvelope {
        guard data.count <= maximumMessageBytes else {
            throw ProtocolCodecError.messageTooLarge
        }
        var reader = ProtobufReader(data: data)
        var protocolVersion: UInt32?
        var operationIdentifier: String?
        var correlationIdentifier: String?
        var sequence: UInt64 = 0
        var messageType: String?
        var payload = Data()
        while let field = try reader.nextField() {
            switch field.number {
            case 1:
                let rawVersion = try reader.readVarint(field: field)
                guard let decodedVersion = UInt32(exactly: rawVersion) else {
                    throw ProtocolCodecError.malformedVarint
                }
                protocolVersion = decodedVersion
            case 2:
                operationIdentifier = try reader.readString(field: field)
            case 3:
                correlationIdentifier = try reader.readString(field: field)
            case 4:
                sequence = try reader.readVarint(field: field)
            case 5:
                messageType = try reader.readString(field: field)
            case 6:
                payload = try reader.readBytes(field: field)
            default:
                try reader.skip(field: field)
            }
        }
        guard let protocolVersion,
              let operationIdentifier,
              let correlationIdentifier,
              let messageType,
              !operationIdentifier.isEmpty,
              !correlationIdentifier.isEmpty,
              !messageType.isEmpty
        else {
            throw ProtocolCodecError.missingRequiredField
        }
        guard protocolVersion == version else {
            throw ProtocolCodecError.incompatibleVersion(actual: protocolVersion)
        }
        return ProtocolEnvelope(
            protocolVersion: protocolVersion,
            operationIdentifier: operationIdentifier,
            correlationIdentifier: correlationIdentifier,
            sequence: sequence,
            messageType: messageType,
            payload: payload
        )
    }

    static func decodeTextDelta(_ data: Data) throws -> String {
        var reader = ProtobufReader(data: data)
        var text: String?
        while let field = try reader.nextField() {
            if field.number == 1 {
                text = try reader.readString(field: field)
            } else {
                try reader.skip(field: field)
            }
        }
        guard let text else {
            throw ProtocolCodecError.missingRequiredField
        }
        return text
    }

    static func decodeFailure(_ data: Data) throws -> ProtocolFailure {
        var reader = ProtobufReader(data: data)
        var kind: String?
        var message: String?
        while let field = try reader.nextField() {
            switch field.number {
            case 1:
                kind = try reader.readString(field: field)
            case 2:
                message = try reader.readString(field: field)
            default:
                try reader.skip(field: field)
            }
        }
        guard let kind, let message, !kind.isEmpty else {
            throw ProtocolCodecError.missingRequiredField
        }
        return ProtocolFailure(kind: kind, safeMessage: message)
    }
}

private struct ProtobufField {
    let number: UInt64
    let wireType: UInt8
}

private struct ProtobufWriter {
    private(set) var bytes: [UInt8] = []

    var data: Data { Data(bytes) }

    mutating func appendVarint(field: UInt64, value: UInt64) {
        appendRawVarint((field << 3) | 0)
        appendRawVarint(value)
    }

    mutating func appendString(field: UInt64, value: String) throws {
        try appendBytes(field: field, value: Data(value.utf8))
    }

    mutating func appendBytes(field: UInt64, value: Data) throws {
        guard value.count <= ProtocolCodec.maximumMessageBytes else {
            throw ProtocolCodecError.messageTooLarge
        }
        appendRawVarint((field << 3) | 2)
        appendRawVarint(UInt64(value.count))
        bytes.append(contentsOf: value)
    }

    private mutating func appendRawVarint(_ value: UInt64) {
        var remaining = value
        while remaining >= 0x80 {
            bytes.append(UInt8(remaining & 0x7f) | 0x80)
            remaining >>= 7
        }
        bytes.append(UInt8(remaining))
    }
}

private struct ProtobufReader {
    private let bytes: [UInt8]
    private var index = 0

    init(data: Data) {
        bytes = Array(data)
    }

    mutating func nextField() throws -> ProtobufField? {
        guard index < bytes.count else {
            return nil
        }
        let tag = try readRawVarint()
        let number = tag >> 3
        let wireType = UInt8(tag & 0x07)
        guard number > 0 else {
            throw ProtocolCodecError.invalidWireType
        }
        return ProtobufField(number: number, wireType: wireType)
    }

    mutating func readVarint(field: ProtobufField) throws -> UInt64 {
        guard field.wireType == 0 else {
            throw ProtocolCodecError.invalidWireType
        }
        return try readRawVarint()
    }

    mutating func readString(field: ProtobufField) throws -> String {
        let value = try readBytes(field: field)
        guard let string = String(data: value, encoding: .utf8) else {
            throw ProtocolCodecError.invalidUTF8
        }
        return string
    }

    mutating func readBytes(field: ProtobufField) throws -> Data {
        guard field.wireType == 2 else {
            throw ProtocolCodecError.invalidWireType
        }
        let length = try readRawVarint()
        guard length <= UInt64(ProtocolCodec.maximumMessageBytes),
              length <= UInt64(bytes.count - index)
        else {
            throw ProtocolCodecError.truncated
        }
        let end = index + Int(length)
        let value = Data(bytes[index..<end])
        index = end
        return value
    }

    mutating func skip(field: ProtobufField) throws {
        switch field.wireType {
        case 0:
            _ = try readRawVarint()
        case 1:
            try advance(by: 8)
        case 2:
            let length = try readRawVarint()
            guard length <= UInt64(Int.max) else {
                throw ProtocolCodecError.messageTooLarge
            }
            try advance(by: Int(length))
        case 5:
            try advance(by: 4)
        default:
            throw ProtocolCodecError.invalidWireType
        }
    }

    private mutating func readRawVarint() throws -> UInt64 {
        var result: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard index < bytes.count else {
                throw ProtocolCodecError.truncated
            }
            let byte = bytes[index]
            index += 1
            if shift == 63 && byte > 1 {
                throw ProtocolCodecError.malformedVarint
            }
            result |= UInt64(byte & 0x7f) << UInt64(shift)
            if byte & 0x80 == 0 {
                return result
            }
        }
        throw ProtocolCodecError.malformedVarint
    }

    private mutating func advance(by count: Int) throws {
        guard count >= 0, count <= bytes.count - index else {
            throw ProtocolCodecError.truncated
        }
        index += count
    }
}
