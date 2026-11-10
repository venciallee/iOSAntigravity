import Foundation

public enum AntigravityRPCError: Error, Sendable {
    case invalidEndpoint
    case httpError(statusCode: Int, body: String)
    case decodingError(String)
    case interactionRejected
}

/// Pure Swift 6 Connect-RPC & `/connect-websocket` client for `exa.language_server_pb.LanguageServerService`.
///
/// Connects either to:
/// 1. Official Antigravity Remote Control Relay (`https://antigravity.google.com/r/<instance-id>`)
/// 2. Direct LAN / Tailscale `language_server` (`https://<host>:<port>`) with `x-codeium-csrf-token`
public actor AntigravityRPCClient {
    public static let servicePrefix = "/exa.language_server_pb.LanguageServerService"

    private let host: RemoteHostInstance
    private let csrfToken: String?
    private let sessionCookie: String?
    private let urlSession: URLSession

    public init(
        host: RemoteHostInstance,
        csrfToken: String? = nil,
        sessionCookie: String? = nil,
        urlSession: URLSession = .shared
    ) {
        self.host = host
        self.csrfToken = csrfToken
        self.sessionCookie = sessionCookie
        self.urlSession = urlSession
    }

    // MARK: - Core Unary RPC (JSON & Binary Protobuf)

    public func callUnaryJSON(method: String, body: [String: Any]) async throws -> [String: Any] {
        let url = host.endpointURL.appendingPathComponent("\(Self.servicePrefix)/\(method)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        applyAuthHeaders(to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AntigravityRPCError.invalidEndpoint
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AntigravityRPCError.httpError(statusCode: http.statusCode, body: text)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AntigravityRPCError.decodingError("Expected JSON object from \(method)")
        }
        return json
    }

    /// Fetches trajectory steps using binary Protobuf (`application/proto`) to bypass the 600-step JSON ceiling.
    public func fetchTrajectoryStepsProtobuf(
        cascadeId: String,
        startIndex: Int,
        endIndex: Int
    ) async throws -> [CascadeStep] {
        let url = host.endpointURL.appendingPathComponent("\(Self.servicePrefix)/GetCascadeTrajectorySteps")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/proto", forHTTPHeaderField: "Content-Type")
        request.setValue("application/proto", forHTTPHeaderField: "Accept")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        applyAuthHeaders(to: &request)
        request.httpBody = ProtobufStepCodec.encodeGetStepsRequest(
            cascadeId: cascadeId,
            startIndex: startIndex,
            endIndex: endIndex
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AntigravityRPCError.httpError(statusCode: status, body: "Binary step fetch failed")
        }
        return ProtobufStepCodec.decodeStepsResponse(data, cascadeId: cascadeId)
    }

    // MARK: - High-Level Cascade & Jetbox Operations

    public func startCascade(workspaceUri: String, initialPrompt: String, modelId: String) async throws -> String {
        let res = try await callUnaryJSON(
            method: "StartCascade",
            body: [
                "workspaceUris": [workspaceUri],
                "initialUserInput": initialPrompt,
                "modelId": modelId
            ]
        )
        guard let cascadeId = res["cascadeId"] as? String else {
            throw AntigravityRPCError.decodingError("Missing cascadeId in StartCascade response")
        }
        return cascadeId
    }

    public func sendUserCascadeMessage(
        cascadeId: String,
        message: String,
        modelId: String,
        effort: ThinkingEffortLevel
    ) async throws {
        _ = try await callUnaryJSON(
            method: "SendUserCascadeMessage",
            body: [
                "cascadeId": cascadeId,
                "userResponse": message,
                "modelConfig": [
                    "modelId": modelId,
                    "thinkingEffort": effort.rawValue.uppercased()
                ]
            ]
        )
    }

    public func handleCascadeUserInteraction(
        step: CascadeStep,
        decision: InteractionDecision
    ) async throws {
        guard let interactionPayload = InteractionBuilder.buildPayload(step: step, decision: decision) else {
            throw AntigravityRPCError.interactionRejected
        }
        _ = try await callUnaryJSON(
            method: "HandleCascadeUserInteraction",
            body: ["interaction": interactionPayload]
        )
    }

    public func cancelCascadeInvocation(cascadeId: String) async throws {
        _ = try await callUnaryJSON(
            method: "CancelCascadeInvocation",
            body: ["cascadeId": cascadeId]
        )
    }

    // MARK: - Server-Streaming Envelope Subscription

    /// Subscribes to a Connect-RPC server-streaming method (`JetboxSubscribeToSummaries`, `StreamCascadeReactiveUpdates`, etc.)
    public func subscribeEnvelopeStream(
        method: String,
        requestJSON: [String: Any] = [:]
    ) throws -> AsyncThrowingStream<[String: Any], Error> {
        let url = host.endpointURL.appendingPathComponent("\(Self.servicePrefix)/\(method)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/connect+json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        applyAuthHeaders(to: &request)

        let rawJSON = try JSONSerialization.data(withJSONObject: requestJSON)
        request.httpBody = ConnectEnvelopeFrame(flags: [], payload: rawJSON).encode()

        let session = self.urlSession
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw AntigravityRPCError.invalidEndpoint
                    }
                    var parser = ConnectStreamParser()
                    var chunkBuffer = Data()
                    for try await byte in bytes {
                        chunkBuffer.append(byte)
                        if chunkBuffer.count >= 64 {
                            for frame in parser.feed(chunkBuffer) {
                                if frame.flags.contains(.endStream) {
                                    continuation.finish()
                                    return
                                }
                                if let obj = try? JSONSerialization.jsonObject(with: frame.payload) as? [String: Any] {
                                    continuation.yield(obj)
                                }
                            }
                            chunkBuffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !chunkBuffer.isEmpty {
                        for frame in parser.feed(chunkBuffer) where !frame.flags.contains(.endStream) {
                            if let obj = try? JSONSerialization.jsonObject(with: frame.payload) as? [String: Any] {
                                continuation.yield(obj)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func applyAuthHeaders(to request: inout URLRequest) {
        if let csrfToken, !csrfToken.isEmpty {
            request.setValue(csrfToken, forHTTPHeaderField: "x-codeium-csrf-token")
        }
        if let sessionCookie, !sessionCookie.isEmpty {
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        }
    }
}
