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
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 20
            config.timeoutIntervalForResource = 300
            let delegate = PinnedTLSURLSessionDelegate(
                pinnedFingerprintSHA256: pinnedFingerprintSHA256,
                allowLocalSelfSignedTOFU: host.channel == .directHost
            )
            self.urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
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
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 20
            config.timeoutIntervalForResource = 300
            let delegate = PinnedTLSURLSessionDelegate(
                pinnedFingerprintSHA256: pinnedFingerprintSHA256,
                allowLocalSelfSignedTOFU: true
            )
            self.urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        }
    }

    // MARK: - Handshake & Login Verification

    /// Verifies authentication (`x-codeium-csrf-token` or Google session cookie) and hydrates initial state.
    public func verifyConnection() async throws -> BackendHandshakeResult {
        let start = Date()
        async let workspacesTask = getWorkspaceInfos()
        async let summariesTask = getAllCascadeTrajectories()
        let workspaces = try await workspacesTask
        let summaries = try await summariesTask
        let elapsedMs = max(1, Int(Date().timeIntervalSince(start) * 1000.0))
        return BackendHandshakeResult(
            latencyMs: elapsedMs,
            workspaces: workspaces,
            summaries: summaries
        )
    }

    // MARK: - Core Unary RPC (`Sendable` JSONValue & Binary Protobuf)

    public func callUnaryJSON(
        method: String,
        body: [String: JSONValue] = [:]
    ) async throws -> [String: JSONValue] {
        let url = endpointURL.appendingPathComponent("\(Self.servicePrefix)/\(method)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
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

    public func getWorkspaceInfos() async throws -> [WorkspaceInfo] {
        let res = try await callUnaryJSON(method: "GetWorkspaceInfos")
        let items = res["workspaces"]?.arrayValue ?? res["workspaceInfos"]?.arrayValue ?? []
        return items.compactMap { item -> WorkspaceInfo? in
            guard let obj = item.objectValue else { return nil }
            guard let uri = obj["workspaceUri"]?.stringValue
                ?? obj["workspaceFolderAbsoluteUri"]?.stringValue else { return nil }
            let name = obj["displayName"]?.stringValue ?? (uri as NSString).lastPathComponent
            let branch = obj["activeBranch"]?.stringValue ?? obj["gitBranch"]?.stringValue ?? "main"
            let files = obj["indexedFiles"]?.arrayValue?.compactMap(\.stringValue) ?? []
            return WorkspaceInfo(
                workspaceUri: uri,
                displayName: name,
                activeBranch: branch,
                indexedFiles: files
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
    public func getAllCascadeTrajectories() async throws -> [CascadeSummary] {
        let res = try await callUnaryJSON(method: "GetAllCascadeTrajectories")

        // Format A: Native Desktop `language_server` map `{"trajectorySummaries": {"<cascadeId>": {...}}}`
        if let summaryMap = res["trajectorySummaries"]?.objectValue {
            return summaryMap.compactMap { cascadeId, value -> CascadeSummary? in
                guard let obj = value.objectValue else { return nil }
                let title = obj["summary"]?.stringValue ?? obj["title"]?.stringValue ?? "Untitled Conversation"
                let firstWorkspace = obj["workspaces"]?.arrayValue?.first?.objectValue
                let uri = firstWorkspace?["workspaceFolderAbsoluteUri"]?.stringValue
                    ?? obj["workspaceUri"]?.stringValue
                    ?? "file:///Users/wl/code/workspace"
                let slug = (uri as NSString).lastPathComponent
                let statusRaw = obj["status"]?.stringValue ?? "CORTEX_STEP_STATUS_DONE"
                let normalizedStatus = statusRaw.replacingOccurrences(of: "CASCADE_RUN_STATUS_", with: "CORTEX_STEP_STATUS_")
                let stepCount = obj["stepCount"]?.intValue ?? 0
                return CascadeSummary(
                    cascadeId: cascadeId,
                    title: title,
                    projectSlug: slug,
                    workspaceUri: uri,
                    status: CortexStepStatus.from(jsonName: normalizedStatus),
                    stepCount: stepCount
                )
            }
        }

        // Format B: Array `{"trajectories": [...]}`
        guard let list = res["trajectories"]?.arrayValue else { return [] }
        return list.compactMap { item -> CascadeSummary? in
            guard let obj = item.objectValue,
                  let id = obj["cascadeId"]?.stringValue,
                  let title = obj["title"]?.stringValue else { return nil }
            let uri = obj["workspaceUri"]?.stringValue ?? "file:///Users/wl/code/ledger-svc"
            let slug = obj["projectSlug"]?.stringValue ?? (uri as NSString).lastPathComponent
            let statusName = obj["status"]?.stringValue ?? "CORTEX_STEP_STATUS_DONE"
            let stepCount = obj["stepCount"]?.intValue ?? 0
            let branch = obj["branchName"]?.stringValue ?? "main"
            let subtitle = obj["statusSubtitle"]?.stringValue ?? ""
            return CascadeSummary(
                cascadeId: id,
                title: title,
                projectSlug: slug,
                workspaceUri: uri,
                branchName: branch,
                status: CortexStepStatus.from(jsonName: statusName),
                stepCount: stepCount,
                statusSubtitle: subtitle,
                isPinned: obj["isPinned"]?.boolValue ?? false,
                isArchived: obj["isArchived"]?.boolValue ?? false,
                isUnread: obj["isUnread"]?.boolValue ?? false
            )
        }
    }

    /// Creates a new Cascade session (`StartCascade`) on the backend and returns its `cascadeId`.
    public func startCascade(
        workspaceUri: String,
        initialPrompt: String = "",
        modelId: String = "MODEL_PLACEHOLDER_M26"
    ) async throws -> String {
        var payload: [String: JSONValue] = [
            "metadata": .object([
                "ideName": .string("antigravity-ios"),
                "ideVersion": .string("2.0.0")
            ]),
            "workspaceUris": .array([.string(workspaceUri)]),
            "modelId": .string(modelId)
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
                            "model": .string(modelId)
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
            let sectionRaw = obj["section"]?.stringValue ?? AutomationSectionKind.scheduled.rawValue
            let section = AutomationSectionKind(rawValue: sectionRaw) ?? .scheduled
            return AutomationItem(
                id: id,
                title: title,
                projectSlug: slug,
                scheduleSummary: summary,
                section: section,
                nextRunText: obj["nextRunText"]?.stringValue ?? "Tonight, 02:00",
                lastRunText: obj["lastRunText"]?.stringValue ?? "Scheduled"
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

    private static func decodeJSONStep(
        _ value: JSONValue,
        cascadeId: String,
        fallbackIndex: Int
    ) -> CascadeStep? {
        guard let obj = value.objectValue else { return nil }
        let stepIndex = obj["stepIndex"]?.intValue ?? fallbackIndex
        let typeName = obj["type"]?.stringValue ?? "CORTEX_STEP_TYPE_PLANNER_RESPONSE"
        let statusName = obj["status"]?.stringValue ?? "CORTEX_STEP_STATUS_DONE"
        let stepType = CortexStepType.allCases.first(where: { $0.jsonName == typeName }) ?? .plannerResponse
        let stepStatus = CortexStepStatus.from(jsonName: statusName)

        // Decode userInput (string or nested object `{"userResponse": ...}` / `{"items": [{"text": ...}]}`)
        var userText: String? = obj["userInput"]?.stringValue
        var mentions: [String] = obj["attachedMentions"]?.arrayValue?.compactMap(\.stringValue) ?? []
        if let uiObj = obj["userInput"]?.objectValue {
            userText = uiObj["userResponse"]?.stringValue
                ?? uiObj["items"]?.arrayValue?.compactMap { $0.objectValue?["text"]?.stringValue }.joined(separator: "\n")
            if let itemArr = uiObj["items"]?.arrayValue {
                for item in itemArr {
                    if let fileLabel = item.objectValue?["item"]?.objectValue?["file"]?.objectValue?["label"]?.stringValue {
                        mentions.append(fileLabel)
                    }
                }
            }
        }

        // Decode plannerResponse
        var plannerPayload: PlannerResponsePayload?
        if let pr = obj["plannerResponse"]?.objectValue {
            let text = pr["modifiedResponse"]?.stringValue ?? pr["response"]?.stringValue ?? ""
            let thinking = pr["thinking"]?.stringValue
            let duration = pr["thinkingDurationSeconds"]?.doubleValue
            plannerPayload = PlannerResponsePayload(
                response: text,
                thinking: thinking,
                thinkingDurationSeconds: duration
            )
        }

        // Decode runCommand + requestedInteraction
        var runCmdPayload: RunCommandPayload?
        var interaction: RequestedInteraction?
        if let rc = obj["runCommand"]?.objectValue {
            let cmdLine = rc["commandLine"]?.stringValue ?? rc["proposedCommandLine"]?.stringValue ?? ""
            let cwd = rc["cwd"]?.stringValue ?? "~"
            runCmdPayload = RunCommandPayload(
                commandId: rc["commandId"]?.stringValue ?? "cmd-\(stepIndex)",
                commandLine: cmdLine,
                proposedCommandLine: rc["proposedCommandLine"]?.stringValue ?? cmdLine,
                cwd: cwd,
                exitCode: rc["exitCode"]?.intValue,
                outputPreview: rc["combinedOutput"]?.objectValue?["full"]?.stringValue ?? rc["outputPreview"]?.stringValue
            )
            if stepStatus == .waiting {
                interaction = RequestedInteraction(
                    kind: .runCommand,
                    runCommand: RunCommandInteractionSpec(proposedCommandLine: cmdLine, cwd: cwd)
                )
            }
        }

        if let reqInt = obj["requestedInteraction"]?.objectValue {
            if let rcInt = reqInt["runCommand"]?.objectValue {
                let cmd = rcInt["proposedCommandLine"]?.stringValue ?? runCmdPayload?.commandLine ?? ""
                interaction = RequestedInteraction(
                    kind: .runCommand,
                    runCommand: RunCommandInteractionSpec(
                        proposedCommandLine: cmd,
                        cwd: rcInt["cwd"]?.stringValue ?? "~"
                    )
                )
            } else if let qaInt = reqInt["askQuestion"]?.objectValue {
                interaction = RequestedInteraction(
                    kind: .askQuestion,
                    askQuestion: AskQuestionInteractionSpec(
                        question: qaInt["question"]?.stringValue ?? "Input required",
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
        if let vf = obj["viewFile"]?.objectValue,
           let uri = vf["fileUri"]?.stringValue ?? vf["absolutePathUri"]?.stringValue {
            viewFilePayload = ViewFilePayload(
                fileUri: uri,
                startLine: vf["startLine"]?.intValue ?? 1,
                endLine: vf["endLine"]?.intValue ?? 120
            )
        }

        var codeActionPayload: CodeActionPayload?
        if let ca = obj["codeAction"]?.objectValue,
           let uri = ca["targetFileUri"]?.stringValue ?? ca["fileUri"]?.stringValue {
            codeActionPayload = CodeActionPayload(
                targetFileUri: uri,
                description: ca["description"]?.stringValue ?? "Updated file",
                additions: ca["additions"]?.intValue ?? 0,
                deletions: ca["deletions"]?.intValue ?? 0
            )
        }

        var taskBoundaryPayload: TaskBoundaryPayload?
        if let tb = obj["taskBoundary"]?.objectValue {
            taskBoundaryPayload = TaskBoundaryPayload(
                taskName: tb["taskName"]?.stringValue ?? "Task",
                taskStatus: tb["taskStatus"]?.stringValue ?? "",
                taskSummary: tb["taskSummary"]?.stringValue ?? "",
                completedCount: tb["completedCount"]?.intValue ?? 1,
                totalCount: tb["totalCount"]?.intValue ?? 4
            )
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
            requestedInteraction: interaction
        )
    }
}
