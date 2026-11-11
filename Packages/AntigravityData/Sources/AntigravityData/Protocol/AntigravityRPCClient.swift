import Foundation
#if canImport(Security)
import Security
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum AntigravityRPCError: Error, Sendable, Equatable {
    case invalidEndpoint
    case unauthorized(String)
    case httpError(statusCode: Int, body: String)
    case decodingError(String)
    case interactionRejected
}

/// Handshake telemetry returned by `AntigravityRPCClient.verifyConnection()`.
public struct BackendHandshakeResult: Sendable, Equatable {
    public let latencyMs: Int
    public let workspaces: [WorkspaceInfo]
    public let summaries: [CascadeSummary]
    public let serverVersion: String

    public init(
        latencyMs: Int,
        workspaces: [WorkspaceInfo],
        summaries: [CascadeSummary],
        serverVersion: String = "v2.32.0"
    ) {
        self.latencyMs = latencyMs
        self.workspaces = workspaces
        self.summaries = summaries
        self.serverVersion = serverVersion
    }
}

/// URLSession TLS delegate supporting SHA-256 certificate pinning and local LAN / Tailscale TOFU
/// for Antigravity Desktop's dynamically generated self-signed `language_server` HTTPS certificate.
public final class PinnedTLSURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let pinnedFingerprintHex: String?
    private let allowLocalSelfSignedTOFU: Bool

    public init(pinnedFingerprintSHA256: String? = nil, allowLocalSelfSignedTOFU: Bool = true) {
        self.pinnedFingerprintHex = pinnedFingerprintSHA256?
            .replacingOccurrences(of: "SHA256:", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        self.allowLocalSelfSignedTOFU = allowLocalSelfSignedTOFU
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        #if canImport(Security)
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()
        if let expectedHex = pinnedFingerprintHex, !expectedHex.isEmpty {
            if let certChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
               let leaf = certChain.first {
                let derData = SecCertificateCopyData(leaf) as Data
                #if canImport(CryptoKit)
                let digest = SHA256.hash(data: derData)
                let actualHex = digest.map { String(format: "%02x", $0) }.joined()
                if actualHex.hasPrefix(expectedHex) || expectedHex.hasPrefix(actualHex) {
                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
                    return
                }
                #endif
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let isPrivateOrTailscaleHost =
            host == "localhost" ||
            host == "127.0.0.1" ||
            host.hasSuffix(".local") ||
            host.hasSuffix(".ts.net") ||
            host.hasPrefix("192.168.") ||
            host.hasPrefix("10.") ||
            host.hasPrefix("100.") ||
            host.hasPrefix("172.")

        if allowLocalSelfSignedTOFU && isPrivateOrTailscaleHost {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        #endif
        completionHandler(.performDefaultHandling, nil)
    }
}

/// Pure Swift 6 Connect-RPC & `/connect-websocket` client for `exa.language_server_pb.LanguageServerService`.
///
/// Connects either to:
/// 1. Official Antigravity Remote Control Relay (`https://antigravity.google.com/r/<instance-id>`)
/// 2. Direct LAN / Tailscale `language_server` or Mac Companion Bridge (`https://<host>:<port>`) with `x-codeium-csrf-token`
public actor AntigravityRPCClient {
    public static let servicePrefix = "/exa.language_server_pb.LanguageServerService"
    public static let protobufStepThreshold = 600

    private let endpointURL: URL
    private let csrfToken: String?
    private let sessionCookie: String?
    private let urlSession: URLSession

    public init(
        host: RemoteHostInstance,
        csrfToken: String? = nil,
        sessionCookie: String? = nil,
        pinnedFingerprintSHA256: String? = nil,
        urlSession: URLSession? = nil
    ) {
        self.endpointURL = host.endpointURL
        self.csrfToken = csrfToken
        self.sessionCookie = sessionCookie
        if let urlSession {
            self.urlSession = urlSession
        } else {
            self.urlSession = Self.makeDefaultURLSession(
                for: host.endpointURL,
                pinnedFingerprintSHA256: pinnedFingerprintSHA256,
                allowLocalSelfSignedTOFU: host.channel == .directHost
            )
        }
    }

    public init(
        baseURL: URL,
        csrfToken: String? = nil,
        sessionCookie: String? = nil,
        pinnedFingerprintSHA256: String? = nil,
        urlSession: URLSession? = nil
    ) {
        self.endpointURL = baseURL
        self.csrfToken = csrfToken
        self.sessionCookie = sessionCookie
        if let urlSession {
            self.urlSession = urlSession
        } else {
            self.urlSession = Self.makeDefaultURLSession(
                for: baseURL,
                pinnedFingerprintSHA256: pinnedFingerprintSHA256,
                allowLocalSelfSignedTOFU: true
            )
        }
    }

    nonisolated private static func makeDefaultURLSession(
        for endpointURL: URL,
        pinnedFingerprintSHA256: String?,
        allowLocalSelfSignedTOFU: Bool
    ) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 300
        let host = (endpointURL.host ?? "").lowercased()
        let isLocalOrPrivateHost =
            host == "localhost" ||
            host == "127.0.0.1" ||
            host == "::1" ||
            host.hasSuffix(".local") ||
            host.hasSuffix(".ts.net") ||
            host.hasPrefix("192.168.") ||
            host.hasPrefix("10.") ||
            host.hasPrefix("100.") ||
            host.hasPrefix("172.")
        if isLocalOrPrivateHost {
            config.connectionProxyDictionary = [:]
        }
        let delegate = PinnedTLSURLSessionDelegate(
            pinnedFingerprintSHA256: pinnedFingerprintSHA256,
            allowLocalSelfSignedTOFU: allowLocalSelfSignedTOFU
        )
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    // MARK: - Handshake & Login Verification

    /// Verifies authentication (`x-codeium-csrf-token` or Google session cookie) and hydrates initial state.
    public func verifyConnection(timeoutInterval: TimeInterval = 4.0) async throws -> BackendHandshakeResult {
        let start = Date()
        async let workspacesTask = getWorkspaceInfosOptional(timeoutInterval: timeoutInterval)
        async let summariesTask = getAllCascadeTrajectories(timeoutInterval: timeoutInterval)
        let workspaces = try await workspacesTask
        let summaries = try await summariesTask
        let elapsedMs = max(1, Int(Date().timeIntervalSince(start) * 1000.0))
        return BackendHandshakeResult(
            latencyMs: elapsedMs,
            workspaces: workspaces,
            summaries: summaries
        )
    }

    private func getWorkspaceInfosOptional(timeoutInterval: TimeInterval?) async throws -> [WorkspaceInfo] {
        do {
            return try await getWorkspaceInfos(timeoutInterval: timeoutInterval)
        } catch let AntigravityRPCError.httpError(statusCode, _) where statusCode == 404 {
            return []
        }
    }

    // MARK: - Core Unary RPC (`Sendable` JSONValue & Binary Protobuf)

    public func callUnaryJSON(
        method: String,
        body: [String: JSONValue] = [:],
        timeoutInterval: TimeInterval? = nil
    ) async throws -> [String: JSONValue] {
        let url = endpointURL.appendingPathComponent("\(Self.servicePrefix)/\(method)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }
        applyAuthHeaders(to: &request)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AntigravityRPCError.invalidEndpoint
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            let text = String(data: data, encoding: .utf8) ?? "Unauthorized"
            throw AntigravityRPCError.unauthorized(text)
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AntigravityRPCError.httpError(statusCode: http.statusCode, body: text)
        }
        if data.isEmpty {
            return [:]
        }
        guard let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            throw AntigravityRPCError.decodingError("Expected JSON object from \(method)")
        }
        return decoded
    }

    /// Fetches trajectory steps, automatically switching from JSON (`0..<600`) to Binary Protobuf (`>=600`).
    public func fetchTrajectorySteps(
        cascadeId: String,
        startIndex: Int = 0,
        endIndex: Int = 200
    ) async throws -> [CascadeStep] {
        if endIndex >= Self.protobufStepThreshold {
            return try await fetchTrajectoryStepsProtobuf(
                cascadeId: cascadeId,
                startIndex: startIndex,
                endIndex: endIndex
            )
        }
        return try await fetchTrajectoryStepsJSON(
            cascadeId: cascadeId,
            startIndex: startIndex,
            endIndex: endIndex
        )
    }

    /// Fetches the complete trajectory for a live session in safe 50-step JSON batches
    /// (avoiding `language_server` wrap-around / truncation on large `endIndex` ranges)
    /// and switches to Binary Protobuf (`application/proto`) when `knownStepCount >= 600`.
    public func fetchAllTrajectorySteps(
        cascadeId: String,
        knownStepCount: Int = 0
    ) async throws -> [CascadeStep] {
        if knownStepCount >= Self.protobufStepThreshold {
            return try await fetchTrajectoryStepsProtobuf(
                cascadeId: cascadeId,
                startIndex: 0,
                endIndex: knownStepCount
            )
        }

        let batchSize = 50
        let maxTarget = max(batchSize, min(Self.protobufStepThreshold, knownStepCount + batchSize))
        var offset = 0
        var seenIndices = Set<Int>()
        var collected: [CascadeStep] = []

        while offset < maxTarget {
            let batchEnd = offset + batchSize
            let res = try await callUnaryJSON(
                method: "GetCascadeTrajectorySteps",
                body: [
                    "cascadeId": .string(cascadeId),
                    "startIndex": .int(offset),
                    "endIndex": .int(batchEnd)
                ]
            )
            guard let rawSteps = res["steps"]?.arrayValue, !rawSteps.isEmpty else {
                break
            }
            var addedNewStep = false
            for (idxOffset, item) in rawSteps.enumerated() {
                if let step = Self.decodeJSONStep(item, cascadeId: cascadeId, fallbackIndex: offset + idxOffset) {
                    if seenIndices.insert(step.stepIndex).inserted {
                        collected.append(step)
                        addedNewStep = true
                    }
                }
            }
            if rawSteps.count < batchSize || !addedNewStep {
                break
            }
            offset += rawSteps.count
        }

        return collected.sorted { $0.stepIndex < $1.stepIndex }
    }

    /// Fetches trajectory steps over JSON (`GetCascadeTrajectorySteps`) for conversations under 600 steps.
    /// Supports both native Desktop `language_server` step JSON and companion/mock step schemas.
    public func fetchTrajectoryStepsJSON(
        cascadeId: String,
        startIndex: Int = 0,
        endIndex: Int = 200
    ) async throws -> [CascadeStep] {
        let res = try await callUnaryJSON(
            method: "GetCascadeTrajectorySteps",
            body: [
                "cascadeId": .string(cascadeId),
                "startIndex": .int(startIndex),
                "endIndex": .int(endIndex)
            ]
        )
        guard let rawSteps = res["steps"]?.arrayValue else { return [] }
        return rawSteps.enumerated().compactMap { offset, item in
            Self.decodeJSONStep(item, cascadeId: cascadeId, fallbackIndex: startIndex + offset)
        }
    }

    /// Fetches trajectory steps using binary Protobuf (`application/proto`) to bypass the 600-step JSON ceiling.
    public func fetchTrajectoryStepsProtobuf(
        cascadeId: String,
        startIndex: Int,
        endIndex: Int
    ) async throws -> [CascadeStep] {
        let url = endpointURL.appendingPathComponent("\(Self.servicePrefix)/GetCascadeTrajectorySteps")
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

    // MARK: - Workspace & Project Operations (`UE01`, `UE04`, `UE05`)

    public func getWorkspaceInfos(timeoutInterval: TimeInterval? = nil) async throws -> [WorkspaceInfo] {
        let res = try await callUnaryJSON(method: "GetWorkspaceInfos", timeoutInterval: timeoutInterval)
        let items = res["workspaces"]?.arrayValue ?? res["workspaceInfos"]?.arrayValue ?? []
        return items.compactMap { item -> WorkspaceInfo? in
            guard let obj = item.objectValue else { return nil }
            guard let rawUri = obj["workspaceUri"]?.stringValue
                ?? obj["workspaceFolderAbsoluteUri"]?.stringValue else { return nil }
            let decodedRaw = (rawUri.removingPercentEncoding ?? rawUri).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if decodedRaw == "file:///home/antigravity" {
                return nil
            }
            let sourceHint = [obj["runtime"]?.stringValue, obj["source"]?.stringValue]
                .compactMap { $0 }
                .joined(separator: " ")
            let isCloud = (obj["isCloud"]?.boolValue ?? false)
                || AntigravityCloudDetector.isCloudWorkspaceURI(rawUri, sourceHint: sourceHint)
            let uri = AntigravityCloudDetector.normalizeWorkspaceURI(rawUri, isCloud: isCloud)
            let fallbackName: String
            if uri.hasPrefix("cloud://") {
                let tail = uri.replacingOccurrences(of: "cloud://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                fallbackName = (tail as NSString).lastPathComponent.isEmpty ? tail : (tail as NSString).lastPathComponent
            } else if uri.contains("://"), let parsedURL = URL(string: uri), !parsedURL.lastPathComponent.isEmpty {
                fallbackName = parsedURL.lastPathComponent
            } else {
                fallbackName = (uri.replacingOccurrences(of: "file://", with: "") as NSString).lastPathComponent
            }
            let name = obj["displayName"]?.stringValue ?? fallbackName
            let branch = obj["activeBranch"]?.stringValue ?? obj["gitBranch"]?.stringValue ?? "main"
            let files = obj["indexedFiles"]?.arrayValue?.compactMap(\.stringValue) ?? []
            return WorkspaceInfo(
                workspaceUri: uri,
                displayName: name,
                activeBranch: branch,
                indexedFiles: files,
                isCloud: isCloud
            )
        }
    }

    public func createProjectWorkspace(draft: NewProjectDraft) async throws -> ProjectWorkspace {
        let repoName = draft.selectedRepo?.fullName ?? draft.projectName
        let res = try await callUnaryJSON(
            method: "CreateProjectWorkspace",
            body: [
                "name": .string(draft.projectName),
                "runtime": .string(draft.runsOn.rawValue),
                "source": .string(draft.source.rawValue),
                "repository": .string(repoName),
                "branchWorktree": .string(draft.branchWorktree)
            ]
        )
        let workspaceUri = res["workspaceUri"]?.stringValue
            ?? (draft.runsOn == .cloud ? "cloud://\(repoName)" : "file:///Users/wl/code/\(draft.projectName)")
        return ProjectWorkspace(
            id: draft.projectName,
            name: draft.projectName,
            pathDisplay: draft.runsOn == .cloud ? "cloud://\(repoName)" : "~/code/\(draft.projectName)",
            workspaceUri: workspaceUri,
            runtime: draft.runsOn,
            hostName: draft.runsOn.rawValue,
            activeBranch: draft.selectedRepo?.defaultBranch ?? "main"
        )
    }

    public func openWorkspaceInFinder(workspaceUri: String) async throws {
        _ = try await callUnaryJSON(
            method: "OpenWorkspaceInFinder",
            body: ["workspaceUri": .string(workspaceUri)]
        )
    }

    // MARK: - Conversation & Trajectory Operations (`UE01`, `UE03`, `UE07`)

    /// Fetches all sessions from either Desktop `language_server` (`trajectorySummaries` map)
    /// or Companion/Mock (`trajectories` array).
    public func getAllCascadeTrajectories(timeoutInterval: TimeInterval? = nil) async throws -> [CascadeSummary] {
        let res = try await callUnaryJSON(method: "GetAllCascadeTrajectories", timeoutInterval: timeoutInterval)
        let now = Date()

        // Format A: Native Desktop `language_server` map `{"trajectorySummaries": {"<cascadeId>": {...}}}`
        if let summaryMap = res["trajectorySummaries"]?.objectValue {
            let decoded = summaryMap.compactMap { cascadeId, value in
                Self.decodeTrajectorySummaryEntry(cascadeId: cascadeId, value: value, now: now)
            }
            return decoded.sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.cascadeId < rhs.cascadeId
            }
        }

        // Format B: Array `{"trajectories": [...]}`
        guard let list = res["trajectories"]?.arrayValue else { return [] }
        return list.compactMap { item -> CascadeSummary? in
            guard let obj = item.objectValue,
                  let id = obj["cascadeId"]?.stringValue,
                  let title = obj["title"]?.stringValue else { return nil }
            let rawUri = obj["workspaceUri"]?.stringValue ?? "file:///Users/wl/code/ledger-svc"
            let sourceHint = [obj["runtime"]?.stringValue, obj["source"]?.stringValue]
                .compactMap { $0 }
                .joined(separator: " ")
            let isCloud = (obj["isCloud"]?.boolValue ?? false)
                || AntigravityCloudDetector.isCloudWorkspaceURI(rawUri, cascadeId: id, sourceHint: sourceHint)
            let uri = AntigravityCloudDetector.normalizeWorkspaceURI(rawUri, isCloud: isCloud)
            let slug = obj["projectSlug"]?.stringValue ?? (rawUri as NSString).lastPathComponent
            let statusName = obj["status"]?.stringValue ?? "CORTEX_STEP_STATUS_DONE"
            let stepCount = obj["stepCount"]?.intValue ?? 0
            let branch = obj["branchName"]?.stringValue ?? "main"
            let subtitle = obj["statusSubtitle"]?.stringValue ?? ""
            let updatedAt = Self.parseProtoTimestamp(obj["updatedAt"] ?? obj["lastModifiedTime"]) ?? now
            let relativeLabel = obj["relativeTimeLabel"]?.stringValue ?? Self.formatRelativeTimeLabel(from: updatedAt, now: now)
            return CascadeSummary(
                cascadeId: id,
                title: title,
                projectSlug: slug,
                workspaceUri: uri,
                branchName: branch,
                status: CortexStepStatus.from(jsonName: statusName),
                stepCount: stepCount,
                updatedAt: updatedAt,
                relativeTimeLabel: relativeLabel,
                statusSubtitle: subtitle,
                isPinned: obj["isPinned"]?.boolValue ?? false,
                isArchived: obj["isArchived"]?.boolValue ?? false,
                isUnread: obj["isUnread"]?.boolValue ?? false,
                isCloud: isCloud
            )
        }
    }

    private static func normalizeProtoModelEnum(_ modelId: String) -> String {
        let trimmed = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("MODEL_") {
            return trimmed
        }
        let lower = trimmed.lowercased()
        if lower.contains("flash") {
            return "MODEL_PLACEHOLDER_M18"
        }
        return "MODEL_PLACEHOLDER_M26"
    }

    /// Creates a new Cascade session (`StartCascade`) on the backend and returns its `cascadeId`.
    public func startCascade(
        workspaceUri: String,
        initialPrompt: String = "",
        modelId: String = "MODEL_PLACEHOLDER_M26"
    ) async throws -> String {
        let protoModel = Self.normalizeProtoModelEnum(modelId)
        var payload: [String: JSONValue] = [
            "metadata": .object([
                "ideName": .string("antigravity-ios"),
                "ideVersion": .string("2.0.0")
            ]),
            "workspaceUris": .array([.string(workspaceUri)]),
            "modelId": .string(protoModel)
        ]
        if !initialPrompt.isEmpty {
            payload["initialUserInput"] = .string(initialPrompt)
        }
        let res = try await callUnaryJSON(method: "StartCascade", body: payload)
        guard let cascadeId = res["cascadeId"]?.stringValue else {
            throw AntigravityRPCError.decodingError("Missing cascadeId in StartCascade response")
        }
        return cascadeId
    }

    /// Sends a user prompt + `@file` context items + model/mode config (`SendUserCascadeMessage`).
    /// Includes both native `language_server` fields (`items`, `metadata`, `cascadeConfig`)
    /// and companion/mock fields (`userResponse`, `modelConfig`).
    public func sendUserCascadeMessage(
        cascadeId: String,
        message: String,
        attachments: [ComposerAttachmentChip] = [],
        modelId: String,
        effort: ThinkingEffortLevel = .high,
        mode: CascadeExecutionMode = .planning,
        agentPersona: String = "Default"
    ) async throws {
        var items: [JSONValue] = [.object(["text": .string(message)])]
        for chip in attachments {
            items.append(
                .object([
                    "item": .object([
                        "file": .object([
                            "absoluteUri": .string(chip.targetUri),
                            "label": .string(chip.label)
                        ])
                    ])
                ])
            )
        }

        let plannerMode = (mode == .planning)
            ? "CONVERSATIONAL_PLANNER_MODE_PLANNING"
            : "CONVERSATIONAL_PLANNER_MODE_DEFAULT"
        let protoModel = Self.normalizeProtoModelEnum(modelId)

        _ = try await callUnaryJSON(
            method: "SendUserCascadeMessage",
            body: [
                "cascadeId": .string(cascadeId),
                "items": .array(items),
                "userResponse": .string(message),
                "metadata": .object([
                    "ideName": .string("antigravity-ios"),
                    "ideVersion": .string("2.0.0")
                ]),
                "cascadeConfig": .object([
                    "plannerConfig": .object([
                        "conversational": .object([
                            "plannerMode": .string(plannerMode)
                        ]),
                        "requestedModel": .object([
                            "model": .string(protoModel)
                        ])
                    ])
                ]),
                "modelConfig": .object([
                    "modelId": .string(modelId),
                    "thinkingEffort": .string(effort.rawValue.uppercased()),
                    "mode": .string(mode.rawValue.uppercased()),
                    "agentPersona": .string(agentPersona)
                ])
            ]
        )
    }

    public func handleCascadeUserInteraction(_ payload: CascadeUserInteractionPayload) async throws {
        var interactionObj: [String: JSONValue] = [
            "trajectoryId": .string(payload.cascadeId),
            "stepIndex": .int(payload.stepIndex)
        ]

        if let rc = payload.runCommand {
            interactionObj["runCommand"] = .object([
                "confirm": .bool(rc.confirm),
                "proposedCommandLine": .string(rc.proposedCommandLine),
                "submittedCommandLine": .string(rc.submittedCommandLine),
                "faceIdVerified": .bool(rc.faceIdVerified)
            ])
        } else if let perm = payload.permission {
            interactionObj["permission"] = .object([
                "allow": .bool(perm.allow),
                "turnGrants": .object([
                    "allow": .array(perm.grantPatterns.map(JSONValue.string)),
                    "deny": .array([])
                ])
            ])
        } else if let fp = payload.filePermission {
            var fpObj: [String: JSONValue] = [
                "allow": .bool(fp.allow),
                "scope": .string(fp.scope)
            ]
            if let uri = fp.absolutePathUri {
                fpObj["absolutePathUri"] = .string(uri)
            }
            interactionObj["filePermission"] = .object(fpObj)
        } else if let qa = payload.askQuestion {
            var qaObj: [String: JSONValue] = [
                "selectedOptions": .array(qa.selectedOptions.map(JSONValue.string))
            ]
            if let custom = qa.customResponse {
                qaObj["customResponse"] = .string(custom)
            }
            interactionObj["askQuestion"] = .object(qaObj)
        } else if let confirm = payload.genericConfirm {
            interactionObj[payload.kind.rawValue] = .object(["confirm": .bool(confirm)])
        }

        _ = try await callUnaryJSON(
            method: "HandleCascadeUserInteraction",
            body: ["interaction": .object(interactionObj)]
        )
    }

    public func handleCascadeUserInteraction(
        step: CascadeStep,
        decision: InteractionDecision
    ) async throws {
        guard let payload = InteractionBuilder.buildPayload(step: step, decision: decision) else {
            throw AntigravityRPCError.interactionRejected
        }
        try await handleCascadeUserInteraction(payload)
    }

    public func cancelCascadeInvocation(cascadeId: String) async throws {
        _ = try await callUnaryJSON(
            method: "CancelCascadeInvocation",
            body: ["cascadeId": .string(cascadeId)]
        )
    }

    public func pinCascade(cascadeId: String, isPinned: Bool) async throws {
        _ = try await callUnaryJSON(
            method: "PinCascade",
            body: [
                "cascadeId": .string(cascadeId),
                "isPinned": .bool(isPinned)
            ]
        )
    }

    public func renameCascade(cascadeId: String, newTitle: String) async throws {
        _ = try await callUnaryJSON(
            method: "RenameCascade",
            body: [
                "cascadeId": .string(cascadeId),
                "title": .string(newTitle)
            ]
        )
    }

    public func moveCascadeToWorkspace(cascadeId: String, workspaceUri: String) async throws {
        _ = try await callUnaryJSON(
            method: "MoveCascadeToWorkspace",
            body: [
                "cascadeId": .string(cascadeId),
                "workspaceUri": .string(workspaceUri)
            ]
        )
    }

    public func archiveCascade(cascadeId: String, isArchived: Bool = true) async throws {
        _ = try await callUnaryJSON(
            method: "ArchiveCascade",
            body: [
                "cascadeId": .string(cascadeId),
                "isArchived": .bool(isArchived)
            ]
        )
    }

    public func deleteCascade(cascadeId: String) async throws {
        _ = try await callUnaryJSON(
            method: "DeleteCascade",
            body: ["cascadeId": .string(cascadeId)]
        )
    }

    // MARK: - Automations RPC (`UE06`)

    public func listAutomations() async throws -> [AutomationItem] {
        let res = try await callUnaryJSON(method: "ListAutomations")
        guard let arr = res["automations"]?.arrayValue else { return [] }
        return arr.compactMap { item -> AutomationItem? in
            guard let obj = item.objectValue,
                  let id = obj["id"]?.stringValue,
                  let title = obj["title"]?.stringValue else { return nil }
            let slug = obj["projectSlug"]?.stringValue ?? "ledger-svc"
            let summary = obj["scheduleSummary"]?.stringValue ?? "\(slug) · Daily · Flash"
            let sectionRaw = (obj["section"]?.stringValue ?? AutomationSectionKind.scheduled.rawValue).uppercased()
            let section = AutomationSectionKind(rawValue: sectionRaw) ?? .scheduled
            return AutomationItem(
                id: id,
                title: title,
                projectSlug: slug,
                scheduleSummary: summary,
                section: section,
                nextRunText: obj["nextRunText"]?.stringValue ?? "Tonight, 02:00",
                lastRunText: obj["lastRunText"]?.stringValue ?? "Scheduled",
                needsReview: obj["needsReview"]?.boolValue ?? false,
                isRunningNow: obj["isRunningNow"]?.boolValue ?? false
            )
        }
    }

    public func createAutomation(prompt: String, projectSlug: String) async throws -> AutomationItem {
        let res = try await callUnaryJSON(
            method: "CreateAutomation",
            body: [
                "prompt": .string(prompt),
                "projectSlug": .string(projectSlug)
            ]
        )
        let id = res["id"]?.stringValue ?? "auto-\(UUID().uuidString.prefix(8).lowercased())"
        return AutomationItem(
            id: id,
            title: prompt,
            projectSlug: projectSlug,
            scheduleSummary: "\(projectSlug) · Custom schedule · Flash",
            section: .scheduled,
            nextRunText: "Tomorrow, 09:00",
            lastRunText: "Created just now"
        )
    }

    public func triggerAutomationNow(automationId: String) async throws {
        _ = try await callUnaryJSON(
            method: "TriggerAutomationNow",
            body: ["automationId": .string(automationId)]
        )
    }

    public func setAutomationPaused(automationId: String, isPaused: Bool) async throws {
        _ = try await callUnaryJSON(
            method: "SetAutomationPaused",
            body: [
                "automationId": .string(automationId),
                "isPaused": .bool(isPaused)
            ]
        )
    }

    // MARK: - Artifacts & Turn Diff RPC (`UE11`, `UE12`)

    public func getArtifactSnapshots(cascadeId: String) async throws -> [ArtifactSnapshot] {
        let res = try await callUnaryJSON(
            method: "GetArtifactSnapshots",
            body: ["cascadeId": .string(cascadeId)]
        )
        guard let arr = res["artifacts"]?.arrayValue else { return [] }
        return arr.compactMap { item -> ArtifactSnapshot? in
            guard let obj = item.objectValue,
                  let path = obj["artifactPath"]?.stringValue else { return nil }
            return ArtifactSnapshot(
                artifactPath: path,
                title: obj["title"]?.stringValue ?? "Artifact",
                summary: obj["summary"]?.stringValue ?? "",
                kind: .implementationPlan,
                content: obj["content"]?.stringValue ?? "",
                requestFeedback: obj["requestFeedback"]?.boolValue ?? false
            )
        }
    }

    public func sendPlanReviewComments(cascadeId: String, comments: [PlanInlineComment]) async throws {
        let encodedComments: [JSONValue] = comments.map { c in
            .object([
                "id": .string(c.id),
                "targetFilePath": .string(c.targetFilePath),
                "quotedSpan": .string(c.quotedSpan),
                "body": .string(c.body)
            ])
        }
        _ = try await callUnaryJSON(
            method: "SendPlanReviewComments",
            body: [
                "cascadeId": .string(cascadeId),
                "comments": .array(encodedComments)
            ]
        )
    }

    public func getTurnDiff(cascadeId: String, turnNumber: Int?) async throws -> [FilePatchDiff] {
        var body: [String: JSONValue] = ["cascadeId": .string(cascadeId)]
        if let turnNumber {
            body["turnNumber"] = .int(turnNumber)
        }
        _ = try await callUnaryJSON(method: "GetTurnDiff", body: body)
        return []
    }

    public func revertDiffHunk(cascadeId: String, filePath: String, hunkHeader: String? = nil) async throws {
        var body: [String: JSONValue] = [
            "cascadeId": .string(cascadeId),
            "filePath": .string(filePath)
        ]
        if let hunkHeader {
            body["hunkHeader"] = .string(hunkHeader)
        }
        _ = try await callUnaryJSON(method: "RevertDiffHunk", body: body)
    }

    public func sendDiffReviewComments(cascadeId: String, comments: [DiffLineComment]) async throws {
        let encoded: [JSONValue] = comments.map { c in
            .object([
                "id": .string(c.id),
                "filePath": .string(c.filePath),
                "lineNumber": .int(c.lineNumber),
                "body": .string(c.body)
            ])
        }
        _ = try await callUnaryJSON(
            method: "SendDiffReviewComments",
            body: [
                "cascadeId": .string(cascadeId),
                "comments": .array(encoded)
            ]
        )
    }

    // MARK: - Server-Streaming Envelope Subscription

    /// Subscribes to a Connect-RPC server-streaming method (`JetboxSubscribeToSummaries`, `StreamCascadeReactiveUpdates`, etc.)
    public func subscribeEnvelopeStream(
        method: String,
        requestPayload: [String: JSONValue] = [:]
    ) throws -> AsyncThrowingStream<[String: JSONValue], Error> {
        let url = endpointURL.appendingPathComponent("\(Self.servicePrefix)/\(method)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/connect+json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        applyAuthHeaders(to: &request)

        let rawJSON = try JSONEncoder().encode(requestPayload)
        request.httpBody = ConnectEnvelopeFrame(flags: [], payload: rawJSON).encode()

        let session = self.urlSession
        let immutableRequest = request
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: immutableRequest)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                        throw AntigravityRPCError.invalidEndpoint
                    }
                    var parser = ConnectStreamParser()
                    var chunkBuffer = Data()
                    let decoder = JSONDecoder()
                    for try await byte in bytes {
                        chunkBuffer.append(byte)
                        if chunkBuffer.count >= 16 {
                            for frame in parser.feed(chunkBuffer) {
                                if frame.flags.contains(.endStream) {
                                    continuation.finish()
                                    return
                                }
                                if let obj = try? decoder.decode([String: JSONValue].self, from: frame.payload) {
                                    continuation.yield(obj)
                                }
                            }
                            chunkBuffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !chunkBuffer.isEmpty {
                        for frame in parser.feed(chunkBuffer) where !frame.flags.contains(.endStream) {
                            if let obj = try? decoder.decode([String: JSONValue].self, from: frame.payload) {
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

    // MARK: - JSON Step Decoder (`language_server` + Companion Schema)

    private static func nonEmptyString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : raw
    }

    private static func resolveStepType(_ typeName: String) -> CortexStepType {
        if let exact = CortexStepType.allCases.first(where: { $0.jsonName == typeName }) {
            return exact
        }
        let upper = typeName.uppercased()
        if upper.contains("USER_INPUT") { return .userInput }
        if upper.contains("PLANNER_RESPONSE") { return .plannerResponse }
        if upper.contains("NOTIFY_USER") { return .notifyUser }
        if upper.contains("TASK_BOUNDARY") { return .taskBoundary }
        if upper.contains("RUN_COMMAND") { return .runCommand }
        if upper.contains("VIEW_FILE") || upper.contains("VIEW_CODE") { return .viewFile }
        if upper.contains("GREP_SEARCH") || upper.contains("FIND_BY_NAME") || upper.contains("SEARCH") { return .search }
        if upper.contains("LIST_DIRECTORY") { return .listDirectory }
        if upper.contains("CODE_ACTION") || upper.contains("REPLACE_FILE") || upper.contains("WRITE_TO_FILE") {
            return .codeAction
        }
        return .unspecified
    }

    private static func parseDurationSeconds(_ value: JSONValue?) -> Double? {
        guard let value else { return nil }
        if let d = value.doubleValue { return d }
        if let obj = value.objectValue {
            let secs = obj["seconds"]?.doubleValue ?? Double(obj["seconds"]?.stringValue ?? "") ?? 0
            let nanos = obj["nanos"]?.doubleValue ?? Double(obj["nanos"]?.stringValue ?? "") ?? 0
            let total = secs + (nanos / 1_000_000_000.0)
            return total > 0 ? total : nil
        }
        if let str = value.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) {
            let numeric = str.hasSuffix("s") ? String(str.dropLast()) : str
            return Double(numeric)
        }
        return nil
    }

    public static func decodeJSONStep(
        _ value: JSONValue,
        cascadeId: String,
        fallbackIndex: Int
    ) -> CascadeStep? {
        guard let obj = value.objectValue else { return nil }
        let stepIndex = obj["stepIndex"]?.intValue ?? fallbackIndex
        let typeName = obj["type"]?.stringValue ?? ""
        let statusName = obj["status"]?.stringValue ?? "CORTEX_STEP_STATUS_DONE"
        var stepType = resolveStepType(typeName)
        let stepStatus = CortexStepStatus.from(jsonName: statusName)

        // Decode userInput (string or nested object `{"userResponse": ...}` / `{"items": [{"text": ...}]}`)
        var userText: String? = nonEmptyString(obj["userInput"]?.stringValue)
        var mentions: [String] = obj["attachedMentions"]?.arrayValue?.compactMap(\.stringValue) ?? []
        if let uiObj = obj["userInput"]?.objectValue {
            let itemsJoined = uiObj["items"]?.arrayValue?
                .compactMap { nonEmptyString($0.objectValue?["text"]?.stringValue) }
                .joined(separator: "\n")
            userText = nonEmptyString(uiObj["userResponse"]?.stringValue)
                ?? nonEmptyString(itemsJoined)
            if let itemArr = uiObj["items"]?.arrayValue {
                for item in itemArr {
                    if let fileObj = item.objectValue?["item"]?.objectValue?["file"]?.objectValue {
                        if let fileLabel = nonEmptyString(fileObj["label"]?.stringValue) {
                            if !mentions.contains(fileLabel) { mentions.append(fileLabel) }
                        } else if let uri = nonEmptyString(fileObj["absoluteUri"]?.stringValue) {
                            let base = (uri.replacingOccurrences(of: "file://", with: "") as NSString).lastPathComponent
                            let chip = base.hasPrefix("@") ? base : "@\(base)"
                            if !base.isEmpty && !mentions.contains(chip) { mentions.append(chip) }
                        }
                    }
                }
            }
            if stepType == .unspecified && (userText != nil || !mentions.isEmpty) {
                stepType = .userInput
            }
        }

        // Decode plannerResponse & notifyUser
        var plannerPayload: PlannerResponsePayload?
        if let pr = obj["plannerResponse"]?.objectValue {
            let text = nonEmptyString(pr["modifiedResponse"]?.stringValue)
                ?? nonEmptyString(pr["response"]?.stringValue)
                ?? ""
            let thinking = nonEmptyString(pr["thinking"]?.stringValue)
            let duration = parseDurationSeconds(pr["thinkingDurationSeconds"] ?? pr["thinkingDuration"])
            if !text.isEmpty || thinking != nil {
                plannerPayload = PlannerResponsePayload(
                    response: text,
                    thinking: thinking,
                    thinkingDurationSeconds: duration
                )
                if stepType == .unspecified {
                    stepType = .plannerResponse
                }
            }
        } else if let nu = obj["notifyUser"]?.objectValue {
            let notifyText = nonEmptyString(nu["notificationContent"]?.stringValue)
                ?? nonEmptyString(nu["message"]?.stringValue)
                ?? nonEmptyString(nu["reviewContent"]?.stringValue)
            if let notifyText {
                let paths = nu["pathsToReview"]?.arrayValue?.compactMap(\.stringValue) ?? []
                plannerPayload = PlannerResponsePayload(
                    response: notifyText,
                    referencedFiles: paths
                )
                stepType = .notifyUser
            }
        }

        // Decode runCommand + requestedInteraction
        var runCmdPayload: RunCommandPayload?
        var interaction: RequestedInteraction?
        if let rc = obj["runCommand"]?.objectValue {
            let cmdLine = nonEmptyString(rc["commandLine"]?.stringValue)
                ?? nonEmptyString(rc["proposedCommandLine"]?.stringValue)
                ?? nonEmptyString(rc["command"]?.stringValue)
                ?? ""
            let cwd = nonEmptyString(rc["cwd"]?.stringValue) ?? "~"
            if !cmdLine.isEmpty {
                runCmdPayload = RunCommandPayload(
                    commandId: rc["commandId"]?.stringValue ?? "cmd-\(stepIndex)",
                    commandLine: cmdLine,
                    proposedCommandLine: nonEmptyString(rc["proposedCommandLine"]?.stringValue) ?? cmdLine,
                    cwd: cwd,
                    exitCode: rc["exitCode"]?.intValue,
                    outputPreview: nonEmptyString(rc["combinedOutput"]?.objectValue?["full"]?.stringValue)
                        ?? nonEmptyString(rc["outputPreview"]?.stringValue)
                        ?? nonEmptyString(rc["output"]?.stringValue)
                )
                if stepType == .unspecified {
                    stepType = .runCommand
                }
            }
            if stepStatus == .waiting {
                interaction = RequestedInteraction(
                    kind: .runCommand,
                    runCommand: RunCommandInteractionSpec(proposedCommandLine: cmdLine, cwd: cwd)
                )
            }
        }

        if let reqInt = obj["requestedInteraction"]?.objectValue {
            if let rcInt = reqInt["runCommand"]?.objectValue {
                let cmd = nonEmptyString(rcInt["proposedCommandLine"]?.stringValue) ?? runCmdPayload?.commandLine ?? ""
                interaction = RequestedInteraction(
                    kind: .runCommand,
                    runCommand: RunCommandInteractionSpec(
                        proposedCommandLine: cmd,
                        cwd: nonEmptyString(rcInt["cwd"]?.stringValue) ?? "~"
                    )
                )
            } else if let qaInt = reqInt["askQuestion"]?.objectValue {
                interaction = RequestedInteraction(
                    kind: .askQuestion,
                    askQuestion: AskQuestionInteractionSpec(
                        question: nonEmptyString(qaInt["question"]?.stringValue) ?? "Input required",
                        options: qaInt["options"]?.arrayValue?.compactMap(\.stringValue) ?? [],
                        isMultiSelect: qaInt["isMultiSelect"]?.boolValue ?? false
                    )
                )
            } else if let fpInt = reqInt["filePermission"]?.objectValue {
                interaction = RequestedInteraction(
                    kind: .filePermission,
                    filePermission: FilePermissionInteractionSpec(
                        absolutePathUri: fpInt["absolutePathUri"]?.stringValue ?? ""
                    )
                )
            }
        }

        var viewFilePayload: ViewFilePayload?
        let vfCandidate = obj["viewFile"]?.objectValue
            ?? obj["viewFileOutline"]?.objectValue
            ?? obj["viewCodeItem"]?.objectValue
        if let vf = vfCandidate,
           let uri = nonEmptyString(vf["fileUri"]?.stringValue)
            ?? nonEmptyString(vf["absolutePathUri"]?.stringValue)
            ?? nonEmptyString(vf["absolutePath"]?.stringValue) {
            viewFilePayload = ViewFilePayload(
                fileUri: uri,
                startLine: vf["startLine"]?.intValue ?? 1,
                endLine: vf["endLine"]?.intValue ?? 120
            )
            if stepType == .unspecified { stepType = .viewFile }
        }

        var searchPayload: SearchPayload?
        let searchCandidate = obj["grepSearch"]?.objectValue
            ?? obj["findByName"]?.objectValue
            ?? obj["search"]?.objectValue
        if let sc = searchCandidate {
            let query = nonEmptyString(sc["query"]?.stringValue)
                ?? nonEmptyString(sc["pattern"]?.stringValue)
                ?? "workspace"
            let scope = nonEmptyString(sc["searchPath"]?.stringValue)
                ?? nonEmptyString(sc["searchDirectory"]?.stringValue)
                ?? "."
            let count = sc["results"]?.arrayValue?.count ?? sc["matchCount"]?.intValue ?? 0
            searchPayload = SearchPayload(query: query, scopeDirectory: scope, matchCount: count)
            if stepType == .unspecified { stepType = .search }
        }

        var codeActionPayload: CodeActionPayload?
        let caCandidate = obj["codeAction"]?.objectValue
            ?? obj["replaceFileContent"]?.objectValue
            ?? obj["writeToFile"]?.objectValue
        if let ca = caCandidate {
            let actionSpec = ca["actionSpec"]?.objectValue
            let uri = nonEmptyString(ca["targetFileUri"]?.stringValue)
                ?? nonEmptyString(ca["fileUri"]?.stringValue)
                ?? nonEmptyString(ca["targetFile"]?.stringValue)
                ?? nonEmptyString(actionSpec?["createFile"]?.objectValue?["path"]?.objectValue?["absoluteUri"]?.stringValue)
                ?? nonEmptyString(actionSpec?["insertBlock"]?.objectValue?["path"]?.objectValue?["absoluteUri"]?.stringValue)
            if let uri {
                codeActionPayload = CodeActionPayload(
                    targetFileUri: uri,
                    description: nonEmptyString(ca["description"]?.stringValue)
                        ?? nonEmptyString(ca["instruction"]?.stringValue)
                        ?? "Updated file",
                    additions: ca["additions"]?.intValue ?? 0,
                    deletions: ca["deletions"]?.intValue ?? 0
                )
                if stepType == .unspecified { stepType = .codeAction }
            }
        }

        var taskBoundaryPayload: TaskBoundaryPayload?
        if let tb = obj["taskBoundary"]?.objectValue {
            taskBoundaryPayload = TaskBoundaryPayload(
                taskName: nonEmptyString(tb["taskName"]?.stringValue) ?? "Task",
                taskStatus: nonEmptyString(tb["taskStatus"]?.stringValue) ?? "",
                taskSummary: nonEmptyString(tb["taskSummary"]?.stringValue) ?? "",
                completedCount: tb["completedCount"]?.intValue ?? 1,
                totalCount: tb["totalCount"]?.intValue ?? 4
            )
            if stepType == .unspecified { stepType = .taskBoundary }
        }

        return CascadeStep(
            cascadeId: cascadeId,
            stepIndex: stepIndex,
            type: stepType,
            status: stepStatus,
            userInput: userText,
            attachedMentions: mentions,
            plannerResponse: plannerPayload,
            taskBoundary: taskBoundaryPayload,
            runCommand: runCmdPayload,
            codeAction: codeActionPayload,
            viewFile: viewFilePayload,
            search: searchPayload,
            requestedInteraction: interaction
        )
    }

    // MARK: - Live Desktop Summary & Timestamp Helpers

    /// Decodes a single entry from `GetAllCascadeTrajectories.trajectorySummaries`,
    /// filtering out blank 0-step unused Desktop tabs and computing accurate unread/status/relative-time fields.
    public static func decodeTrajectorySummaryEntry(
        cascadeId: String,
        value: JSONValue,
        now: Date = Date()
    ) -> CascadeSummary? {
        guard let obj = value.objectValue else { return nil }
        let annotations = obj["annotations"]?.objectValue

        let candidateTitles: [String?] = [
            annotations?["title"]?.stringValue,
            obj["summary"]?.stringValue,
            obj["title"]?.stringValue
        ]
        let resolvedTitle = candidateTitles
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

        let stepCount = obj["stepCount"]?.intValue
            ?? Int(obj["stepCount"]?.stringValue ?? "")
            ?? 0

        // Antigravity Desktop keeps unused 0-step New Chat placeholders in `trajectorySummaries`
        // without a title/summary and hides them in its sidebar. Filter them out cleanly.
        if resolvedTitle == nil && stepCount == 0 {
            return nil
        }
        let title = resolvedTitle ?? "New Conversation"
        let lowerTitle = title.lowercased()
        if lowerTitle.contains("ios connect-rpc handshake")
            || lowerTitle.contains("reply in one short sentence confirming ios connect-rpc handshake") {
            return nil
        }

        let workspaceObjects = (obj["workspaces"]?.arrayValue ?? []).compactMap(\.objectValue)
        let selectedWorkspace = Self.selectPrimaryWorkspaceObject(from: workspaceObjects)
        let trajMeta = obj["trajectoryMetadata"]?.objectValue
        let rawUri = selectedWorkspace?["workspaceFolderAbsoluteUri"]?.stringValue
            ?? selectedWorkspace?["workspaceUri"]?.stringValue
            ?? obj["workspaceUri"]?.stringValue
            ?? "file:///Users/wl/code/workspace"

        let sourceHint = [
            obj["source"]?.stringValue,
            obj["runtime"]?.stringValue,
            trajMeta?["runtime"]?.stringValue,
            trajMeta?["environment"]?.stringValue,
            trajMeta?["executionEnvironment"]?.stringValue,
            trajMeta?["source"]?.stringValue
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        let isCloud = (obj["isCloud"]?.boolValue ?? false)
            || (trajMeta?["isCloud"]?.boolValue ?? false)
            || AntigravityCloudDetector.isCloudWorkspaceURI(rawUri, cascadeId: cascadeId, sourceHint: sourceHint)
        let uri = AntigravityCloudDetector.normalizeWorkspaceURI(rawUri, isCloud: isCloud)

        let explicitSlug = obj["projectSlug"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug: String
        if let explicitSlug, !explicitSlug.isEmpty {
            slug = explicitSlug
        } else if rawUri.hasPrefix("cloud://") {
            let trimmedCloud = rawUri.replacingOccurrences(of: "cloud://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            slug = trimmedCloud.isEmpty ? "cloud-workspace" : trimmedCloud
        } else if rawUri.hasPrefix("https://github.com/") {
            let trimmedGH = rawUri.replacingOccurrences(of: "https://github.com/", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            slug = trimmedGH.isEmpty ? "github-workspace" : trimmedGH
        } else if rawUri.contains("://") && !rawUri.hasPrefix("file://") {
            let decodedRaw = rawUri.removingPercentEncoding ?? rawUri
            let lastComp = ((URL(string: decodedRaw)?.path ?? decodedRaw) as NSString).lastPathComponent
            slug = lastComp.isEmpty ? "cloud-workspace" : lastComp
        } else {
            let cleanPath = (rawUri.removingPercentEncoding ?? rawUri)
                .replacingOccurrences(of: "file://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let lastComp = (cleanPath as NSString).lastPathComponent
            if (!lastComp.isEmpty && lastComp != "workspace" && lastComp != "antigravity") || trajMeta?["projectId"]?.stringValue == nil {
                slug = lastComp.isEmpty ? "workspace" : lastComp
            } else {
                slug = trajMeta?["projectId"]?.stringValue ?? "workspace"
            }
        }
        let branch = selectedWorkspace?["gitBranch"]?.stringValue
            ?? selectedWorkspace?["branchName"]?.stringValue
            ?? obj["branchName"]?.stringValue
            ?? "main"

        let statusRaw = obj["status"]?.stringValue ?? "CASCADE_RUN_STATUS_IDLE"
        let status = CortexStepStatus.from(jsonName: statusRaw)

        let updatedDate = Self.parseProtoTimestamp(
            obj["lastModifiedTime"]
                ?? obj["updatedAt"]
                ?? obj["lastStepTime"]
                ?? obj["createdTime"]
        )
        let lastViewedDate = Self.parseProtoTimestamp(
            annotations?["lastUserViewTime"] ?? obj["lastUserViewTime"]
        )
        let updatedAt = updatedDate ?? now
        let relativeLabel = Self.formatRelativeTimeLabel(from: updatedDate, now: now)

        let isUnread: Bool
        if let explicitUnread = obj["isUnread"]?.boolValue ?? annotations?["unread"]?.boolValue {
            isUnread = explicitUnread
        } else if let updatedDate, let lastViewedDate {
            isUnread = updatedDate.timeIntervalSince(lastViewedDate) > 1.0
                || statusRaw.uppercased() == "CASCADE_RUN_STATUS_DONE"
        } else {
            isUnread = statusRaw.uppercased() == "CASCADE_RUN_STATUS_DONE" || status == .waiting
        }

        let isPinned = obj["isPinned"]?.boolValue
            ?? annotations?["pinned"]?.boolValue
            ?? annotations?["isPinned"]?.boolValue
            ?? false
        let isArchived = obj["isArchived"]?.boolValue
            ?? annotations?["archived"]?.boolValue
            ?? annotations?["isArchived"]?.boolValue
            ?? false

        let explicitSubtitle = obj["statusSubtitle"]?.stringValue
        let subtitle = Self.buildLiveStatusSubtitle(
            status: status,
            stepCount: stepCount,
            isUnread: isUnread,
            explicitSubtitle: explicitSubtitle
        )

        return CascadeSummary(
            cascadeId: cascadeId,
            title: title,
            projectSlug: slug.isEmpty ? "workspace" : slug,
            workspaceUri: uri,
            branchName: branch,
            status: status,
            stepCount: stepCount,
            currentStepIndex: max(1, stepCount),
            totalSteps: max(1, stepCount),
            updatedAt: updatedAt,
            relativeTimeLabel: relativeLabel,
            statusSubtitle: subtitle,
            isPinned: isPinned,
            isArchived: isArchived,
            isUnread: isUnread,
            isCloud: isCloud
        )
    }

    private static func selectPrimaryWorkspaceObject(
        from workspaces: [[String: JSONValue]]
    ) -> [String: JSONValue]? {
        guard !workspaces.isEmpty else { return nil }
        for entry in workspaces {
            let raw = (entry["workspaceFolderAbsoluteUri"]?.stringValue ?? entry["workspaceUri"]?.stringValue ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = raw.lowercased()
            if lower.hasPrefix("cloud://")
                || lower.hasPrefix("vscode-remote://")
                || lower.hasPrefix("vscode-vfs://")
                || lower.hasPrefix("https://github.com/") {
                return entry
            }
        }
        for entry in workspaces {
            let raw = (entry["workspaceFolderAbsoluteUri"]?.stringValue ?? entry["workspaceUri"]?.stringValue ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }
            let decoded = (raw.removingPercentEncoding ?? raw)
            let fsPath: String
            if decoded.hasPrefix("file://") {
                let tail = String(decoded.dropFirst("file://".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                fsPath = tail.isEmpty ? "/" : "/\(tail)"
            } else {
                fsPath = decoded
            }
            if !AntigravityCloudDetector.genericContainerRoots.contains(fsPath) {
                return entry
            }
        }
        return workspaces.first
    }

    /// Parses Protobuf `google.protobuf.Timestamp` values encoded either as RFC3339 strings
    /// (including 1–9 fractional nanosecond digits) or `{"seconds": ..., "nanos": ...}` objects.
    public static func parseProtoTimestamp(_ value: JSONValue?) -> Date? {
        guard let value else { return nil }

        if let tsObj = value.objectValue {
            let secs: Double? = tsObj["seconds"]?.doubleValue
                ?? Double(tsObj["seconds"]?.stringValue ?? "")
            if let secs {
                let nanos = tsObj["nanos"]?.doubleValue
                    ?? Double(tsObj["nanos"]?.stringValue ?? "")
                    ?? 0
                return Date(timeIntervalSince1970: secs + (nanos / 1_000_000_000.0))
            }
            return nil
        }

        guard let rawString = value.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawString.isEmpty else {
            return nil
        }

        if let dotIdx = rawString.firstIndex(of: ".") {
            let fracStart = rawString.index(after: dotIdx)
            var fracEnd = fracStart
            while fracEnd < rawString.endIndex && rawString[fracEnd].isNumber {
                fracEnd = rawString.index(after: fracEnd)
            }
            let digits = rawString[fracStart..<fracEnd]
            if !digits.isEmpty {
                let millis = String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
                let normalized = "\(rawString[..<dotIdx]).\(millis)\(rawString[fracEnd...])"
                let fracFormatter = ISO8601DateFormatter()
                fracFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let parsed = fracFormatter.date(from: normalized) {
                    return parsed
                }
            }
        }

        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        return plainFormatter.date(from: rawString)
    }

    /// Formats a compact mobile relative timestamp (`now`, `8m`, `2h`, `Yesterday`, `4d`, `2w`).
    public static func formatRelativeTimeLabel(from date: Date?, now: Date = Date()) -> String {
        guard let date else { return "now" }
        let delta = max(0, now.timeIntervalSince(date))
        if delta < 60 {
            return "now"
        } else if delta < 3_600 {
            return "\(Int(delta / 60))m"
        } else if delta < 86_400 {
            return "\(Int(delta / 3_600))h"
        } else if delta < 172_800 {
            return "Yesterday"
        } else if delta < 604_800 {
            return "\(Int(delta / 86_400))d"
        } else {
            return "\(Int(delta / 604_800))w"
        }
    }

    public static func buildLiveStatusSubtitle(
        status: CortexStepStatus,
        stepCount: Int,
        isUnread: Bool,
        explicitSubtitle: String? = nil
    ) -> String {
        if let explicitSubtitle, !explicitSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicitSubtitle
        }
        switch status {
        case .inProgress:
            return stepCount > 0 ? "Running · Step \(stepCount)" : "Running..."
        case .pending:
            return "Queued · Waiting to start"
        case .waiting, .blocked:
            return "Needs review · Waiting on you"
        case .error:
            return stepCount > 0 ? "Error · Step \(stepCount)" : "Error"
        case .cancelled:
            return stepCount > 0 ? "Stopped · \(stepCount) steps" : "Stopped"
        case .done:
            if isUnread {
                return stepCount > 0 ? "Done · New reply · \(stepCount) steps" : "Done · New reply"
            }
            return stepCount > 0 ? "Done · \(stepCount) steps" : "Done"
        case .unspecified:
            return stepCount > 0 ? "Idle · \(stepCount) steps" : "Idle"
        }
    }
}
