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
    public let resolvedHostname: String?
    public let resolvedInstanceUuid: String?
    public let resolvedAuthUser: String?
    public let availableRelayInstances: [RelayInstanceInfo]

    public init(
        latencyMs: Int,
        workspaces: [WorkspaceInfo],
        summaries: [CascadeSummary],
        serverVersion: String = "v2.32.0",
        resolvedHostname: String? = nil,
        resolvedInstanceUuid: String? = nil,
        resolvedAuthUser: String? = nil,
        availableRelayInstances: [RelayInstanceInfo] = []
    ) {
        self.latencyMs = latencyMs
        self.workspaces = workspaces
        self.summaries = summaries
        self.serverVersion = serverVersion
        self.resolvedHostname = resolvedHostname
        self.resolvedInstanceUuid = resolvedInstanceUuid
        self.resolvedAuthUser = resolvedAuthUser
        self.availableRelayInstances = availableRelayInstances
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

/// Pure Swift 6 Connect-RPC & Google Cloud Relay client for `exa.language_server_pb.LanguageServerService`.
///
/// Connects either to:
/// 1. Official Antigravity Remote Control Relay (`https://antigravity.google.com/r/<instance-id>` via `devtools_jetski_boq_api_proto.ApiService`)
/// 2. Direct LAN / Tailscale `language_server` or Mac Companion Bridge (`https://<host>:<port>`) with `x-codeium-csrf-token`
public actor AntigravityRPCClient {
    public static let servicePrefix = "/exa.language_server_pb.LanguageServerService"
    public static let protobufStepThreshold = 600

    private let channel: RemoteConnectionChannel
    private let endpointURL: URL
    private let relayOriginURL: URL
    private let csrfToken: String?
    private let sessionCookie: String?
    private let explicitAuthUser: String?
    private var authUser: String
    private var targetInstanceIdentifier: String
    private var resolvedInstanceUuid: String?
    private var cachedRelayInstances: [RelayInstanceInfo] = []
    private var cachedCloudProjectsById: [String: ProjectWorkspace] = [:]
    private var cachedValidUpstreamModels: Set<String>?
    private var cachedDefaultUpstreamModel: String?
    private let urlSession: URLSession

    public struct LiveModelCatalogResult: Sendable, Equatable {
        public let models: [CascadeModelConfig]
        public let defaultModelId: String?
        public let agents: [String]

        public init(
            models: [CascadeModelConfig],
            defaultModelId: String? = nil,
            agents: [String] = ["Default"]
        ) {
            self.models = models
            self.defaultModelId = defaultModelId
            self.agents = agents
        }
    }

    private static let companionOnlyMethods: Set<String> = [
        "ListAutomations",
        "CreateAutomation",
        "TriggerAutomationNow",
        "SetAutomationPaused",
        "OpenWorkspaceInFinder",
        "CreateProjectWorkspace",
        "GetTurnDiff",
        "GetArtifactSnapshots",
        "SendPlanReviewComments",
        "RevertDiffHunk",
        "SendDiffReviewComments"
    ]

    public init(
        host: RemoteHostInstance,
        csrfToken: String? = nil,
        sessionCookie: String? = nil,
        authUser: String? = nil,
        resolvedInstanceUuid: String? = nil,
        pinnedFingerprintSHA256: String? = nil,
        urlSession: URLSession? = nil
    ) {
        self.channel = host.channel
        self.endpointURL = host.endpointURL
        let parsedTarget = RemoteHostInstance.parseRemoteControlTarget(host.endpointURL.absoluteString)
        self.relayOriginURL = URL(string: parsedTarget?.relayOrigin ?? SAPISIDHashGenerator.defaultOrigin)
            ?? host.endpointURL
        let extractedId = parsedTarget?.instanceId.isEmpty == false ? parsedTarget!.instanceId : host.instanceId
        self.targetInstanceIdentifier = extractedId
        self.resolvedInstanceUuid = resolvedInstanceUuid
        let effectiveAuthUser = authUser ?? parsedTarget?.authUser
        self.explicitAuthUser = effectiveAuthUser
        self.authUser = effectiveAuthUser ?? "0"
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
        authUser: String? = nil,
        resolvedInstanceUuid: String? = nil,
        pinnedFingerprintSHA256: String? = nil,
        urlSession: URLSession? = nil
    ) {
        let parsedTarget = RemoteHostInstance.parseRemoteControlTarget(baseURL.absoluteString)
        let isRelay = parsedTarget != nil && (csrfToken == nil || csrfToken?.isEmpty == true) && (sessionCookie?.isEmpty == false)
        self.channel = isRelay ? .cloudRelay : .directHost
        self.endpointURL = baseURL
        self.relayOriginURL = URL(string: parsedTarget?.relayOrigin ?? SAPISIDHashGenerator.defaultOrigin) ?? baseURL
        self.targetInstanceIdentifier = parsedTarget?.instanceId ?? ""
        self.resolvedInstanceUuid = resolvedInstanceUuid
        let effectiveAuthUser = authUser ?? parsedTarget?.authUser
        self.explicitAuthUser = effectiveAuthUser
        self.authUser = effectiveAuthUser ?? "0"
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

    // MARK: - Cloud Relay `ApiService/ListInstances` & Instance Resolution

    /// Queries `POST /$rpc/devtools_jetski_boq_api_proto.ApiService/ListInstances` for a given `X-Goog-AuthUser`.
    public func listRelayInstances(
        authUserOverride: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> [RelayInstanceInfo] {
        let activeAuthUser = authUserOverride ?? authUser
        let urlString = "\(SAPISIDHashGenerator.normalizeOrigin(relayOriginURL.absoluteString))\(SAPISIDHashGenerator.apiServicePrefix)/ListInstances"
        guard let url = URL(string: urlString) else {
            throw AntigravityRPCError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }
        SAPISIDHashGenerator.applyApiServiceHeaders(
            to: &request,
            cookieHeader: sessionCookie ?? "",
            origin: relayOriginURL.absoluteString,
            authUser: activeAuthUser
        )
        request.httpBody = CloudRelayJSPBCodec.encodeListInstancesRequest()

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AntigravityRPCError.invalidEndpoint
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            let text = String(data: data, encoding: .utf8) ?? "Google session expired or unauthorized"
            throw AntigravityRPCError.unauthorized(text)
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AntigravityRPCError.httpError(statusCode: http.statusCode, body: text)
        }
        return try CloudRelayJSPBCodec.decodeListInstancesResponse(
            data,
            responseHeaders: http.allHeaderFields
        )
    }

    /// Resolves a scanned Remote Control device slug (`lt74xt6l0m-golden-star`) or UUID (`0f5819ac-...-v2`)
    /// to an online `RelayInstanceInfo`, automatically probing `X-Goog-AuthUser` `0..4` for multi-account sessions.
    public func resolveCloudRelayInstance(
        preferredIdentifier: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> (selected: RelayInstanceInfo, allInstances: [RelayInstanceInfo], matchedAuthUser: String) {
        let rawTarget = (preferredIdentifier ?? targetInstanceIdentifier).trimmingCharacters(in: .whitespacesAndNewlines)
        let isWildcardTarget = rawTarget.isEmpty
            || rawTarget == "r"
            || rawTarget == "auto"
            || rawTarget == "macbook-pro-local"

        var candidateAuthUsers: [String] = []
        if let explicitAuthUser, !explicitAuthUser.isEmpty {
            candidateAuthUsers.append(explicitAuthUser)
        }
        for fallbackIdx in ["0", "1", "2", "3", "4"] where !candidateAuthUsers.contains(fallbackIdx) {
            candidateAuthUsers.append(fallbackIdx)
        }

        var firstNonEmptyResult: (instances: [RelayInstanceInfo], authUser: String)? = nil
        var lastError: Error? = nil

        for candidateUser in candidateAuthUsers {
            do {
                let instances = try await listRelayInstances(
                    authUserOverride: candidateUser,
                    timeoutInterval: timeoutInterval
                )
                if instances.isEmpty {
                    continue
                }
                if firstNonEmptyResult == nil {
                    firstNonEmptyResult = (instances, candidateUser)
                }

                if !isWildcardTarget {
                    if let exactOnline = instances.first(where: { $0.matches(identifier: rawTarget) && $0.status.isReachable })
                        ?? instances.first(where: { $0.matches(identifier: rawTarget) }) {
                        self.authUser = candidateUser
                        self.resolvedInstanceUuid = exactOnline.uuid
                        self.cachedRelayInstances = instances
                        return (exactOnline, instances, candidateUser)
                    }
                } else if let online = instances.first(where: { $0.status.isReachable }) ?? instances.first {
                    self.authUser = candidateUser
                    self.resolvedInstanceUuid = online.uuid
                    self.cachedRelayInstances = instances
                    return (online, instances, candidateUser)
                }
            } catch {
                lastError = error
                if explicitAuthUser != nil && candidateUser == explicitAuthUser {
                    continue
                }
            }
        }

        if let fallback = firstNonEmptyResult, isWildcardTarget,
           let chosen = fallback.instances.first(where: { $0.status.isReachable }) ?? fallback.instances.first {
            self.authUser = fallback.authUser
            self.resolvedInstanceUuid = chosen.uuid
            self.cachedRelayInstances = fallback.instances
            return (chosen, fallback.instances, fallback.authUser)
        }

        if !isWildcardTarget && (rawTarget.hasSuffix("-v2") || rawTarget.count >= 32) {
            let directInfo = RelayInstanceInfo(
                uuid: rawTarget,
                name: rawTarget,
                status: .connected
            )
            self.resolvedInstanceUuid = rawTarget
            let list = firstNonEmptyResult?.instances ?? [directInfo]
            self.cachedRelayInstances = list
            return (directInfo, list, authUser)
        }

        if let firstNonEmptyResult {
            let names = firstNonEmptyResult.instances.map { "\($0.name) (\($0.status.badgeText))" }.joined(separator: ", ")
            throw AntigravityRPCError.httpError(
                statusCode: 404,
                body: "Host '\(rawTarget)' not found among your Google account's instances: [\(names)]"
            )
        }
        if let lastError {
            throw lastError
        }
        throw AntigravityRPCError.unauthorized(
            "No online Antigravity Desktop instances found for this Google account. Ensure Remote Control is enabled on your Mac/PC."
        )
    }

    // MARK: - Handshake & Login Verification

    /// Verifies authentication (`SAPISIDHASH` + `ApiService/ListInstances` + `ProxyCommand`, or `x-codeium-csrf-token`)
    /// and hydrates initial local + Antigravity Cloud workspaces & trajectories across all reachable instances.
    public func verifyConnection(timeoutInterval: TimeInterval = 4.0) async throws -> BackendHandshakeResult {
        let start = Date()
        let effectiveTimeout = (channel == .cloudRelay) ? max(timeoutInterval, 15.0) : timeoutInterval
        var resolvedName: String? = nil
        var serverVersion = "v2.32.0"
        var allRelayInstances: [RelayInstanceInfo] = []

        if channel == .cloudRelay {
            let resolution = try await resolveCloudRelayInstance(
                preferredIdentifier: targetInstanceIdentifier,
                timeoutInterval: effectiveTimeout
            )
            resolvedName = resolution.selected.name
            serverVersion = resolution.selected.version
            allRelayInstances = resolution.allInstances
        }

        let federated = try await fetchFederatedWorkspacesAndSummaries(timeoutInterval: effectiveTimeout)
        let elapsedMs = max(1, Int(Date().timeIntervalSince(start) * 1000.0))
        return BackendHandshakeResult(
            latencyMs: elapsedMs,
            workspaces: federated.workspaces,
            summaries: federated.summaries,
            serverVersion: serverVersion,
            resolvedHostname: resolvedName,
            resolvedInstanceUuid: resolvedInstanceUuid,
            resolvedAuthUser: channel == .cloudRelay ? authUser : nil,
            availableRelayInstances: allRelayInstances
        )
    }

    /// Refreshes `ListInstances` (when on `.cloudRelay`), federates local workspaces & summaries across all
    /// reachable instances on the signed-in Google account, and queries Antigravity Cloud (`BACKEND_TYPE_REMOTE_AICODE`)
    /// projects & conversations so both Cloud ("Antigravity") and Local hosts stay synchronized.
    public func fetchFederatedWorkspacesAndSummaries(
        timeoutInterval: TimeInterval? = nil
    ) async throws -> (workspaces: [WorkspaceInfo], summaries: [CascadeSummary], cloudProjects: [ProjectWorkspace], cloudWarmingUp: Bool) {
        if channel == .cloudRelay {
            if let refreshed = try? await listRelayInstances(timeoutInterval: timeoutInterval), !refreshed.isEmpty {
                self.cachedRelayInstances = refreshed
                if let currentUuid = resolvedInstanceUuid,
                   !refreshed.contains(where: { $0.uuid == currentUuid }),
                   let fallback = refreshed.first(where: { $0.status.isReachable }) ?? refreshed.first {
                    self.resolvedInstanceUuid = fallback.uuid
                }
            }
        }

        let reachableInstances: [RelayInstanceInfo] = {
            guard channel == .cloudRelay else { return [] }
            let reachable = cachedRelayInstances.filter { $0.status.isReachable }
            if !reachable.isEmpty { return reachable }
            if let uuid = resolvedInstanceUuid {
                return [RelayInstanceInfo(uuid: uuid, name: targetInstanceIdentifier.isEmpty ? "Mac" : targetInstanceIdentifier, status: .connected)]
            }
            return []
        }()

        // 1. Fetch Antigravity Cloud (`BACKEND_TYPE_REMOTE_AICODE`) projects
        let cloudProjectOutcome = await fetchCloudProjects(
            candidateInstances: reachableInstances,
            timeoutInterval: timeoutInterval
        )
        let cloudProjects = cloudProjectOutcome.projects

        var mergedWorkspacesByUri: [String: WorkspaceInfo] = [:]
        for cp in cloudProjects {
            mergedWorkspacesByUri[cp.workspaceUri] = WorkspaceInfo(
                workspaceUri: cp.workspaceUri,
                displayName: cp.name,
                activeBranch: cp.activeBranch,
                isCloud: true,
                originInstanceUuid: cp.originInstanceUuid,
                originHostName: "Antigravity"
            )
        }

        var mergedSummariesById: [String: CascadeSummary] = [:]

        if channel == .cloudRelay && !reachableInstances.isEmpty {
            let cloudProjectsSnapshot = self.cachedCloudProjectsById
            var anyInstanceSucceeded = false

            await withTaskGroup(of: (Bool, [WorkspaceInfo], [CascadeSummary], [CascadeSummary]).self) { group in
                for inst in reachableInstances {
                    group.addTask {
                        var instOk = false
                        let ws: [WorkspaceInfo]
                        do {
                            ws = try await self.getWorkspaceInfos(
                                instanceUuidOverride: inst.uuid,
                                originHostName: inst.name,
                                timeoutInterval: timeoutInterval
                            )
                            instOk = true
                        } catch let AntigravityRPCError.httpError(code, _) where code == 404 {
                            ws = []
                            instOk = true
                        } catch {
                            ws = []
                        }

                        let mem: [CascadeSummary]
                        do {
                            mem = try await self.getAllCascadeTrajectories(
                                instanceUuidOverride: inst.uuid,
                                originHostName: inst.name,
                                timeoutInterval: timeoutInterval
                            )
                            instOk = true
                        } catch {
                            mem = []
                        }

                        let jbLocal = await self.fetchJetboxSummariesSnapshot(
                            cloud: false,
                            instanceUuidOverride: inst.uuid,
                            originHostName: inst.name,
                            snapshotTimeout: 3.5
                        )
                        if !jbLocal.isEmpty { instOk = true }
                        return (instOk, ws, mem, jbLocal)
                    }
                }

                for await (instOk, wsList, memList, jbLocalList) in group {
                    if instOk { anyInstanceSucceeded = true }
                    for ws in wsList where mergedWorkspacesByUri[ws.workspaceUri] == nil {
                        mergedWorkspacesByUri[ws.workspaceUri] = ws
                    }
                    for s in memList + jbLocalList {
                        Self.mergeSummaryEntry(s, into: &mergedSummariesById, cloudProjectsById: cloudProjectsSnapshot)
                    }
                }
            }

            // Query Antigravity Cloud (`BACKEND_TYPE_REMOTE_AICODE`) summaries across candidate instances until non-empty
            let updatedCloudProjects = self.cachedCloudProjectsById
            for inst in reachableInstances {
                let cloudSummaries = await fetchJetboxSummariesSnapshot(
                    cloud: true,
                    instanceUuidOverride: inst.uuid,
                    originHostName: "Antigravity",
                    snapshotTimeout: 4.5
                )
                if !cloudSummaries.isEmpty {
                    anyInstanceSucceeded = true
                    for s in cloudSummaries {
                        Self.mergeSummaryEntry(s, into: &mergedSummariesById, cloudProjectsById: updatedCloudProjects)
                    }
                    break
                }
            }

            if !anyInstanceSucceeded && cloudProjects.isEmpty {
                let ws = try await getWorkspaceInfosOptional(timeoutInterval: timeoutInterval)
                let sums = try await getAllCascadeTrajectories(timeoutInterval: timeoutInterval)
                for w in ws { mergedWorkspacesByUri[w.workspaceUri] = w }
                for s in sums { Self.mergeSummaryEntry(s, into: &mergedSummariesById, cloudProjectsById: updatedCloudProjects) }
            }
        } else {
            // Direct LAN / Companion / Mock server mode
            async let workspacesTask = getWorkspaceInfosOptional(timeoutInterval: timeoutInterval)
            async let summariesTask = getAllCascadeTrajectories(timeoutInterval: timeoutInterval)
            let workspaces = try await workspacesTask
            let summaries = try await summariesTask
            let cloudSummaries = await fetchJetboxSummariesSnapshot(
                cloud: true,
                originHostName: "Antigravity",
                snapshotTimeout: 1.5
            )
            let cloudProjectsSnapshot = self.cachedCloudProjectsById
            for w in workspaces where mergedWorkspacesByUri[w.workspaceUri] == nil {
                mergedWorkspacesByUri[w.workspaceUri] = w
            }
            for s in summaries + cloudSummaries {
                Self.mergeSummaryEntry(s, into: &mergedSummariesById, cloudProjectsById: cloudProjectsSnapshot)
            }
        }

        let sortedSummaries = mergedSummariesById.values.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.cascadeId < rhs.cascadeId
        }
        let sortedWorkspaces = Array(mergedWorkspacesByUri.values).sorted { $0.displayName < $1.displayName }
        return (sortedWorkspaces, sortedSummaries, cloudProjects, cloudProjectOutcome.warmingUp)
    }

    private static func mergeSummaryEntry(
        _ incoming: CascadeSummary,
        into map: inout [String: CascadeSummary],
        cloudProjectsById: [String: ProjectWorkspace]
    ) {
        var resolved = incoming
        if let cpid = resolved.cloudProjectId, !cpid.isEmpty, let cp = cloudProjectsById[cpid] {
            resolved.isCloud = true
            resolved.projectSlug = cp.name
            resolved.workspaceUri = cp.workspaceUri
            resolved.originHostName = "Antigravity"
        }
        if let existing = map[resolved.cascadeId] {
            if existing.title != "New Conversation" && resolved.title == "New Conversation" {
                resolved.title = existing.title
            }
            if existing.originInstanceUuid != nil && resolved.originInstanceUuid == nil {
                resolved.originInstanceUuid = existing.originInstanceUuid
                resolved.originHostName = existing.originHostName
            }
            if resolved.stepCount >= existing.stepCount || resolved.updatedAt >= existing.updatedAt {
                map[resolved.cascadeId] = resolved
            }
        } else {
            map[resolved.cascadeId] = resolved
        }
    }

    private func getWorkspaceInfosOptional(timeoutInterval: TimeInterval?) async throws -> [WorkspaceInfo] {
        do {
            return try await getWorkspaceInfos(timeoutInterval: timeoutInterval)
        } catch let AntigravityRPCError.httpError(statusCode, _) where statusCode == 404 {
            return []
        } catch {
            if channel == .cloudRelay {
                return []
            }
            throw error
        }
    }

    // MARK: - Core Unary RPC (`Sendable` JSONValue & Binary Protobuf)

    public func callUnaryJSON(
        method: String,
        body: [String: JSONValue] = [:],
        instanceUuidOverride: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> [String: JSONValue] {
        if channel == .cloudRelay {
            let relayTimeout = timeoutInterval.map { max($0, 10.0) }
            return try await callCloudRelayUnaryJSON(
                method: method,
                body: body,
                instanceUuidOverride: instanceUuidOverride,
                timeoutInterval: relayTimeout
            )
        }

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

    private func callCloudRelayUnaryJSON(
        method: String,
        body: [String: JSONValue],
        instanceUuidOverride: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> [String: JSONValue] {
        if Self.companionOnlyMethods.contains(method) {
            if method == "ListAutomations" {
                return ["automations": .array([])]
            }
            if method == "GetArtifactSnapshots" {
                return ["artifacts": .array([])]
            }
            if method == "GetTurnDiff" {
                return ["files": .array([])]
            }
            return ["ok": .bool(true)]
        }

        var workingBody = try await sanitizeCloudRelayPayload(method: method, body: body)
        for attempt in 1...3 {
            let encodedPayload = workingBody.isEmpty ? Data("{}".utf8) : try JSONEncoder().encode(workingBody)
            let (respData, _) = try await callCloudRelayProxyCommand(
                method: method,
                payload: encodedPayload,
                contentType: "application/json",
                instanceUuidOverride: instanceUuidOverride,
                timeoutInterval: timeoutInterval
            )
            if respData.isEmpty {
                return [:]
            }
            if let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: respData) {
                if let code = decoded["code"]?.stringValue,
                   let message = decoded["message"]?.stringValue,
                   decoded.count <= 3 {
                    if attempt < 3, let unknownField = Self.extractUnknownProtoFieldName(from: message),
                       workingBody[unknownField] != nil {
                        workingBody.removeValue(forKey: unknownField)
                        continue
                    }
                    throw AntigravityRPCError.httpError(statusCode: 400, body: "\(code): \(message)")
                }
                return decoded
            }
            let rawText = String(data: respData, encoding: .utf8) ?? ""
            if attempt < 3, let unknownField = Self.extractUnknownProtoFieldName(from: rawText),
               workingBody[unknownField] != nil {
                workingBody.removeValue(forKey: unknownField)
                continue
            }
            throw AntigravityRPCError.decodingError("Expected JSON object from Cloud Relay \(method)")
        }
        return [:]
    }

    private func callCloudRelayProxyCommand(
        method: String,
        payload: Data,
        contentType: String,
        instanceUuidOverride: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> (payload: Data, headers: [String: String]) {
        if instanceUuidOverride == nil && resolvedInstanceUuid == nil {
            _ = try await resolveCloudRelayInstance(
                preferredIdentifier: targetInstanceIdentifier,
                timeoutInterval: timeoutInterval
            )
        }
        let effectiveUuid = (instanceUuidOverride?.isEmpty == false) ? instanceUuidOverride : resolvedInstanceUuid
        guard let targetUuid = effectiveUuid, !targetUuid.isEmpty else {
            throw AntigravityRPCError.invalidEndpoint
        }

        let originStr = SAPISIDHashGenerator.normalizeOrigin(relayOriginURL.absoluteString)
        guard var comps = URLComponents(string: "\(originStr)\(SAPISIDHashGenerator.apiServicePrefix)/ProxyCommand") else {
            throw AntigravityRPCError.invalidEndpoint
        }
        comps.queryItems = [URLQueryItem(name: "$unique", value: method)]
        guard let url = comps.url else {
            throw AntigravityRPCError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let timeoutInterval {
            request.timeoutInterval = timeoutInterval
        }
        SAPISIDHashGenerator.applyApiServiceHeaders(
            to: &request,
            cookieHeader: sessionCookie ?? "",
            origin: originStr,
            authUser: authUser,
            isStreaming: false
        )
        request.httpBody = try CloudRelayJSPBCodec.encodeProxyCommandRequest(
            targetInstanceUuid: targetUuid,
            rpcPath: "\(Self.servicePrefix)/\(method)",
            payload: payload,
            contentType: contentType,
            isStreaming: false
        )

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
        return try CloudRelayJSPBCodec.decodeProxyCommandResponse(
            data,
            responseHeaders: http.allHeaderFields
        )
    }

    private func sanitizeCloudRelayPayload(
        method: String,
        body: [String: JSONValue]
    ) async throws -> [String: JSONValue] {
        let desktopMetadata: JSONValue = .object([
            "ideName": .string("antigravity"),
            "extensionName": .string("antigravity"),
            "locale": .string("en")
        ])

        switch method {
        case "StartCascade":
            var clean: [String: JSONValue] = [
                "metadata": desktopMetadata,
                "source": .string("CORTEX_TRAJECTORY_SOURCE_CASCADE_CLIENT")
            ]
            if let cid = body["cascadeId"]?.stringValue, !cid.isEmpty {
                clean["cascadeId"] = .string(cid)
            }
            if let backend = body["backend"]?.stringValue, !backend.isEmpty {
                clean["backend"] = .string(backend)
            }
            if let projEnv = body["projectEnvConfig"] {
                clean["projectEnvConfig"] = projEnv
            } else if let uris = body["workspaceUris"], uris.arrayValue?.isEmpty == false {
                clean["workspaceUris"] = uris
            }
            return clean

        case "SendUserCascadeMessage":
            var cleanItems: [JSONValue] = []
            if let rawItems = body["items"]?.arrayValue {
                for entry in rawItems {
                    guard let obj = entry.objectValue else { continue }
                    if let text = obj["text"]?.stringValue {
                        cleanItems.append(.object(["text": .string(text)]))
                    } else if let absUri = obj["item"]?.objectValue?["file"]?.objectValue?["absoluteUri"]?.stringValue,
                              absUri.hasPrefix("file://") {
                        cleanItems.append(
                            .object([
                                "item": .object([
                                    "file": .object(["absoluteUri": .string(absUri)])
                                ])
                            ])
                        )
                    }
                }
            }
            if cleanItems.isEmpty, let fallbackText = body["userResponse"]?.stringValue, !fallbackText.isEmpty {
                cleanItems.append(.object(["text": .string(fallbackText)]))
            }

            var clean: [String: JSONValue] = [
                "cascadeId": body["cascadeId"] ?? .string(""),
                "items": .array(cleanItems),
                "metadata": desktopMetadata
            ]

            if var cascadeCfg = body["cascadeConfig"]?.objectValue,
               var plannerCfg = cascadeCfg["plannerConfig"]?.objectValue {
                // Ensure conversational.plannerMode is ALWAYS valid upstream enum (`CONVERSATIONAL_PLANNER_MODE_DEFAULT`)
                if var convObj = plannerCfg["conversational"]?.objectValue {
                    let rawMode = convObj["plannerMode"]?.stringValue ?? ""
                    if rawMode != "CONVERSATIONAL_PLANNER_MODE_DEFAULT" && rawMode != "CONVERSATIONAL_PLANNER_MODE_READ_ONLY" {
                        convObj["plannerMode"] = .string("CONVERSATIONAL_PLANNER_MODE_DEFAULT")
                    }
                    plannerCfg["conversational"] = .object(convObj)
                }

                let reqModelObj = plannerCfg["requestedModel"]?.objectValue
                let requestedModel = reqModelObj?["model"]?.stringValue ?? reqModelObj?["alias"]?.stringValue ?? ""
                let isAlias = (reqModelObj?["alias"]?.stringValue != nil)
                let (defaultModel, validModels) = await ensureUpstreamModelCatalog()

                if !validModels.isEmpty && !validModels.contains(requestedModel) {
                    if let defaultModel, !defaultModel.isEmpty {
                        plannerCfg["requestedModel"] = .object(["model": .string(defaultModel)])
                        if plannerCfg["planModel"] != nil && defaultModel.hasPrefix("MODEL_") {
                            plannerCfg["planModel"] = .string(defaultModel)
                        }
                    } else {
                        plannerCfg.removeValue(forKey: "requestedModel")
                        plannerCfg.removeValue(forKey: "planModel")
                    }
                } else if validModels.isEmpty && !isAlias && (!requestedModel.hasPrefix("MODEL_") || requestedModel.contains(" ")) {
                    if let defaultModel, !defaultModel.isEmpty {
                        plannerCfg["requestedModel"] = .object(["model": .string(defaultModel)])
                    } else {
                        plannerCfg.removeValue(forKey: "requestedModel")
                        plannerCfg.removeValue(forKey: "planModel")
                    }
                }
                cascadeCfg["plannerConfig"] = .object(plannerCfg)
                clean["cascadeConfig"] = .object(cascadeCfg)
            }
            return clean

        case "HandleCascadeUserInteraction":
            guard var interaction = body["interaction"]?.objectValue else {
                return body
            }
            if var rc = interaction["runCommand"]?.objectValue {
                if rc["confirm"]?.boolValue == true && rc["faceIdVerified"]?.boolValue == false {
                    throw AntigravityRPCError.unauthorized("Face ID verification required before approving command")
                }
                rc.removeValue(forKey: "faceIdVerified")
                interaction["runCommand"] = .object(rc)
            }
            return ["interaction": .object(interaction)]

        default:
            return body
        }
    }

    private func ensureUpstreamModelCatalog() async -> (defaultModel: String?, validModels: Set<String>) {
        if let cachedValidUpstreamModels {
            return (cachedDefaultUpstreamModel, cachedValidUpstreamModels)
        }
        let result = await fetchModelCatalog()
        if let cachedValidUpstreamModels {
            return (cachedDefaultUpstreamModel, cachedValidUpstreamModels)
        }
        let ids = Set(result.models.map(\.modelId).filter { $0.hasPrefix("MODEL_") })
        return (result.defaultModelId, ids)
    }

    /// Queries the connected `language_server` / `agy` daemon for its live model & custom agent catalog
    /// via `GetCascadeModelConfigs`, `GetCascadeModelConfigData`, `GetAvailableModels`, and `GetAllCustomAgentConfigs`.
    public func fetchModelCatalog() async -> LiveModelCatalogResult {
        var parsedModels: [CascadeModelConfig] = []
        var validIds = Set<String>()
        var defaultModelId: String? = nil

        let metaReq: [String: JSONValue] = [
            "metadata": .object([
                "ideName": .string("antigravity"),
                "extensionName": .string("antigravity"),
                "locale": .string("en")
            ])
        ]
        for method in ["GetCascadeModelConfigs", "GetCascadeModelConfigData"] {
            if let obj = try? await callUnaryJSON(method: method, body: metaReq, timeoutInterval: 8.0),
               let configs = obj["clientModelConfigs"]?.arrayValue,
               !configs.isEmpty {
                for entry in configs {
                    guard let cfg = entry.objectValue else { continue }
                    if cfg["disabled"]?.boolValue == true { continue }
                    let label = (cfg["label"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !label.isEmpty else { continue }
                    let moa = cfg["modelOrAlias"]?.objectValue
                    let rawModel = moa?["model"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let rawAlias = moa?["alias"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let isAlias = (rawModel == nil || rawModel == "MODEL_UNSPECIFIED" || rawModel?.isEmpty == true) && (rawAlias?.isEmpty == false)
                    guard let modelId = isAlias ? rawAlias : rawModel,
                          !modelId.isEmpty,
                          modelId != "MODEL_UNSPECIFIED",
                          !validIds.contains(modelId) else {
                        continue
                    }
                    validIds.insert(modelId)

                    let lowerLabel = label.lowercased()
                    let supportsThinking = (cfg["supportsThoughtCirculation"]?.boolValue ?? false)
                        || (cfg["supportsThinking"]?.boolValue ?? false)
                        || lowerLabel.contains("thinking")
                        || lowerLabel.contains("pro")
                        || lowerLabel.contains("opus")
                    let effort: ThinkingEffortLevel = lowerLabel.contains("(low)") ? .low : (lowerLabel.contains("flash") ? .medium : .high)
                    let quotaPart: String? = {
                        if let rem = cfg["quotaInfo"]?.objectValue?["remainingFraction"]?.doubleValue {
                            return "\(Int((rem * 100.0).rounded()))% quota left"
                        }
                        return nil
                    }()
                    let desc = Self.nonEmptyString(cfg["description"]?.stringValue)
                        ?? Self.nonEmptyString(cfg["tagTitle"]?.stringValue)
                        ?? quotaPart
                        ?? Self.defaultSubtitle(forModelLabel: label)

                    parsedModels.append(
                        CascadeModelConfig(
                            modelId: modelId,
                            displayName: label,
                            subtitle: desc,
                            hasThinkingBadge: supportsThinking,
                            requiresUpgradeNote: nil,
                            mode: .planning,
                            agentPersona: "Default",
                            effort: effort,
                            isModelAlias: isAlias
                        )
                    )
                    if cfg["isRecommended"]?.boolValue == true && defaultModelId == nil {
                        defaultModelId = modelId
                    }
                }
                let overrideMoa = obj["defaultOverrideModelConfig"]?.objectValue?["modelOrAlias"]?.objectValue
                if let defM = Self.nonEmptyString(overrideMoa?["model"]?.stringValue), defM != "MODEL_UNSPECIFIED" {
                    defaultModelId = defM
                } else if let defA = Self.nonEmptyString(overrideMoa?["alias"]?.stringValue) {
                    defaultModelId = defA
                }
                if !parsedModels.isEmpty {
                    break
                }
            }
        }

        if parsedModels.isEmpty,
           let availWrapper = try? await callUnaryJSON(
               method: "GetAvailableModels",
               body: ["forceRefresh": .bool(false)],
               timeoutInterval: 8.0
           ) {
            let resp = availWrapper["response"]?.objectValue ?? availWrapper
            if let modelsMap = resp["models"]?.objectValue, !modelsMap.isEmpty {
                var orderedKeys: [String] = []
                let sorts = resp["agentModelSorts"]?.arrayValue ?? resp["battleModeModelSorts"]?.arrayValue ?? []
                for sort in sorts {
                    for grp in sort.objectValue?["groups"]?.arrayValue ?? [] {
                        for midVal in grp.objectValue?["modelIds"]?.arrayValue ?? [] {
                            if let mid = Self.nonEmptyString(midVal.stringValue), !orderedKeys.contains(mid) {
                                orderedKeys.append(mid)
                            }
                        }
                    }
                }
                if orderedKeys.isEmpty {
                    orderedKeys = modelsMap.keys.sorted()
                }
                for key in orderedKeys {
                    guard let details = modelsMap[key]?.objectValue else { continue }
                    if details["disabled"]?.boolValue == true || details["isInternal"]?.boolValue == true {
                        continue
                    }
                    let displayName = Self.nonEmptyString(details["displayName"]?.stringValue) ?? key
                    let protoEnum = Self.nonEmptyString(details["model"]?.stringValue)
                    let modelId = (protoEnum != nil && protoEnum != "MODEL_UNSPECIFIED") ? protoEnum! : key
                    guard !validIds.contains(modelId) else { continue }
                    validIds.insert(modelId)

                    let lowerLabel = displayName.lowercased()
                    let supportsThinking = (details["supportsThinking"]?.boolValue ?? false)
                        || lowerLabel.contains("thinking")
                    let effort: ThinkingEffortLevel = lowerLabel.contains("(low)") ? .low : (lowerLabel.contains("flash") ? .medium : .high)
                    let subtitle = Self.nonEmptyString(details["description"]?.stringValue)
                        ?? Self.defaultSubtitle(forModelLabel: displayName)

                    parsedModels.append(
                        CascadeModelConfig(
                            modelId: modelId,
                            displayName: displayName,
                            subtitle: subtitle,
                            hasThinkingBadge: supportsThinking,
                            requiresUpgradeNote: nil,
                            mode: .planning,
                            agentPersona: "Default",
                            effort: effort,
                            isModelAlias: !modelId.hasPrefix("MODEL_")
                        )
                    )
                }
            }
        }

        if !validIds.isEmpty {
            self.cachedValidUpstreamModels = validIds
            self.cachedDefaultUpstreamModel = defaultModelId ?? parsedModels.first?.modelId
        } else {
            self.cachedValidUpstreamModels = []
            self.cachedDefaultUpstreamModel = nil
        }

        var agents: [String] = ["Default"]
        if let agentResp = try? await callUnaryJSON(method: "GetAllCustomAgentConfigs", body: [:], timeoutInterval: 5.0) {
            let rawAgents = agentResp["customAgentConfigs"]?.arrayValue
                ?? agentResp["agents"]?.arrayValue
                ?? agentResp["configs"]?.arrayValue
                ?? []
            for item in rawAgents {
                if let name = Self.nonEmptyString(item.objectValue?["name"]?.stringValue)
                    ?? Self.nonEmptyString(item.objectValue?["displayName"]?.stringValue)
                    ?? Self.nonEmptyString(item.objectValue?["id"]?.stringValue),
                   !agents.contains(name) {
                    agents.append(name)
                }
            }
        }

        let finalModels = parsedModels.isEmpty ? CascadeModelConfig.liveDefaultCatalog : parsedModels
        return LiveModelCatalogResult(
            models: finalModels,
            defaultModelId: defaultModelId ?? finalModels.first?.modelId,
            agents: agents
        )
    }

    private static func defaultSubtitle(forModelLabel label: String) -> String {
        let lower = label.lowercased()
        if lower.contains("flash") {
            return "Fastest responses and lightweight edits"
        }
        if lower.contains("opus") {
            return "Frontier Anthropic reasoning for complex architecture"
        }
        if lower.contains("sonnet") {
            return "Balanced Anthropic coding & reasoning"
        }
        if lower.contains("(low)") {
            return "Faster Pro reasoning for everyday coding"
        }
        return "Deep reasoning for long, multi-step tasks"
    }

    // MARK: - Antigravity Cloud (`BACKEND_TYPE_REMOTE_AICODE`) Projects & Summaries

    /// Lists and reads Antigravity Cloud ("Remote Agents") projects via `ListProjects` + `ReadProject`.
    public func fetchCloudProjects(
        candidateInstances: [RelayInstanceInfo] = [],
        timeoutInterval: TimeInterval? = nil
    ) async -> (projects: [ProjectWorkspace], warmingUp: Bool) {
        let targetUuids: [String?] = {
            if channel == .cloudRelay && !candidateInstances.isEmpty {
                return candidateInstances.map { Optional($0.uuid) }
            }
            return [nil]
        }()

        var sawWarmingUp = false
        for targetUuid in targetUuids {
            do {
                let listResp = try await callUnaryJSON(
                    method: "ListProjects",
                    body: ["backend": .string("BACKEND_TYPE_REMOTE_AICODE")],
                    instanceUuidOverride: targetUuid,
                    timeoutInterval: timeoutInterval ?? 8.0
                )
                let ids = listResp["projectIds"]?.arrayValue?.compactMap(\.stringValue).filter { !$0.isEmpty } ?? []
                guard !ids.isEmpty else { continue }

                var loaded: [ProjectWorkspace] = []
                for pid in ids {
                    if let readResp = try? await callUnaryJSON(
                        method: "ReadProject",
                        body: ["id": .string(pid)],
                        instanceUuidOverride: targetUuid,
                        timeoutInterval: timeoutInterval ?? 8.0
                    ),
                    let projObj = readResp["project"]?.objectValue {
                        let parsed = Self.decodeCloudProjectObject(projObj, fallbackId: pid, originInstanceUuid: targetUuid)
                        cachedCloudProjectsById[parsed.id] = parsed
                        loaded.append(parsed)
                    }
                }
                if !loaded.isEmpty {
                    return (loaded, false)
                }
            } catch let AntigravityRPCError.httpError(_, body) {
                let lower = body.lowercased()
                if lower.contains("failed_precondition") || lower.contains("not enabled") || lower.contains("precondition") {
                    sawWarmingUp = true
                }
            } catch {
                continue
            }
        }
        return ([], sawWarmingUp)
    }

    private static func decodeCloudProjectObject(
        _ projObj: [String: JSONValue],
        fallbackId: String,
        originInstanceUuid: String?
    ) -> ProjectWorkspace {
        let pid = nonEmptyString(projObj["id"]?.stringValue) ?? fallbackId
        let name = nonEmptyString(projObj["name"]?.stringValue) ?? "Antigravity Cloud"
        let resources = projObj["projectResources"]?.objectValue?["resources"]?.arrayValue ?? []
        var repoDisplay: String? = nil
        for resEntry in resources {
            if let rr = resEntry.objectValue?["remoteResource"]?.objectValue {
                if let dn = nonEmptyString(rr["displayName"]?.stringValue)
                    ?? nonEmptyString(rr["name"]?.stringValue)
                    ?? nonEmptyString(rr["uri"]?.stringValue) {
                    repoDisplay = dn
                        .replacingOccurrences(of: "https://github.com/", with: "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    break
                }
            }
        }
        let cloudSlug = repoDisplay ?? name
        let workspaceUri = "cloud://\(cloudSlug)"
        return ProjectWorkspace(
            id: pid,
            name: name,
            pathDisplay: workspaceUri,
            workspaceUri: workspaceUri,
            runtime: .cloud,
            hostName: "Antigravity",
            activeBranch: "main",
            cloudProjectId: pid,
            originInstanceUuid: originInstanceUuid
        )
    }

    /// Queries connected GitHub repositories available to Antigravity Cloud (`ListAvailableResources`).
    public func fetchCloudGitHubRepos() async -> [GitHubRepoItem] {
        guard let resp = try? await callUnaryJSON(
            method: "ListAvailableResources",
            body: [
                "backend": .string("BACKEND_TYPE_REMOTE_AICODE"),
                "type": .string("github")
            ],
            timeoutInterval: 8.0
        ),
        let resources = resp["resources"]?.arrayValue else {
            return []
        }
        return resources.compactMap { entry -> GitHubRepoItem? in
            guard let obj = entry.objectValue else { return nil }
            guard let fullName = Self.nonEmptyString(obj["displayName"]?.stringValue)
                ?? Self.nonEmptyString(obj["name"]?.stringValue) else {
                return nil
            }
            let branch = Self.nonEmptyString(obj["defaultBranch"]?.stringValue) ?? "main"
            return GitHubRepoItem(
                fullName: fullName,
                defaultBranch: branch,
                visibilityLabel: obj["isPrivate"]?.boolValue == true ? "Private" : "GitHub"
            )
        }
    }

    /// Reads the initial snapshot frame emitted by `JetboxSubscribeToSummaries` (either local or `BACKEND_TYPE_REMOTE_AICODE` Cloud)
    /// and closes the temporary stream immediately.
    public func fetchJetboxSummariesSnapshot(
        cloud: Bool,
        instanceUuidOverride: String? = nil,
        originHostName: String? = nil,
        snapshotTimeout: TimeInterval = 4.0
    ) async -> [CascadeSummary] {
        let reqPayload: [String: JSONValue] = cloud
            ? ["backend": .string("BACKEND_TYPE_REMOTE_AICODE")]
            : [:]
        guard let stream = try? subscribeEnvelopeStream(
            method: "JetboxSubscribeToSummaries",
            requestPayload: reqPayload,
            instanceUuidOverride: instanceUuidOverride
        ) else {
            return []
        }

        let cloudProjectsSnapshot = self.cachedCloudProjectsById
        return await withTaskGroup(of: [CascadeSummary]?.self) { group in
            group.addTask {
                do {
                    for try await event in stream {
                        let parsed = Self.decodeJetboxSummariesEvent(
                            event,
                            forceCloud: cloud,
                            originInstanceUuid: instanceUuidOverride,
                            originHostName: originHostName,
                            cloudProjectsById: cloudProjectsSnapshot
                        )
                        return parsed.upserts
                    }
                } catch {}
                return []
            }
            group.addTask {
                let ns = UInt64(max(0.5, snapshotTimeout) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? []
        }
    }

    /// Decodes a `JetboxSubscribeToSummariesResponse` (`updates` map + `deletes` array, or mock `summaries` / `delta`).
    public static func decodeJetboxSummariesEvent(
        _ event: [String: JSONValue],
        forceCloud: Bool = false,
        originInstanceUuid: String? = nil,
        originHostName: String? = nil,
        cloudProjectsById: [String: ProjectWorkspace] = [:]
    ) -> (upserts: [CascadeSummary], deletes: [String]) {
        let now = Date()
        var upserts: [CascadeSummary] = []
        let deletes = event["deletes"]?.arrayValue?.compactMap(\.stringValue) ?? []

        if let updatesMap = event["updates"]?.objectValue {
            for (cid, val) in updatesMap {
                if let obj = val.objectValue,
                   obj["killed"]?.boolValue == true,
                   (obj["status"]?.stringValue ?? "").contains("UNSPECIFIED") {
                    continue
                }
                if var summary = Self.decodeTrajectorySummaryEntry(cascadeId: cid, value: val, now: now) {
                    if forceCloud {
                        summary.isCloud = true
                        summary.originHostName = "Antigravity"
                    } else {
                        summary.originHostName = originHostName
                    }
                    summary.originInstanceUuid = originInstanceUuid
                    if let cpid = summary.cloudProjectId, let cp = cloudProjectsById[cpid] {
                        summary.isCloud = true
                        summary.projectSlug = cp.name
                        summary.workspaceUri = cp.workspaceUri
                        summary.originHostName = "Antigravity"
                    }
                    upserts.append(summary)
                }
            }
        } else if let summariesArr = event["summaries"]?.arrayValue {
            for val in summariesArr {
                guard let cid = val.objectValue?["cascadeId"]?.stringValue else { continue }
                if var summary = Self.decodeTrajectorySummaryEntry(cascadeId: cid, value: val, now: now) {
                    if forceCloud { summary.isCloud = true }
                    summary.originInstanceUuid = originInstanceUuid
                    summary.originHostName = originHostName
                    upserts.append(summary)
                }
            }
        }
        return (upserts, deletes)
    }

    private static func extractUnknownProtoFieldName(from message: String) -> String? {
        guard let markerRange = message.range(of: "unknown field \"") else { return nil }
        let rest = message[markerRange.upperBound...]
        guard let endQuote = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<endQuote])
    }

    /// Wakes a dormant disk trajectory into `language_server` memory (`LoadTrajectory`).
    public func loadTrajectory(
        cascadeId: String,
        instanceUuidOverride: String? = nil
    ) async throws {
        _ = try await callUnaryJSON(
            method: "LoadTrajectory",
            body: ["cascadeId": .string(cascadeId)],
            instanceUuidOverride: instanceUuidOverride,
            timeoutInterval: 8.0
        )
    }

    /// Fetches trajectory steps, automatically switching from JSON (`0..<600`) to Binary Protobuf (`>=600`).
    public func fetchTrajectorySteps(
        cascadeId: String,
        startIndex: Int = 0,
        endIndex: Int = 200,
        instanceUuidOverride: String? = nil
    ) async throws -> [CascadeStep] {
        if endIndex >= Self.protobufStepThreshold {
            return try await fetchTrajectoryStepsProtobuf(
                cascadeId: cascadeId,
                startIndex: startIndex,
                endIndex: endIndex,
                instanceUuidOverride: instanceUuidOverride
            )
        }
        return try await fetchTrajectoryStepsJSON(
            cascadeId: cascadeId,
            startIndex: startIndex,
            endIndex: endIndex,
            instanceUuidOverride: instanceUuidOverride
        )
    }

    /// Fetches the complete trajectory for a live session using upstream `GetCascadeTrajectoryStepsRequest`
    /// (`cascade_id` + optional `step_offset`, waking dormant sessions via `LoadTrajectory` if needed)
    /// and switches to Binary Protobuf (`application/proto`) when `knownStepCount >= 600` or truncated.
    public func fetchAllTrajectorySteps(
        cascadeId: String,
        knownStepCount: Int = 0,
        instanceUuidOverride: String? = nil
    ) async throws -> [CascadeStep] {
        if knownStepCount >= Self.protobufStepThreshold {
            let protoSteps = try await fetchTrajectoryStepsProtobuf(
                cascadeId: cascadeId,
                startIndex: 0,
                endIndex: knownStepCount,
                instanceUuidOverride: instanceUuidOverride
            )
            if protoSteps.isEmpty && knownStepCount > 0 {
                try? await loadTrajectory(cascadeId: cascadeId, instanceUuidOverride: instanceUuidOverride)
                return try await fetchTrajectoryStepsProtobuf(
                    cascadeId: cascadeId,
                    startIndex: 0,
                    endIndex: knownStepCount,
                    instanceUuidOverride: instanceUuidOverride
                )
            }
            return protoSteps
        }

        var firstResp = try await callUnaryJSON(
            method: "GetCascadeTrajectorySteps",
            body: ["cascadeId": .string(cascadeId)],
            instanceUuidOverride: instanceUuidOverride
        )
        if firstResp["truncatedAt"] != nil {
            return try await fetchTrajectoryStepsProtobuf(
                cascadeId: cascadeId,
                startIndex: 0,
                endIndex: max(knownStepCount, Self.protobufStepThreshold),
                instanceUuidOverride: instanceUuidOverride
            )
        }

        var rawSteps = firstResp["steps"]?.arrayValue ?? []
        if rawSteps.isEmpty && knownStepCount > 0 {
            try? await loadTrajectory(cascadeId: cascadeId, instanceUuidOverride: instanceUuidOverride)
            firstResp = try await callUnaryJSON(
                method: "GetCascadeTrajectorySteps",
                body: ["cascadeId": .string(cascadeId)],
                instanceUuidOverride: instanceUuidOverride
            )
            if firstResp["truncatedAt"] != nil {
                return try await fetchTrajectoryStepsProtobuf(
                    cascadeId: cascadeId,
                    startIndex: 0,
                    endIndex: max(knownStepCount, Self.protobufStepThreshold),
                    instanceUuidOverride: instanceUuidOverride
                )
            }
            rawSteps = firstResp["steps"]?.arrayValue ?? []
        }

        if rawSteps.count >= 590 {
            if let protoSteps = try? await fetchTrajectoryStepsProtobuf(
                cascadeId: cascadeId,
                startIndex: 0,
                endIndex: max(knownStepCount, rawSteps.count),
                instanceUuidOverride: instanceUuidOverride
            ), protoSteps.count >= rawSteps.count {
                return protoSteps
            }
        }

        var seenIndices = Set<Int>()
        var collected: [CascadeStep] = []
        for (idxOffset, item) in rawSteps.enumerated() {
            if let step = Self.decodeJSONStep(item, cascadeId: cascadeId, fallbackIndex: idxOffset) {
                if seenIndices.insert(step.stepIndex).inserted {
                    collected.append(step)
                }
            }
        }

        var offset = rawSteps.count
        while offset > 0 && offset < knownStepCount && offset < Self.protobufStepThreshold {
            let pageResp = try await callUnaryJSON(
                method: "GetCascadeTrajectorySteps",
                body: [
                    "cascadeId": .string(cascadeId),
                    "stepOffset": .int(offset)
                ],
                instanceUuidOverride: instanceUuidOverride
            )
            guard let pageSteps = pageResp["steps"]?.arrayValue, !pageSteps.isEmpty else {
                break
            }
            var addedNew = false
            for (idxOffset, item) in pageSteps.enumerated() {
                if let step = Self.decodeJSONStep(item, cascadeId: cascadeId, fallbackIndex: offset + idxOffset) {
                    if seenIndices.insert(step.stepIndex).inserted {
                        collected.append(step)
                        addedNew = true
                    }
                }
            }
            if !addedNew {
                break
            }
            offset += pageSteps.count
        }

        return collected.sorted { $0.stepIndex < $1.stepIndex }
    }

    /// Fetches trajectory steps over JSON (`GetCascadeTrajectorySteps`) for conversations under 600 steps.
    /// Supports both native Desktop `language_server` step JSON (`stepOffset`) and companion/mock step schemas.
    public func fetchTrajectoryStepsJSON(
        cascadeId: String,
        startIndex: Int = 0,
        endIndex: Int = 200,
        instanceUuidOverride: String? = nil
    ) async throws -> [CascadeStep] {
        var body: [String: JSONValue] = ["cascadeId": .string(cascadeId)]
        if startIndex > 0 {
            body["stepOffset"] = .int(startIndex)
        }
        let res = try await callUnaryJSON(
            method: "GetCascadeTrajectorySteps",
            body: body,
            instanceUuidOverride: instanceUuidOverride
        )
        if res["truncatedAt"] != nil {
            return try await fetchTrajectoryStepsProtobuf(
                cascadeId: cascadeId,
                startIndex: startIndex,
                endIndex: max(endIndex, Self.protobufStepThreshold),
                instanceUuidOverride: instanceUuidOverride
            )
        }
        guard let rawSteps = res["steps"]?.arrayValue else { return [] }
        return rawSteps.enumerated().compactMap { offset, item in
            Self.decodeJSONStep(item, cascadeId: cascadeId, fallbackIndex: startIndex + offset)
        }
    }

    /// Fetches trajectory steps using binary Protobuf (`application/proto`) to bypass the 600-step JSON ceiling.
    public func fetchTrajectoryStepsProtobuf(
        cascadeId: String,
        startIndex: Int,
        endIndex: Int,
        instanceUuidOverride: String? = nil
    ) async throws -> [CascadeStep] {
        let protoReqBytes = ProtobufStepCodec.encodeGetStepsRequest(
            cascadeId: cascadeId,
            startIndex: startIndex,
            endIndex: endIndex
        )
        if channel == .cloudRelay {
            let (respBytes, _) = try await callCloudRelayProxyCommand(
                method: "GetCascadeTrajectorySteps",
                payload: protoReqBytes,
                contentType: "application/proto",
                instanceUuidOverride: instanceUuidOverride
            )
            return ProtobufStepCodec.decodeStepsResponse(respBytes, cascadeId: cascadeId)
        }

        let url = endpointURL.appendingPathComponent("\(Self.servicePrefix)/GetCascadeTrajectorySteps")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/proto", forHTTPHeaderField: "Content-Type")
        request.setValue("application/proto", forHTTPHeaderField: "Accept")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        applyAuthHeaders(to: &request)
        request.httpBody = protoReqBytes

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AntigravityRPCError.httpError(statusCode: status, body: "Binary step fetch failed")
        }
        return ProtobufStepCodec.decodeStepsResponse(data, cascadeId: cascadeId)
    }

    // MARK: - Workspace & Project Operations (`UE01`, `UE04`, `UE05`)

    public func getWorkspaceInfos(
        instanceUuidOverride: String? = nil,
        originHostName: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> [WorkspaceInfo] {
        let res = try await callUnaryJSON(
            method: "GetWorkspaceInfos",
            instanceUuidOverride: instanceUuidOverride,
            timeoutInterval: timeoutInterval
        )
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
                isCloud: isCloud,
                originInstanceUuid: instanceUuidOverride ?? resolvedInstanceUuid,
                originHostName: isCloud ? "Antigravity" : originHostName
            )
        }
    }

    public func createProjectWorkspace(draft: NewProjectDraft) async throws -> ProjectWorkspace {
        let repoName = draft.selectedRepo?.fullName ?? draft.projectName
        if channel == .cloudRelay && draft.runsOn == .cloud {
            let newProjectId = UUID().uuidString.lowercased()
            var projectObj: [String: JSONValue] = [
                "id": .string(newProjectId),
                "name": .string(draft.projectName),
                "backendType": .string("BACKEND_TYPE_REMOTE_AICODE")
            ]
            if let repo = draft.selectedRepo {
                projectObj["projectResources"] = .object([
                    "resources": .array([
                        .object([
                            "remoteResource": .object([
                                "type": .string("github"),
                                "name": .string(repo.fullName),
                                "displayName": .string(repo.fullName)
                            ])
                        ])
                    ])
                ])
            }
            let res = try await callUnaryJSON(
                method: "CreateProject",
                body: [
                    "backend": .string("BACKEND_TYPE_REMOTE_AICODE"),
                    "project": .object(projectObj)
                ]
            )
            let returnedProj = res["project"]?.objectValue
            let finalId = Self.nonEmptyString(returnedProj?["id"]?.stringValue) ?? newProjectId
            let finalName = Self.nonEmptyString(returnedProj?["name"]?.stringValue) ?? draft.projectName
            let cloudUri = "cloud://\(repoName)"
            let created = ProjectWorkspace(
                id: finalId,
                name: finalName,
                pathDisplay: cloudUri,
                workspaceUri: cloudUri,
                runtime: .cloud,
                hostName: "Antigravity",
                activeBranch: draft.selectedRepo?.defaultBranch ?? "main",
                cloudProjectId: finalId,
                originInstanceUuid: resolvedInstanceUuid
            )
            cachedCloudProjectsById[finalId] = created
            return created
        }

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
            hostName: draft.runsOn == .cloud ? "Antigravity" : draft.runsOn.rawValue,
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
    public func getAllCascadeTrajectories(
        instanceUuidOverride: String? = nil,
        originHostName: String? = nil,
        timeoutInterval: TimeInterval? = nil
    ) async throws -> [CascadeSummary] {
        let res = try await callUnaryJSON(
            method: "GetAllCascadeTrajectories",
            instanceUuidOverride: instanceUuidOverride,
            timeoutInterval: timeoutInterval
        )
        let now = Date()
        let cloudMap = self.cachedCloudProjectsById
        let effectiveUuid = instanceUuidOverride ?? resolvedInstanceUuid

        // Format A: Native Desktop `language_server` map `{"trajectorySummaries": {"<cascadeId>": {...}}}`
        if let summaryMap = res["trajectorySummaries"]?.objectValue {
            let decoded = summaryMap.compactMap { cascadeId, value -> CascadeSummary? in
                guard var s = Self.decodeTrajectorySummaryEntry(cascadeId: cascadeId, value: value, now: now) else {
                    return nil
                }
                s.originInstanceUuid = effectiveUuid
                s.originHostName = s.isCloud ? "Antigravity" : originHostName
                if let cpid = s.cloudProjectId, let cp = cloudMap[cpid] {
                    s.isCloud = true
                    s.projectSlug = cp.name
                    s.workspaceUri = cp.workspaceUri
                    s.originHostName = "Antigravity"
                }
                return s
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
                || (obj["cloud"]?.boolValue ?? false)
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
                isCloud: isCloud,
                originInstanceUuid: effectiveUuid,
                originHostName: isCloud ? "Antigravity" : originHostName
            )
        }
    }

    public static func normalizeProtoModelEnum(_ modelId: String) -> String {
        let trimmed = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("MODEL_") {
            return trimmed
        }
        let lower = trimmed.lowercased()
        if lower.contains("flash") {
            return "MODEL_PLACEHOLDER_M18"
        }
        if lower.contains("sonnet") {
            return "MODEL_PLACEHOLDER_M35"
        }
        if lower.contains("opus") {
            return "MODEL_PLACEHOLDER_M26"
        }
        if lower.contains("low") {
            return "MODEL_PLACEHOLDER_M36"
        }
        if lower.contains("gemini") || lower.contains("pro") {
            return "MODEL_PLACEHOLDER_M37"
        }
        return "MODEL_PLACEHOLDER_M37"
    }

    /// Creates a new Cascade session (`StartCascade`) on either Local or Antigravity Cloud (`BACKEND_TYPE_REMOTE_AICODE`).
    public func startCascade(
        workspaceUri: String,
        initialPrompt: String = "",
        modelId: String = "MODEL_PLACEHOLDER_M37",
        cloudProjectId: String? = nil,
        instanceUuidOverride: String? = nil
    ) async throws -> String {
        let protoModel = Self.normalizeProtoModelEnum(modelId)
        let clientCid = UUID().uuidString.lowercased()
        var payload: [String: JSONValue] = [
            "cascadeId": .string(clientCid),
            "metadata": .object([
                "ideName": .string("antigravity-ios"),
                "ideVersion": .string("2.0.0")
            ]),
            "modelId": .string(protoModel)
        ]
        if let cloudProjectId, !cloudProjectId.isEmpty {
            payload["backend"] = .string("BACKEND_TYPE_REMOTE_AICODE")
            payload["projectEnvConfig"] = .object([
                "projectId": .string(cloudProjectId),
                "defaultProjectEnvironment": .object([:])
            ])
        } else {
            payload["workspaceUris"] = .array([.string(workspaceUri)])
        }
        if !initialPrompt.isEmpty {
            payload["initialUserInput"] = .string(initialPrompt)
        }
        let res = try await callUnaryJSON(
            method: "StartCascade",
            body: payload,
            instanceUuidOverride: instanceUuidOverride
        )
        if let returnedId = Self.nonEmptyString(res["cascadeId"]?.stringValue) {
            return returnedId
        }
        return clientCid
    }

    /// Sends a user prompt + `@file` context items + model/mode config (`SendUserCascadeMessage`).
    /// Encodes `Planning` vs `Fast` via `conversational.agenticMode` (`CONVERSATIONAL_PLANNER_MODE_DEFAULT`)
    /// and sets `planModel` alongside `requestedModel` for Antigravity Cloud (`BACKEND_TYPE_REMOTE_AICODE`) sessions.
    public func sendUserCascadeMessage(
        cascadeId: String,
        message: String,
        attachments: [ComposerAttachmentChip] = [],
        modelId: String,
        effort: ThinkingEffortLevel = .high,
        mode: CascadeExecutionMode = .planning,
        agentPersona: String = "Default",
        isModelAlias: Bool = false,
        isCloud: Bool = false,
        instanceUuidOverride: String? = nil
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

        let protoModel = Self.normalizeProtoModelEnum(modelId)
        let requestedModelPayload: JSONValue = isModelAlias
            ? .object(["alias": .string(modelId)])
            : .object(["model": .string(protoModel)])

        var plannerConfig: [String: JSONValue] = [
            "conversational": .object([
                "plannerMode": .string("CONVERSATIONAL_PLANNER_MODE_DEFAULT"),
                "agenticMode": .bool(mode == .planning)
            ]),
            "requestedModel": requestedModelPayload
        ]
        if (isCloud || cascadeId.hasPrefix("v1/")) && !isModelAlias && protoModel.hasPrefix("MODEL_") {
            plannerConfig["planModel"] = .string(protoModel)
        }

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
                    "plannerConfig": .object(plannerConfig)
                ]),
                "modelConfig": .object([
                    "modelId": .string(modelId),
                    "thinkingEffort": .string(effort.rawValue.uppercased()),
                    "mode": .string(mode.rawValue.uppercased()),
                    "agentPersona": .string(agentPersona)
                ])
            ],
            instanceUuidOverride: instanceUuidOverride
        )
    }

    public func handleCascadeUserInteraction(
        _ payload: CascadeUserInteractionPayload,
        instanceUuidOverride: String? = nil
    ) async throws {
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
            body: ["interaction": .object(interactionObj)],
            instanceUuidOverride: instanceUuidOverride
        )
    }

    public func handleCascadeUserInteraction(
        step: CascadeStep,
        decision: InteractionDecision,
        instanceUuidOverride: String? = nil
    ) async throws {
        guard let payload = InteractionBuilder.buildPayload(step: step, decision: decision) else {
            throw AntigravityRPCError.interactionRejected
        }
        try await handleCascadeUserInteraction(payload, instanceUuidOverride: instanceUuidOverride)
    }

    public func cancelCascadeInvocation(
        cascadeId: String,
        instanceUuidOverride: String? = nil
    ) async throws {
        _ = try await callUnaryJSON(
            method: "CancelCascadeInvocation",
            body: ["cascadeId": .string(cascadeId)],
            instanceUuidOverride: instanceUuidOverride
        )
    }

    public func pinCascade(
        cascadeId: String,
        isPinned: Bool,
        instanceUuidOverride: String? = nil
    ) async throws {
        if channel == .cloudRelay {
            _ = try await callUnaryJSON(
                method: "UpdateConversationAnnotations",
                body: [
                    "cascadeId": .string(cascadeId),
                    "annotations": .object(["pinned": .bool(isPinned)]),
                    "mergeAnnotations": .bool(true)
                ],
                instanceUuidOverride: instanceUuidOverride
            )
            return
        }
        _ = try await callUnaryJSON(
            method: "PinCascade",
            body: [
                "cascadeId": .string(cascadeId),
                "isPinned": .bool(isPinned)
            ],
            instanceUuidOverride: instanceUuidOverride
        )
    }

    public func renameCascade(
        cascadeId: String,
        newTitle: String,
        instanceUuidOverride: String? = nil
    ) async throws {
        if channel == .cloudRelay {
            _ = try await callUnaryJSON(
                method: "UpdateConversationAnnotations",
                body: [
                    "cascadeId": .string(cascadeId),
                    "annotations": .object(["title": .string(newTitle)]),
                    "mergeAnnotations": .bool(true)
                ],
                instanceUuidOverride: instanceUuidOverride
            )
            return
        }
        _ = try await callUnaryJSON(
            method: "RenameCascade",
            body: [
                "cascadeId": .string(cascadeId),
                "title": .string(newTitle)
            ],
            instanceUuidOverride: instanceUuidOverride
        )
    }

    public func moveCascadeToWorkspace(
        cascadeId: String,
        workspaceUri: String,
        instanceUuidOverride: String? = nil
    ) async throws {
        _ = try await callUnaryJSON(
            method: "MoveCascadeToWorkspace",
            body: [
                "cascadeId": .string(cascadeId),
                "workspaceUri": .string(workspaceUri)
            ],
            instanceUuidOverride: instanceUuidOverride
        )
    }

    public func archiveCascade(
        cascadeId: String,
        isArchived: Bool = true,
        instanceUuidOverride: String? = nil
    ) async throws {
        if channel == .cloudRelay {
            _ = try await callUnaryJSON(
                method: "UpdateConversationAnnotations",
                body: [
                    "cascadeId": .string(cascadeId),
                    "annotations": .object(["archived": .bool(isArchived)]),
                    "mergeAnnotations": .bool(true)
                ],
                instanceUuidOverride: instanceUuidOverride
            )
            return
        }
        _ = try await callUnaryJSON(
            method: "ArchiveCascade",
            body: [
                "cascadeId": .string(cascadeId),
                "isArchived": .bool(isArchived)
            ],
            instanceUuidOverride: instanceUuidOverride
        )
    }

    public func deleteCascade(
        cascadeId: String,
        instanceUuidOverride: String? = nil
    ) async throws {
        if channel == .cloudRelay {
            _ = try await callUnaryJSON(
                method: "DeleteCascadeTrajectory",
                body: ["cascadeId": .string(cascadeId)],
                instanceUuidOverride: instanceUuidOverride
            )
            return
        }
        _ = try await callUnaryJSON(
            method: "DeleteCascade",
            body: ["cascadeId": .string(cascadeId)],
            instanceUuidOverride: instanceUuidOverride
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
        requestPayload: [String: JSONValue] = [:],
        instanceUuidOverride: String? = nil
    ) throws -> AsyncThrowingStream<[String: JSONValue], Error> {
        let rawJSON = requestPayload.isEmpty ? Data("{}".utf8) : try JSONEncoder().encode(requestPayload)
        let framedPayload = ConnectEnvelopeFrame(flags: [], payload: rawJSON).encode()

        if channel == .cloudRelay {
            let effectiveUuid = (instanceUuidOverride?.isEmpty == false) ? instanceUuidOverride : resolvedInstanceUuid
            guard let targetUuid = effectiveUuid, !targetUuid.isEmpty else {
                return AsyncThrowingStream { continuation in
                    continuation.finish()
                }
            }
            let originStr = SAPISIDHashGenerator.normalizeOrigin(relayOriginURL.absoluteString)
            guard var comps = URLComponents(string: "\(originStr)\(SAPISIDHashGenerator.apiServicePrefix)/StreamProxyCommand") else {
                throw AntigravityRPCError.invalidEndpoint
            }
            comps.queryItems = [URLQueryItem(name: "$unique", value: "\(method)-\(UUID().uuidString.prefix(8))")]
            guard let relayURL = comps.url else {
                throw AntigravityRPCError.invalidEndpoint
            }
            var relayRequest = URLRequest(url: relayURL)
            relayRequest.httpMethod = "POST"
            SAPISIDHashGenerator.applyApiServiceHeaders(
                to: &relayRequest,
                cookieHeader: sessionCookie ?? "",
                origin: originStr,
                authUser: authUser,
                isStreaming: true
            )
            relayRequest.httpBody = try CloudRelayJSPBCodec.encodeProxyCommandRequest(
                targetInstanceUuid: targetUuid,
                rpcPath: "\(Self.servicePrefix)/\(method)",
                payload: framedPayload,
                contentType: "application/connect+json",
                isStreaming: true
            )

            let session = self.urlSession
            let immutableRelayReq = relayRequest
            return AsyncThrowingStream { continuation in
                let task = Task {
                    do {
                        let (bytes, response) = try await session.bytes(for: immutableRelayReq)
                        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                            continuation.finish()
                            return
                        }
                        let decoder = JSONDecoder()
                        var jspbStreamParser = CloudRelayJSPBStreamParser()
                        var connectParser = ConnectStreamParser()
                        for try await byte in bytes {
                            if let chunks = jspbStreamParser.feedByte(byte) {
                                for chunkData in chunks {
                                    if chunkData.first == UInt8(ascii: "{"),
                                       let obj = try? decoder.decode([String: JSONValue].self, from: chunkData) {
                                        continuation.yield(obj)
                                    } else {
                                        for frame in connectParser.feed(chunkData) {
                                            if frame.flags.contains(.endStream) {
                                                continuation.finish()
                                                return
                                            }
                                            if let obj = try? decoder.decode([String: JSONValue].self, from: frame.payload) {
                                                continuation.yield(obj)
                                            }
                                        }
                                    }
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

        let url = endpointURL.appendingPathComponent("\(Self.servicePrefix)/\(method)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/connect+json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        applyAuthHeaders(to: &request)
        request.httpBody = framedPayload

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
        var recordedMode: CascadeExecutionMode?
        var recordedModelId: String?

        if let uiObj = obj["userInput"]?.objectValue {
            let itemsJoined = uiObj["items"]?.arrayValue?
                .compactMap { nonEmptyString($0.objectValue?["text"]?.stringValue) }
                .joined(separator: "\n")
            userText = nonEmptyString(uiObj["userResponse"]?.stringValue)
                ?? nonEmptyString(uiObj["query"]?.stringValue)
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
            if let userCfg = (uiObj["userConfig"] ?? uiObj["lastUserConfig"])?.objectValue,
               let plannerCfg = userCfg["plannerConfig"]?.objectValue {
                if let convObj = plannerCfg["conversational"]?.objectValue {
                    if let agentic = convObj["agenticMode"]?.boolValue {
                        recordedMode = agentic ? .planning : .fast
                    }
                }
                let reqModelObj = plannerCfg["requestedModel"]?.objectValue
                recordedModelId = nonEmptyString(reqModelObj?["model"]?.stringValue)
                    ?? nonEmptyString(reqModelObj?["alias"]?.stringValue)
                    ?? nonEmptyString(plannerCfg["planModel"]?.stringValue)
                if recordedModelId == "MODEL_UNSPECIFIED" {
                    recordedModelId = nil
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
                let paths = (nu["pathsToReview"]?.arrayValue ?? nu["reviewAbsoluteUris"]?.arrayValue)?
                    .compactMap(\.stringValue) ?? []
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

        let createdDate = Self.parseProtoTimestamp(obj["metadata"]?.objectValue?["createdAt"] ?? obj["createdAt"]) ?? Date()

        return CascadeStep(
            cascadeId: cascadeId,
            stepIndex: stepIndex,
            type: stepType,
            status: stepStatus,
            createdAt: createdDate,
            userInput: userText,
            attachedMentions: mentions,
            plannerResponse: plannerPayload,
            taskBoundary: taskBoundaryPayload,
            runCommand: runCmdPayload,
            codeAction: codeActionPayload,
            viewFile: viewFilePayload,
            search: searchPayload,
            requestedInteraction: interaction,
            recordedExecutionMode: recordedMode,
            recordedModelId: recordedModelId
        )
    }

    // MARK: - Live Desktop Summary & Timestamp Helpers

    /// Decodes a single entry from `GetAllCascadeTrajectories.trajectorySummaries` or `JetboxSubscribeToSummaries.updates`,
    /// filtering out blank 0-step unused Desktop tabs and computing accurate Cloud/local/unread/status fields.
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

        let trajMeta = obj["trajectoryMetadata"]?.objectValue
        let cloudProjectId = Self.nonEmptyString(trajMeta?["projectId"]?.stringValue)
            ?? Self.nonEmptyString(obj["projectId"]?.stringValue)
        let explicitCloudBool = (obj["cloud"]?.boolValue == true)
            || (obj["isCloud"]?.boolValue == true)
            || (trajMeta?["isCloud"]?.boolValue == true)

        // Antigravity Desktop keeps unused 0-step local New Chat placeholders in `trajectorySummaries`
        // without a title/summary and hides them in its sidebar. Filter them out cleanly (unless Cloud session).
        if resolvedTitle == nil && stepCount == 0 && !explicitCloudBool {
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
        let metaWorkspaceUri = trajMeta?["workspaceUris"]?.arrayValue?.compactMap(\.stringValue).first {
            let trimmed = $0.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return !trimmed.isEmpty && trimmed != "file:///home/antigravity"
        }
        let rawUri = selectedWorkspace?["workspaceFolderAbsoluteUri"]?.stringValue
            ?? selectedWorkspace?["workspaceUri"]?.stringValue
            ?? metaWorkspaceUri
            ?? obj["workspaceUri"]?.stringValue
            ?? (explicitCloudBool ? "cloud://\(cloudProjectId ?? "antigravity-cloud")" : "file:///Users/wl/code/workspace")

        let sourceHint = [
            obj["source"]?.stringValue,
            obj["runtime"]?.stringValue,
            obj["backend"]?.stringValue,
            trajMeta?["runtime"]?.stringValue,
            trajMeta?["environment"]?.stringValue,
            trajMeta?["executionEnvironment"]?.stringValue,
            trajMeta?["source"]?.stringValue
        ]
            .compactMap { $0 }
            .joined(separator: " ")

        let isCloud = explicitCloudBool
            || AntigravityCloudDetector.isCloudWorkspaceURI(rawUri, cascadeId: cascadeId, sourceHint: sourceHint)
        let uri = AntigravityCloudDetector.normalizeWorkspaceURI(rawUri, isCloud: isCloud)

        let explicitSlug = obj["projectSlug"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let slug: String
        if let explicitSlug, !explicitSlug.isEmpty {
            slug = explicitSlug
        } else if rawUri.hasPrefix("cloud://") {
            let trimmedCloud = rawUri.replacingOccurrences(of: "cloud://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let lastComp = (trimmedCloud as NSString).lastPathComponent
            slug = lastComp.isEmpty ? (trimmedCloud.isEmpty ? "Antigravity Cloud" : trimmedCloud) : lastComp
        } else if rawUri.hasPrefix("https://github.com/") {
            let trimmedGH = rawUri.replacingOccurrences(of: "https://github.com/", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let lastComp = (trimmedGH as NSString).lastPathComponent
            slug = lastComp.isEmpty ? "github-workspace" : lastComp
        } else if rawUri.contains("://") && !rawUri.hasPrefix("file://") {
            let decodedRaw = rawUri.removingPercentEncoding ?? rawUri
            let lastComp = ((URL(string: decodedRaw)?.path ?? decodedRaw) as NSString).lastPathComponent
            slug = lastComp.isEmpty ? "Antigravity Cloud" : lastComp
        } else {
            let cleanPath = (rawUri.removingPercentEncoding ?? rawUri)
                .replacingOccurrences(of: "file://", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let lastComp = (cleanPath as NSString).lastPathComponent
            if (!lastComp.isEmpty && lastComp != "workspace" && lastComp != "antigravity") || cloudProjectId == nil {
                slug = lastComp.isEmpty ? (isCloud ? "Antigravity Cloud" : "workspace") : lastComp
            } else {
                slug = cloudProjectId ?? (isCloud ? "Antigravity Cloud" : "workspace")
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
            isCloud: isCloud,
            cloudProjectId: cloudProjectId,
            originHostName: isCloud ? "Antigravity" : nil
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
