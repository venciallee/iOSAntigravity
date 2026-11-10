import Foundation

public enum AntigravityRPCError: Error, Sendable, Equatable {
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

    private let endpointURL: URL
    private let csrfToken: String?
    private let sessionCookie: String?
    private let urlSession: URLSession

    public init(
        host: RemoteHostInstance,
        csrfToken: String? = nil,
        sessionCookie: String? = nil,
        urlSession: URLSession = .shared
    ) {
        self.endpointURL = host.endpointURL
        self.csrfToken = csrfToken
        self.sessionCookie = sessionCookie
        self.urlSession = urlSession
    }

    public init(
        baseURL: URL,
        csrfToken: String? = nil,
        sessionCookie: String? = nil,
        urlSession: URLSession = .shared
    ) {
        self.endpointURL = baseURL
        self.csrfToken = csrfToken
        self.sessionCookie = sessionCookie
        self.urlSession = urlSession
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
        guard let items = res["workspaces"]?.arrayValue else { return [] }
        return items.compactMap { item -> WorkspaceInfo? in
            guard let obj = item.objectValue,
                  let uri = obj["workspaceUri"]?.stringValue else { return nil }
            let name = obj["displayName"]?.stringValue ?? (uri as NSString).lastPathComponent
            let branch = obj["activeBranch"]?.stringValue ?? "main"
            return WorkspaceInfo(workspaceUri: uri, displayName: name, activeBranch: branch)
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

    public func getAllCascadeTrajectories() async throws -> [CascadeSummary] {
        let res = try await callUnaryJSON(method: "GetAllCascadeTrajectories")
        guard let list = res["trajectories"]?.arrayValue else { return [] }
        return list.compactMap { item -> CascadeSummary? in
            guard let obj = item.objectValue,
                  let id = obj["cascadeId"]?.stringValue,
                  let title = obj["title"]?.stringValue else { return nil }
            let uri = obj["workspaceUri"]?.stringValue ?? "file:///Users/wl/code/ledger-svc"
            let slug = obj["projectSlug"]?.stringValue ?? (uri as NSString).lastPathComponent
            let statusName = obj["status"]?.stringValue ?? "CORTEX_STEP_STATUS_DONE"
            let stepCount = obj["stepCount"]?.intValue ?? 0
            return CascadeSummary(
                cascadeId: id,
                title: title,
                projectSlug: slug,
                workspaceUri: uri,
                status: CortexStepStatus.from(jsonName: statusName),
                stepCount: stepCount
            )
        }
    }

    public func startCascade(workspaceUri: String, initialPrompt: String, modelId: String) async throws -> String {
        let res = try await callUnaryJSON(
            method: "StartCascade",
            body: [
                "workspaceUris": .array([.string(workspaceUri)]),
                "initialUserInput": .string(initialPrompt),
                "modelId": .string(modelId)
            ]
        )
        guard let cascadeId = res["cascadeId"]?.stringValue else {
            throw AntigravityRPCError.decodingError("Missing cascadeId in StartCascade response")
        }
        return cascadeId
    }

    public func sendUserCascadeMessage(
        cascadeId: String,
        message: String,
        modelId: String,
        effort: ThinkingEffortLevel = .high,
        mode: CascadeExecutionMode = .planning,
        agentPersona: String = "Default"
    ) async throws {
        _ = try await callUnaryJSON(
            method: "SendUserCascadeMessage",
            body: [
                "cascadeId": .string(cascadeId),
                "userResponse": .string(message),
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
        _ = try await callUnaryJSON(
            method: "GetArtifactSnapshots",
            body: ["cascadeId": .string(cascadeId)]
        )
        return []
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
                        if chunkBuffer.count >= 64 {
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
}
