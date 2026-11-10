import Foundation

/// Swift 6 `Sendable` JSON value representation for Connect-RPC frame payloads.
public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSONValue")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .object(let o): try container.encode(o)
        case .array(let a): try container.encode(a)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let obj) = self { return obj }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let arr) = self { return arr }
        return nil
    }
}

/// Namespace convenience for encoding Connect-RPC 5-byte streaming envelopes.
public enum ConnectEnvelope: Sendable {
    public static func encode(payload: Data, flags: ConnectEnvelopeFrame.Flags = []) -> Data {
        ConnectEnvelopeFrame(flags: flags, payload: payload).encode()
    }
}

/// Implements the Connect-RPC 5-byte streaming envelope format used by
/// `exa.language_server_pb.LanguageServerService` server-streaming methods
/// (`JetboxSubscribeToSummaries`, `StreamCascadeReactiveUpdates`, `StreamAgentStateUpdates`, `ProjectUpdatesStream`).
///
/// Wire layout:
/// - Byte 0: `flags` (`0x00` = uncompressed message, `0x01` = compressed, `0x02` = EndStream trailer)
/// - Bytes 1..4: `uint32` big-endian payload length
/// - Bytes 5..(5+length): JSON or binary Protobuf payload
public struct ConnectEnvelopeFrame: Sendable, Equatable {
    public struct Flags: OptionSet, Sendable, Equatable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let compressed = Flags(rawValue: 0x01)
        public static let endStream  = Flags(rawValue: 0x02)
    }

    public let flags: Flags
    public let payload: Data

    public init(flags: Flags = [], payload: Data) {
        self.flags = flags
        self.payload = payload
    }

    public var isCompressed: Bool {
        flags.contains(.compressed)
    }

    public var isEndStream: Bool {
        flags.contains(.endStream)
    }

    public func encode() -> Data {
        var data = Data(capacity: 5 + payload.count)
        data.append(flags.rawValue)
        var lengthBE = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: &lengthBE) { data.append(contentsOf: $0) }
        data.append(payload)
        return data
    }
}

/// Incremental stream parser that buffers incoming bytes from `URLSessionDataTask` or WebSocket
/// and yields complete `ConnectEnvelopeFrame` frames.
public struct ConnectStreamParser: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func feed(_ chunk: Data) -> [ConnectEnvelopeFrame] {
        buffer.append(chunk)
        var frames: [ConnectEnvelopeFrame] = []

        while buffer.count >= 5 {
            let startIndex = buffer.startIndex
            let flagByte = buffer[startIndex]
            let b1 = UInt32(buffer[startIndex + 1]) << 24
            let b2 = UInt32(buffer[startIndex + 2]) << 16
            let b3 = UInt32(buffer[startIndex + 3]) << 8
            let b4 = UInt32(buffer[startIndex + 4])
            let payloadLength = Int(b1 | b2 | b3 | b4)

            guard buffer.count >= 5 + payloadLength else {
                break
            }

            let payloadStart = startIndex + 5
            let payloadEnd = payloadStart + payloadLength
            let payload = Data(buffer[payloadStart..<payloadEnd])
            buffer.removeSubrange(startIndex..<payloadEnd)

            frames.append(
                ConnectEnvelopeFrame(
                    flags: ConnectEnvelopeFrame.Flags(rawValue: flagByte),
                    payload: payload
                )
            )
        }

        return frames
    }
}
