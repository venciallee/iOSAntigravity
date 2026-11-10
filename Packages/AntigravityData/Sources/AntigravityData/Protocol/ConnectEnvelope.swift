import Foundation

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
