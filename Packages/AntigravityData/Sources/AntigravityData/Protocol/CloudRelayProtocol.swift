import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Cloud Relay Instance Models (`devtools_jetski_boq_api_proto.ApiService/ListInstances`)

/// Connection lifecycle state reported by `ApiService/ListInstances` (JSPB field 3).
public enum RelayInstanceStatus: Int, Codable, Sendable, Equatable {
    case unknown = 0
    case connected = 1
    case disconnected = 2
    case idle = 3

    public init(rawStatusCode: Int) {
        self = RelayInstanceStatus(rawValue: rawStatusCode) ?? .unknown
    }

    public var isReachable: Bool {
        self == .connected || self == .idle
    }

    public var badgeText: String {
        switch self {
        case .connected: return "Online"
        case .idle: return "Idle"
        case .disconnected: return "Offline"
        case .unknown: return "Unknown"
        }
    }
}

/// Metadata for a Desktop or Cloud Antigravity instance registered on Google Cloud Relay.
public struct RelayInstanceInfo: Codable, Sendable, Equatable, Identifiable {
    public var id: String { uuid }
    public let uuid: String
    public let name: String
    public let version: String
    public let supportsChunking: Bool
    public let status: RelayInstanceStatus
    public let updatedAt: Date?

    public init(
        uuid: String,
        name: String,
        version: String = "v2.32.0",
        supportsChunking: Bool = true,
        status: RelayInstanceStatus = .connected,
        updatedAt: Date? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.version = version
        self.supportsChunking = supportsChunking
        self.status = status
        self.updatedAt = updatedAt
    }

    /// Matches either the full relay UUID (`0f5819ac-9308-40d8-a308-98b55122c533-v2`),
    /// human-readable device slug (`lt74xt6l0m-golden-star`), or UUID prefix.
    public func matches(identifier rawIdentifier: String) -> Bool {
        let needle = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return false }
        let uuidLower = uuid.lowercased()
        let nameLower = name.lowercased()
        if uuidLower == needle || nameLower == needle {
            return true
        }
        if needle.count >= 8 && (uuidLower.hasPrefix(needle) || nameLower.hasPrefix(needle)) {
            return true
        }
        return false
    }
}

// MARK: - Google SAPISIDHASH & ApiService Header Builder

/// Computes Google `SAPISIDHASH` / `SAPISID1PHASH` / `SAPISID3PHASH` authorization headers
/// and attaches required `devtools_jetski_boq_api_proto.ApiService` gRPC-Web / JSPB headers.
public enum SAPISIDHashGenerator: Sendable {
    public static let defaultOrigin = "https://antigravity.google.com"
    public static let apiServicePrefix = "/$rpc/devtools_jetski_boq_api_proto.ApiService"
    public static let publicWebApiKey = "AIzaSyCUicsvglkMf8CM2MPlGjopIcIxu3VJEDU"
    public static let antigravityTestHeaderName = "x-antigravity-test-72e4dd1c-e8ae-4e97-873b-c3d3a01b735d"
    public static let mobileRemoteUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Antigravity-iOS/2.0"

    /// Parses a semicolon-delimited HTTP `Cookie` header into `[name: value]`.
    public static func parseCookies(_ rawCookieHeader: String) -> [String: String] {
        var result: [String: String] = [:]
        var cleaned = rawCookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasPrefix("cookie:") {
            cleaned = String(cleaned.dropFirst("cookie:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for part in cleaned.split(separator: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let eqIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<eqIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty && !value.isEmpty {
                result[key] = value
            }
        }
        return result
    }

    /// Returns `true` when the cookie string or token contains valid Google session credentials
    /// (`SAPISID` / `__Secure-1PAPISID` / `__Secure-3PAPISID`, or an OAuth `Bearer` token).
    public static func hasRequiredGoogleAuthCookies(_ rawCookieOrToken: String) -> Bool {
        let trimmed = rawCookieOrToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("bearer ") || trimmed.hasPrefix("ya29.") {
            return true
        }
        let cookies = parseCookies(trimmed)
        let hasApiSid = cookies["SAPISID"] != nil
            || cookies["__Secure-1PAPISID"] != nil
            || cookies["__Secure-3PAPISID"] != nil
        let hasSid = cookies["SID"] != nil
            || cookies["__Secure-1PSID"] != nil
            || cookies["__Secure-3PSID"] != nil
        return hasApiSid && (hasSid || cookies.count >= 1)
    }

    /// Computes the `Authorization` header value (`SAPISIDHASH <ts>_<sha1> SAPISID1PHASH ... SAPISID3PHASH ...`).
    public static func computeAuthorizationHeader(
        cookieHeader: String,
        origin: String = defaultOrigin,
        timestamp: Int = Int(Date().timeIntervalSince1970)
    ) -> String? {
        let trimmed = cookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("bearer ") {
            return trimmed
        }
        if trimmed.hasPrefix("ya29.") && !trimmed.contains("=") {
            return "Bearer \(trimmed)"
        }

        let normalizedOrigin = normalizeOrigin(origin)
        let cookies = parseCookies(trimmed)
        var schemes: [String] = []

        if let sapisid = cookies["SAPISID"], !sapisid.isEmpty {
            let digest = sha1Hex("\(timestamp) \(sapisid) \(normalizedOrigin)")
            schemes.append("SAPISIDHASH \(timestamp)_\(digest)")
        }
        if let p1 = cookies["__Secure-1PAPISID"], !p1.isEmpty {
            let digest = sha1Hex("\(timestamp) \(p1) \(normalizedOrigin)")
            schemes.append("SAPISID1PHASH \(timestamp)_\(digest)")
        }
        if let p3 = cookies["__Secure-3PAPISID"], !p3.isEmpty {
            let digest = sha1Hex("\(timestamp) \(p3) \(normalizedOrigin)")
            schemes.append("SAPISID3PHASH \(timestamp)_\(digest)")
        }

        return schemes.isEmpty ? nil : schemes.joined(separator: " ")
    }

    /// Attaches all Google Boq `ApiService` JSPB request headers to `request`.
    public static func applyApiServiceHeaders(
        to request: inout URLRequest,
        cookieHeader: String,
        origin: String = defaultOrigin,
        authUser: String = "0",
        isStreaming: Bool? = nil,
        timestamp: Int = Int(Date().timeIntervalSince1970)
    ) {
        let normalizedOrigin = normalizeOrigin(origin)
        request.setValue("application/json+protobuf", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("grpc-web-javascript/0.1", forHTTPHeaderField: "X-User-Agent")
        request.setValue(publicWebApiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(authUser.isEmpty ? "0" : authUser, forHTTPHeaderField: "X-Goog-AuthUser")
        if isStreaming != true {
            request.setValue("base64", forHTTPHeaderField: "X-Goog-Encode-Response-If-Executable")
        }
        request.setValue(normalizedOrigin, forHTTPHeaderField: "Origin")
        request.setValue(normalizedOrigin, forHTTPHeaderField: "X-Origin")
        request.setValue("\(normalizedOrigin)/", forHTTPHeaderField: "Referer")
        request.setValue("true", forHTTPHeaderField: antigravityTestHeaderName)
        if let isStreaming {
            request.setValue(isStreaming ? "true" : "false", forHTTPHeaderField: "x-is-streaming")
        }

        var cleanedCookie = cookieHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedCookie.lowercased().hasPrefix("cookie:") {
            cleanedCookie = String(cleanedCookie.dropFirst("cookie:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !cleanedCookie.isEmpty && !cleanedCookie.lowercased().hasPrefix("bearer ") && !cleanedCookie.hasPrefix("ya29.") {
            request.setValue(cleanedCookie, forHTTPHeaderField: "Cookie")
        }
        if let auth = computeAuthorizationHeader(
            cookieHeader: cleanedCookie,
            origin: normalizedOrigin,
            timestamp: timestamp
        ) {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }
    }

    public static func normalizeOrigin(_ rawOrigin: String) -> String {
        let trimmed = rawOrigin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed),
              let scheme = comps.scheme?.lowercased(),
              let host = comps.host?.lowercased() else {
            return defaultOrigin
        }
        if let port = comps.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    /// Computes lowercase hex SHA-1 digest using `CryptoKit` when available, with a pure-Swift fallback.
    public static func sha1Hex(_ string: String) -> String {
        let bytes = Array(string.utf8)
        #if canImport(CryptoKit)
        let digest = Insecure.SHA1.hash(data: bytes)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return pureSwiftSHA1Hex(bytes)
        #endif
    }

    /// Pure-Swift FIPS 180-4 SHA-1 implementation for cross-platform determinism.
    public static func pureSwiftSHA1Hex(_ message: [UInt8]) -> String {
        var bytes = message
        let bitLength = UInt64(bytes.count) * 8
        bytes.append(0x80)
        while (bytes.count % 64) != 56 {
            bytes.append(0x00)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8((bitLength >> UInt64(shift)) & 0xff))
        }

        var h0: UInt32 = 0x67452301
        var h1: UInt32 = 0xefcdab89
        var h2: UInt32 = 0x98badcfe
        var h3: UInt32 = 0x10325476
        var h4: UInt32 = 0xc3d2e1f0

        @inline(__always)
        func rotl(_ value: UInt32, _ bits: UInt32) -> UInt32 {
            (value << bits) | (value >> (32 - bits))
        }

        var w = [UInt32](repeating: 0, count: 80)
        for chunkStart in stride(from: 0, to: bytes.count, by: 64) {
            for i in 0..<16 {
                let offset = chunkStart + i * 4
                w[i] = (UInt32(bytes[offset]) << 24)
                    | (UInt32(bytes[offset + 1]) << 16)
                    | (UInt32(bytes[offset + 2]) << 8)
                    | UInt32(bytes[offset + 3])
            }
            for i in 16..<80 {
                w[i] = rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1)
            }

            var a = h0
            var b = h1
            var c = h2
            var d = h3
            var e = h4

            for i in 0..<80 {
                let f: UInt32
                let k: UInt32
                switch i {
                case 0..<20:
                    f = (b & c) | ((~b) & d)
                    k = 0x5a827999
                case 20..<40:
                    f = b ^ c ^ d
                    k = 0x6ed9eba1
                case 40..<60:
                    f = (b & c) | (b & d) | (c & d)
                    k = 0x8f1bbcdc
                default:
                    f = b ^ c ^ d
                    k = 0xca62c1d6
                }
                let temp = rotl(a, 5) &+ f &+ e &+ k &+ w[i]
                e = d
                d = c
                c = rotl(b, 30)
                b = a
                a = temp
            }

            h0 = h0 &+ a
            h1 = h1 &+ b
            h2 = h2 &+ c
            h3 = h3 &+ d
            h4 = h4 &+ e
        }

        return String(format: "%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4)
    }
}

// MARK: - JSPB (`application/json+protobuf`) Codec for `ApiService`

/// Encodes and decodes Google JSPB (`application/json+protobuf`) arrays for
/// `ListInstances`, `ProxyCommand`, and `StreamProxyCommand`.
public enum CloudRelayJSPBCodec: Sendable {

    /// Flexible Base64 / Base64URL decoder handling missing `=` padding and whitespace.
    public static func decodeBase64Flexible(_ raw: String) -> Data? {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if cleaned.isEmpty {
            return Data()
        }
        let remainder = cleaned.count % 4
        let padded = remainder == 0
            ? cleaned
            : cleaned + String(repeating: "=", count: 4 - remainder)
        return Data(base64Encoded: padded, options: [.ignoreUnknownCharacters])
    }

    /// Unwraps `X-Goog-Safety-Encoding: base64` / `Content-Transfer-Encoding: base64`
    /// and Google XSSI prefix (`)]}'\n`) when present.
    public static func unwrapGoogleRPCBody(
        _ rawData: Data,
        responseHeaders: [AnyHashable: Any] = [:]
    ) -> Data {
        var data = rawData
        let isBase64Header = responseHeaders.contains { key, val in
            let lowerKey = String(describing: key).lowercased()
            guard lowerKey == "x-goog-safety-encoding" || lowerKey == "content-transfer-encoding" else {
                return false
            }
            return String(describing: val).lowercased().contains("base64")
        }

        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let firstChar = trimmed.first,
               firstChar != "[" && firstChar != "{" && firstChar != ")",
               let decoded = decodeBase64Flexible(trimmed),
               let decodedText = String(data: decoded, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               (isBase64Header || decodedText.hasPrefix("[") || decodedText.hasPrefix(")]}'")) {
                data = decoded
            }
        }

        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix(")]}'") {
                let afterPrefix = trimmed.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines)
                return Data(afterPrefix.utf8)
            }
        }
        return data
    }

    /// Encodes `ListInstancesRequest` (`[]`).
    public static func encodeListInstancesRequest() -> Data {
        Data("[]".utf8)
    }

    /// Decodes `ListInstancesResponse` JSPB array:
    /// `[ [ [uuid, [name, version, supportsChunking], statusInt, [seconds, nanos]], ... ], maxConnected ]`
    public static func decodeListInstancesResponse(
        _ rawData: Data,
        responseHeaders: [AnyHashable: Any] = [:]
    ) throws -> [RelayInstanceInfo] {
        let unwrapped = unwrapGoogleRPCBody(rawData, responseHeaders: responseHeaders)
        if unwrapped.isEmpty {
            return []
        }
        let rootValue = try JSONDecoder().decode(JSONValue.self, from: unwrapped)
        guard let rootArray = rootValue.arrayValue else {
            throw AntigravityRPCError.decodingError("Expected JSPB array from ListInstances")
        }
        guard let rawInstances = rootArray.first?.arrayValue else {
            return []
        }

        return rawInstances.compactMap { item -> RelayInstanceInfo? in
            guard let row = item.arrayValue,
                  let uuid = row.first?.stringValue,
                  !uuid.isEmpty else {
                return nil
            }
            let metadataArr = row.count > 1 ? row[1].arrayValue : nil
            let rawName = metadataArr?.first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (rawName?.isEmpty == false) ? rawName! : uuid
            let version = (metadataArr != nil && metadataArr!.count > 1 ? metadataArr![1].stringValue : nil) ?? "v2.32.0"
            let supportsChunking: Bool = {
                guard let metadataArr, metadataArr.count > 2 else { return true }
                if let b = metadataArr[2].boolValue { return b }
                if let i = metadataArr[2].intValue { return i != 0 }
                return true
            }()

            let statusCode = row.count > 2 ? (row[2].intValue ?? 0) : 1
            let status = RelayInstanceStatus(rawStatusCode: statusCode)

            var updatedAt: Date? = nil
            if row.count > 3, let tsArr = row[3].arrayValue, !tsArr.isEmpty {
                let secs = tsArr[0].doubleValue ?? Double(tsArr[0].stringValue ?? "")
                let nanos = tsArr.count > 1 ? (tsArr[1].doubleValue ?? Double(tsArr[1].stringValue ?? "") ?? 0) : 0
                if let secs, secs > 0 {
                    updatedAt = Date(timeIntervalSince1970: secs + nanos / 1_000_000_000.0)
                }
            }

            return RelayInstanceInfo(
                uuid: uuid,
                name: name,
                version: version,
                supportsChunking: supportsChunking,
                status: status,
                updatedAt: updatedAt
            )
        }
    }

    /// Encodes `ProxyCommandRequest` JSPB 4-tuple:
    /// `[ targetInstanceUuid, rpcPath, base64Payload, [ [headerKey, headerVal], ... ] ]`
    public static func encodeProxyCommandRequest(
        targetInstanceUuid: String,
        rpcPath: String,
        payload: Data,
        contentType: String = "application/json",
        isStreaming: Bool = false,
        remoteUserAgent: String = SAPISIDHashGenerator.mobileRemoteUserAgent
    ) throws -> Data {
        let base64Payload = payload.isEmpty ? "" : payload.base64EncodedString()
        let headerPairs: [[String]] = [
            ["x-is-streaming", isStreaming ? "true" : "false"],
            ["x-jetski-remote-control-user-agent", remoteUserAgent],
            ["content-type", contentType],
            ["connect-protocol-version", "1"]
        ]
        let jspb: JSONValue = .array([
            .string(targetInstanceUuid),
            .string(rpcPath),
            .string(base64Payload),
            .array(headerPairs.map { pair in .array(pair.map(JSONValue.string)) })
        ])
        return try JSONEncoder().encode(jspb)
    }

    /// Decodes `ProxyCommandResponse` JSPB tuple:
    /// `[ "<base64ResponseBytes>", [ ["accept-encoding", "gzip"], ["content-type", "application/json"] ] ]`
    public static func decodeProxyCommandResponse(
        _ rawData: Data,
        responseHeaders: [AnyHashable: Any] = [:]
    ) throws -> (payload: Data, headers: [String: String]) {
        let unwrapped = unwrapGoogleRPCBody(rawData, responseHeaders: responseHeaders)
        if unwrapped.isEmpty {
            return (Data(), [:])
        }
        let rootValue = try JSONDecoder().decode(JSONValue.self, from: unwrapped)
        guard let rootArray = rootValue.arrayValue else {
            throw AntigravityRPCError.decodingError("Expected JSPB array in ProxyCommandResponse")
        }

        // Check if Boq returned a nested `[responseArray, errorTrailer]` wrapper when payload is absent
        if rootArray.first == .null, rootArray.count >= 2 {
            let errSummary = String(data: unwrapped, encoding: .utf8) ?? "Cloud Relay RPC error"
            throw AntigravityRPCError.httpError(statusCode: 502, body: errSummary)
        }

        let b64Payload = rootArray.first?.stringValue ?? ""
        guard let decodedPayload = decodeBase64Flexible(b64Payload) else {
            throw AntigravityRPCError.decodingError("Invalid base64 payload in ProxyCommandResponse")
        }

        var innerHeaders: [String: String] = [:]
        if rootArray.count > 1, let pairs = rootArray[1].arrayValue {
            for pairVal in pairs {
                if let pair = pairVal.arrayValue,
                   pair.count >= 2,
                   let k = pair[0].stringValue?.lowercased(),
                   let v = pair[1].stringValue {
                    innerHeaders[k] = v
                }
            }
        }

        return (decodedPayload, innerHeaders)
    }

    /// Extracts base64 payload chunks from a `StreamProxyCommand` JSPB response buffer.
    public static func extractStreamProxyPayloads(from rawText: String) -> [Data] {
        let cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }
        let stripped: String
        if cleaned.hasPrefix(")]}'") {
            stripped = String(cleaned.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            stripped = cleaned
        }
        guard let data = stripped.data(using: .utf8) else { return [] }
        if let root = try? JSONDecoder().decode(JSONValue.self, from: data),
           let arr = root.arrayValue {
            return extractPayloadsFromJSPBArray(arr)
        }
        if let decodedB64 = decodeBase64Flexible(stripped),
           let text = String(data: decodedB64, encoding: .utf8),
           text != stripped {
            return extractStreamProxyPayloads(from: text)
        }
        return []
    }

    fileprivate static func extractPayloadsFromJSPBArray(_ arr: [JSONValue]) -> [Data] {
        var payloads: [Data] = []
        func walk(_ node: [JSONValue]) {
            if let firstStr = node.first?.stringValue,
               node.count <= 3,
               (node.count == 1 || node[1].arrayValue != nil || node[1] == .null) {
                if !firstStr.isEmpty, let bytes = decodeBase64Flexible(firstStr), !bytes.isEmpty {
                    payloads.append(bytes)
                }
                return
            }
            for child in node {
                if let childArr = child.arrayValue {
                    walk(childArr)
                }
            }
        }
        walk(arr)
        return payloads
    }
}

/// Incremental byte-level parser for Google Boq `StreamProxyCommand` JSPB streams.
/// Emits decoded inner payload bytes as soon as each top-level `[...]` JSPB array closes,
/// without waiting for trailing `\n` delimiters on infinite server streams.
public struct CloudRelayJSPBStreamParser: Sendable {
    private var currentArrayBytes: [UInt8] = []
    private var depth: Int = 0
    private var inString: Bool = false
    private var isEscaped: Bool = false

    public init() {}

    public mutating func feed(_ bytes: Data) -> [Data] {
        var emitted: [Data] = []
        for byte in bytes {
            if let chunks = feedByte(byte) {
                emitted.append(contentsOf: chunks)
            }
        }
        return emitted
    }

    public mutating func feedByte(_ byte: UInt8) -> [Data]? {
        if depth == 0 {
            if byte == UInt8(ascii: "[") {
                depth = 1
                inString = false
                isEscaped = false
                currentArrayBytes.removeAll(keepingCapacity: true)
                currentArrayBytes.append(byte)
            }
            return nil
        }

        currentArrayBytes.append(byte)

        if inString {
            if isEscaped {
                isEscaped = false
            } else if byte == UInt8(ascii: "\\") {
                isEscaped = true
            } else if byte == UInt8(ascii: "\"") {
                inString = false
            }
            return nil
        }

        if byte == UInt8(ascii: "\"") {
            inString = true
        } else if byte == UInt8(ascii: "[") {
            depth += 1
        } else if byte == UInt8(ascii: "]") {
            depth -= 1
            if depth == 0 {
                let completedData = Data(currentArrayBytes)
                currentArrayBytes.removeAll(keepingCapacity: true)
                if let root = try? JSONDecoder().decode(JSONValue.self, from: completedData),
                   let arr = root.arrayValue {
                    let extracted = CloudRelayJSPBCodec.extractPayloadsFromJSPBArray(arr)
                    if !extracted.isEmpty {
                        return extracted
                    }
                }
            }
        }
        return nil
    }
}
