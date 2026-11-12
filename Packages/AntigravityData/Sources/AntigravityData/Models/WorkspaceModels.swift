import Foundation

// MARK: - Top-Level Navigation, ESDD Scene & Filter Enumerations

/// Primary bottom Liquid Glass navigation tab (`UE01`, `UE06`).
public enum PrimaryTab: String, Codable, CaseIterable, Sendable, Identifiable {
    case agents = "Agents"
    case automations = "Automations"
    case settings = "Settings"

    public var id: String { rawValue }
}

/// Deterministic ESDD verification scene identifiers (`UE01` .. `UE13`).
public enum ESDDVerifySceneCase: String, Codable, CaseIterable, Sendable, Identifiable {
    case agentsHome = "UE01_AGENTS_HOME"
    case displayOptions = "UE02_DISPLAY_OPTIONS"
    case contextMenuPin = "UE03_CONTEXT_MENU_PIN"
    case projectDetail = "UE04_PROJECT_DETAIL"
    case createProject = "UE05_CREATE_PROJECT"
    case automations = "UE06_AUTOMATIONS"
    case chatAndComposer = "UE07_CHAT_AND_COMPOSER"
    case addContext = "UE08_ADD_CONTEXT"
    case modelAndMode = "UE09_MODEL_AND_MODE"
    case structuredQuestion = "UE10_STRUCTURED_QUESTION"
    case planReview = "UE11_PLAN_REVIEW"
    case turnDiffReview = "UE12_TURN_DIFF_REVIEW"
    case liveActivitySpec = "UE13_LIVE_ACTIVITY_SPEC"

    public var id: String { rawValue }
}

/// Quick filter pills on `AgentsHomeViewController` (`UE01`).
public enum AgentsQuickFilter: String, Codable, CaseIterable, Sendable, Identifiable {
    case all = "All"
    case running = "Running"
    case needsYou = "Needs you"
    case unread = "Unread"

    public var id: String { rawValue }
}

/// Grouping dimension in `DisplayOptionsSheetView` (`UE02`).
public enum DisplayGroupBy: String, Codable, CaseIterable, Sendable, Identifiable {
    case project = "Project"
    case host = "Host"
    case none = "None"

    public var id: String { rawValue }
}

/// Conversation sort field in `DisplayOptionsSheetView` (`UE02`).
public enum ConversationSortField: String, Codable, CaseIterable, Sendable, Identifiable {
    case lastUpdated = "Last Updated"
    case dateCreated = "Date Created"
    case title = "Title"

    public var id: String { rawValue }
}

/// Persisted display & sorting preferences for `AgentsHomeViewController` (`UE02`).
public struct AgentDisplayOptions: Codable, Sendable, Equatable {
    public var groupBy: DisplayGroupBy
    public var sortBy: ConversationSortField
    public var newestFirst: Bool
    public var sortProjectsOrder: String
    public var filterScopeLabel: String
    public var densityLabel: String
    public var autoPinOnMessage: Bool
    public var archivedOnly: Bool

    public init(
        groupBy: DisplayGroupBy = .project,
        sortBy: ConversationSortField = .lastUpdated,
        newestFirst: Bool = true,
        sortProjectsOrder: String = "Custom Order",
        filterScopeLabel: String = "All conversations",
        densityLabel: String = "Comfortable · Previews",
        autoPinOnMessage: Bool = false,
        archivedOnly: Bool = false
    ) {
        self.groupBy = groupBy
        self.sortBy = sortBy
        self.newestFirst = newestFirst
        self.sortProjectsOrder = sortProjectsOrder
        self.filterScopeLabel = filterScopeLabel
        self.densityLabel = densityLabel
        self.autoPinOnMessage = autoPinOnMessage
        self.archivedOnly = archivedOnly
    }

    public var sortAscending: Bool {
        get { !newestFirst }
        set { newestFirst = !newValue }
    }
}

/// Execution host target for a project (`UE01`, `UE04`, `UE05`).
public enum ProjectRuntimeTarget: String, Codable, CaseIterable, Sendable, Identifiable {
    case macBookPro = "MacBook Pro"
    case cloud = "Cloud"

    public var id: String { rawValue }

    public var descriptionText: String {
        switch self {
        case .macBookPro:
            return "Runs locally on your paired MacBook Pro with direct filesystem access."
        case .cloud:
            return "Runs in its own cloud VM and keeps working while your computer sleeps."
        }
    }
}

/// Repository or folder source when creating a project (`UE05`).
public enum ProjectSourceKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case githubRepo = "GitHub repository"
    case driveFolder = "Drive folder"

    public var id: String { rawValue }
}

/// Underline section tab in `ProjectDetailViewController` (`UE04`).
public enum ProjectDetailTab: String, Codable, CaseIterable, Sendable, Identifiable {
    case active = "Active"
    case archived = "Archived"
    case automations = "Automations"

    public var id: String { rawValue }
}

/// GitHub repository candidate row in `CreateProjectSheetView` (`UE05`).
public struct GitHubRepoItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var fullName: String
    public var visibilityLabel: String
    public var defaultBranch: String

    public init(
        id: String,
        fullName: String,
        visibilityLabel: String,
        defaultBranch: String = "main"
    ) {
        self.id = id
        self.fullName = fullName
        self.visibilityLabel = visibilityLabel
        self.defaultBranch = defaultBranch
    }

    public static let sampleCatalog: [GitHubRepoItem] = [
        GitHubRepoItem(
            id: "repo-ledger-svc",
            fullName: "acme/ledger-svc",
            visibilityLabel: "Private · Go · updated 2h ago",
            defaultBranch: "main"
        ),
        GitHubRepoItem(
            id: "repo-web-console",
            fullName: "acme/web-console",
            visibilityLabel: "Private · TypeScript · updated 1d ago",
            defaultBranch: "main"
        ),
        GitHubRepoItem(
            id: "repo-design-tokens",
            fullName: "acme/design-tokens",
            visibilityLabel: "Public · updated 5d ago",
            defaultBranch: "main"
        )
    ]
}

/// Draft form state for `CreateProjectSheetView` (`UE05`).
public struct NewProjectDraft: Codable, Sendable, Equatable {
    public var runsOn: ProjectRuntimeTarget
    public var source: ProjectSourceKind
    public var repoSearchQuery: String
    public var selectedRepo: GitHubRepoItem?
    public var branchWorktree: String
    public var projectName: String

    public init(
        runsOn: ProjectRuntimeTarget = .cloud,
        source: ProjectSourceKind = .githubRepo,
        repoSearchQuery: String = "",
        selectedRepo: GitHubRepoItem? = GitHubRepoItem.sampleCatalog.first,
        branchWorktree: String = "main · New worktree",
        projectName: String = "ledger-svc-cloud"
    ) {
        self.runsOn = runsOn
        self.source = source
        self.repoSearchQuery = repoSearchQuery
        self.selectedRepo = selectedRepo
        self.branchWorktree = branchWorktree
        self.projectName = projectName
    }
}

/// Pure Swift 6 detector & URI normalizer for Antigravity Cloud VM (`Jetski Remote Agents`),
/// GitHub Cloud Projects (`cloud://`, `vscode-vfs://`), and Remote-SSH / Tunnel / Devbox workspaces (`vscode-remote://`).
public enum AntigravityCloudDetector {
    public static let cloudURIPrefixes: [String] = [
        "cloud://",
        "https://github.com/",
        "http://github.com/",
        "vscode-remote://",
        "vscode-vfs://",
        "ssh://",
        "remote://",
        "jetski://",
        "antigravity-cloud://",
        "antigravity-remote://",
        "devbox://",
        "codespace://"
    ]

    public static let genericContainerRoots: Set<String> = [
        "/home/antigravity",
        "/workspace",
        "/workspaces",
        "/root"
    ]

    public static func isCloudWorkspaceURI(
        _ rawURI: String,
        cascadeId: String = "",
        sourceHint: String = ""
    ) -> Bool {
        let cid = cascadeId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cid.hasPrefix("v1/") || cid.contains("jetski_remote_agents") || cid.contains("remote_agent") {
            return true
        }
        let src = sourceHint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if src.contains("cloud") || src.contains("remote") || src.contains("jetski") || src.contains("github") {
            return true
        }
        let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
        let decoded = (trimmed.removingPercentEncoding ?? trimmed)
        let lower = decoded.lowercased()
        if cloudURIPrefixes.contains(where: { lower.hasPrefix($0) }) {
            return true
        }
        if decoded == "file:///home/antigravity" || decoded.hasPrefix("file:///home/antigravity/") {
            return true
        }
        return false
    }

    public static func normalizeWorkspaceURI(_ rawURI: String, isCloud: Bool) -> String {
        let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return isCloud ? "cloud://workspace" : "" }
        let decoded = (trimmed.removingPercentEncoding ?? trimmed)
        let lower = decoded.lowercased()

        if lower.hasPrefix("https://github.com/") || lower.hasPrefix("http://github.com/") {
            let prefixLen = lower.hasPrefix("https://") ? "https://github.com/".count : "http://github.com/".count
            var tail = String(decoded.dropFirst(prefixLen)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if tail.hasSuffix(".git") {
                tail = String(tail.dropLast(4))
            }
            let parts = tail.split(separator: "/").map(String.init)
            if parts.count >= 2 {
                return "cloud://\(parts[0])/\(parts[1])"
            }
            return tail.isEmpty ? "cloud://github" : "cloud://\(tail)"
        }

        if lower.hasPrefix("vscode-vfs://") {
            if let url = URL(string: decoded) {
                let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
                if parts.count >= 2 {
                    return "cloud://\(parts[0])/\(parts[1])"
                }
            }
            return trimmed
        }

        if decoded == "file:///home/antigravity" || decoded.hasPrefix("file:///home/antigravity/") {
            let suffix = String(decoded.dropFirst("file:///home/antigravity".count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let parts = suffix.split(separator: "/").map(String.init)
            if parts.count >= 2 {
                return "cloud://\(parts[0])/\(parts[1])"
            }
            if let first = parts.first, !first.isEmpty {
                return "cloud://\(first)"
            }
            return "cloud://antigravity"
        }

        if isCloud && decoded.hasPrefix("file://") {
            let fsPath = String(decoded.dropFirst("file://".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let parts = fsPath.split(separator: "/").map(String.init)
            if let slug = parts.last, !slug.isEmpty {
                return "cloud://\(slug)"
            }
            return "cloud://workspace"
        }

        return trimmed
    }

    public static func extractCloudLocationLabel(_ workspaceUri: String) -> String? {
        let decoded = (workspaceUri.removingPercentEncoding ?? workspaceUri)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = decoded.lowercased()
        if lower.hasPrefix("cloud://") {
            let tail = String(decoded.dropFirst("cloud://".count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !tail.isEmpty, tail != "workspace", tail != "antigravity" else { return nil }
            return tail
        }
        if lower.hasPrefix("https://github.com/") || lower.hasPrefix("http://github.com/") {
            let norm = normalizeWorkspaceURI(decoded, isCloud: true)
            return extractCloudLocationLabel(norm)
        }
        if lower.hasPrefix("vscode-remote://") {
            let afterScheme = String(decoded.dropFirst("vscode-remote://".count))
            if let authority = afterScheme.split(separator: "/").first, !authority.isEmpty {
                return String(authority)
            }
        }
        return nil
    }
}

/// Represents a local or cloud project workspace group (`UE01`, `UE04`, `UE05`).
public struct ProjectWorkspace: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var pathDisplay: String
    public var workspaceUri: String
    public var runtime: ProjectRuntimeTarget
    public var hostName: String
    public var activeBranch: String
    public var worktrees: [String]
    public var isExpandedInHome: Bool
    public var rulesAndSkillsCount: Int

    public init(
        id: String,
        name: String,
        pathDisplay: String,
        workspaceUri: String,
        runtime: ProjectRuntimeTarget = .macBookPro,
        hostName: String = "MacBook Pro",
        activeBranch: String = "main",
        worktrees: [String] = ["main"],
        isExpandedInHome: Bool = true,
        rulesAndSkillsCount: Int = 4
    ) {
        self.id = id
        self.name = name
        self.pathDisplay = pathDisplay
        self.workspaceUri = workspaceUri
        self.runtime = runtime
        self.hostName = hostName
        self.activeBranch = activeBranch
        self.worktrees = worktrees
        self.isExpandedInHome = isExpandedInHome
        self.rulesAndSkillsCount = rulesAndSkillsCount
    }

    public var homeSubtitle: String {
        homeSubtitle(isHostOnline: true)
    }

    public func homeSubtitle(isHostOnline: Bool) -> String {
        switch runtime {
        case .macBookPro:
            let statePrefix = isHostOnline ? "Local" : "Offline"
            return "\(statePrefix) · \(hostName) · \(activeBranch)"
        case .cloud:
            if let cloudLabel = AntigravityCloudDetector.extractCloudLocationLabel(workspaceUri),
               cloudLabel.caseInsensitiveCompare(name) != .orderedSame {
                return "Cloud · \(cloudLabel) · \(activeBranch)"
            }
            return "Cloud · \(activeBranch)"
        }
    }

    public var runtimeBadgeText: String {
        switch runtime {
        case .macBookPro:
            return "Local · \(hostName)"
        case .cloud:
            return "Cloud VM"
        }
    }
}

// MARK: - Remote Host & Workspace Info

/// Connection transport channel for Antigravity Remote Control.
public enum RemoteConnectionChannel: String, Codable, Sendable, CaseIterable {
    /// Connects via `https://antigravity.google.com/r/<instance-id>` QR link & Google OAuth session.
    case cloudRelay
    /// Connects directly to local/Tailscale `language_server` HTTPS port with `x-codeium-csrf-token`.
    case directHost

    public var displayName: String {
        switch self {
        case .cloudRelay: return "Google Cloud Relay"
        case .directHost: return "Direct LAN / Tailscale"
        }
    }
}

/// Represents a paired Antigravity Desktop or Cloud VM host instance.
public struct RemoteHostInstance: Codable, Sendable, Equatable, Identifiable {
    public var id: String { instanceId }
    public var instanceId: String
    public var hostname: String
    public var version: String
    public var channel: RemoteConnectionChannel
    public var endpointURL: URL
    public var isOnline: Bool
    public var latencyMs: Int
    public var certificateFingerprintSHA256: String

    public init(
        instanceId: String,
        hostname: String,
        version: String = "v2.32.0",
        channel: RemoteConnectionChannel = .cloudRelay,
        endpointURL: URL,
        isOnline: Bool = true,
        latencyMs: Int = 18,
        certificateFingerprintSHA256: String = "SHA256:9F:86:D0:81:88:4C:7D:65:9A:2F:EA:A0:C5:5A:D0:15"
    ) {
        self.instanceId = instanceId
        self.hostname = hostname
        self.version = version
        self.channel = channel
        self.endpointURL = endpointURL
        self.isOnline = isOnline
        self.latencyMs = latencyMs
        self.certificateFingerprintSHA256 = certificateFingerprintSHA256
    }

    /// Structured result from parsing an official Antigravity Remote Control QR URL or device identifier.
    public struct ParsedRemoteControlTarget: Sendable, Equatable {
        public var instanceId: String
        public var conversationId: String?
        public var authUser: String?
        public var relayOrigin: String
        public var originalURLString: String?
        public var requiresRedirectResolution: Bool

        public init(
            instanceId: String,
            conversationId: String? = nil,
            authUser: String? = nil,
            relayOrigin: String = "https://antigravity.google.com",
            originalURLString: String? = nil,
            requiresRedirectResolution: Bool = false
        ) {
            self.instanceId = instanceId
            self.conversationId = conversationId
            self.authUser = authUser
            self.relayOrigin = relayOrigin
            self.originalURLString = originalURLString
            self.requiresRedirectResolution = requiresRedirectResolution
        }

        public var canonicalRelayURLString: String {
            let trimmedOrigin = relayOrigin.hasSuffix("/") ? String(relayOrigin.dropLast()) : relayOrigin
            if instanceId.isEmpty {
                return trimmedOrigin
            }
            return "\(trimmedOrigin)/r/\(instanceId)"
        }
    }

    /// Returns `true` when `rawHost` belongs to an official Antigravity Cloud Relay surface.
    public static func isAntigravityRelayHost(_ rawHost: String) -> Bool {
        let host = rawHost.lowercased()
        if host == "accounts.google.com" || host == "www.google.com" || host == "google.com" {
            return false
        }
        if host == "antigravity.google.com" || host == "antigravity.google"
            || host.hasSuffix(".antigravity.google.com") || host.hasSuffix(".antigravity.google") {
            return true
        }
        if (host.hasPrefix("antigravity.") || host.contains(".antigravity.") || host.contains("jetski"))
            && (host.hasSuffix(".google.com") || host.hasSuffix(".google") || host.hasSuffix(".corp.google.com")) {
            return true
        }
        if host == "antigravity.dev" || host.hasSuffix(".antigravity.dev")
            || host == "antigravity.app" || host.hasSuffix(".antigravity.app") {
            return true
        }
        return false
    }

    /// Returns `true` when `rawHost` is an official Google shortlink redirector (`g.co`, `c.gle`, `goo.gl`, `*.page.link`).
    public static func isGoogleShortlinkHost(_ rawHost: String) -> Bool {
        let host = rawHost.lowercased()
        return host == "g.co"
            || host == "c.gle"
            || host == "goo.gl"
            || host.hasSuffix(".goo.gl")
            || host.hasSuffix(".page.link")
    }

    /// Returns `true` for loopback hosts used by local mock Cloud Relay verification servers.
    public static func isLoopbackHost(_ rawHost: String) -> Bool {
        let host = rawHost.lowercased()
        return host == "127.0.0.1" || host == "localhost" || host == "::1" || host == "[::1]"
    }

    /// Returns `true` for Direct LAN / Companion Bridge pairing URIs (`antigravity://pair?url=https://192.168.x.x:8787&csrf=...`).
    public static func isDirectLANPairingURI(_ rawInput: String) -> Bool {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let comps = URLComponents(string: trimmed),
              let scheme = comps.scheme?.lowercased(),
              (scheme == "antigravity" || scheme == "agy" || scheme == "google-antigravity"),
              let targetURL = comps.queryItems?.first(where: { $0.name == "url" })?.value,
              !targetURL.isEmpty else {
            return false
        }
        if comps.host?.lowercased() == "pair" {
            return true
        }
        if let csrf = comps.queryItems?.first(where: { $0.name == "csrf" })?.value, !csrf.isEmpty {
            return true
        }
        return false
    }

    /// Selects the best Cloud Relay target URL after `WKWebView` sign-in completes, preserving
    /// resolved shortlink destinations while never dropping an explicit scanned `instanceId`.
    public static func resolveEffectiveRelayTarget(
        scannedInput: String,
        webViewFinalURL: String?
    ) -> String {
        let trimmedScanned = scannedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFinal = webViewFinalURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let scannedTarget = parseRemoteControlTarget(trimmedScanned)
        let finalTarget = trimmedFinal.isEmpty ? nil : parseRemoteControlTarget(trimmedFinal)

        if let finalTarget, !finalTarget.instanceId.isEmpty {
            if scannedTarget == nil || scannedTarget?.instanceId.isEmpty == true || scannedTarget?.requiresRedirectResolution == true {
                return trimmedFinal
            }
        }
        if !trimmedScanned.isEmpty {
            if let scannedTarget, !scannedTarget.requiresRedirectResolution {
                return trimmedScanned
            }
            if !trimmedFinal.isEmpty {
                return trimmedFinal
            }
            return trimmedScanned
        }
        if !trimmedFinal.isEmpty {
            return trimmedFinal
        }
        return "https://antigravity.google.com"
    }

    /// Parses an official Antigravity Remote Control QR URL (`https://antigravity.google.com/r/<id>?p=c%2F<conv>`),
    /// `/u/<authuser>/r/<id>`, Google `AccountChooser`/`ServiceLogin` wrappers, Google shortlinks (`g.co`, `c.gle`),
    /// scheme-less Antigravity links, custom `antigravity://` / `agy://` URIs, JSON payloads, or bare device slugs.
    public static func parseRemoteControlTarget(_ rawInput: String) -> ParsedRemoteControlTarget? {
        parseRemoteControlTargetInternal(rawInput, depth: 0)
    }

    private static func parseRemoteControlTargetInternal(
        _ rawInput: String,
        depth: Int
    ) -> ParsedRemoteControlTarget? {
        guard depth <= 4 else { return nil }
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if isDirectLANPairingURI(trimmed) {
            return nil
        }

        // 1. JSON payload support (`{"url": ...}` or `{"instanceId": ...}`)
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}"),
           let jsonData = trimmed.data(using: .utf8),
           let dict = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any] {
            let urlKeys = ["url", "relayUrl", "relay_url", "remoteUrl", "remote_url", "link", "href", "endpoint"]
            for key in urlKeys {
                if let urlStr = dict[key] as? String,
                   let nested = parseRemoteControlTargetInternal(urlStr, depth: depth + 1) {
                    return nested
                }
            }
            let idKeys = ["instanceId", "instance_id", "instance", "uuid", "deviceId", "device_id", "hostId", "host_id", "slug"]
            for key in idKeys {
                if let rawId = dict[key] as? String {
                    let cleanId = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanId.isEmpty {
                        let conv = (dict["conversationId"] ?? dict["conversation_id"] ?? dict["cascadeId"] ?? dict["cascade_id"]) as? String
                        let auth = (dict["authUser"] ?? dict["authuser"] ?? dict["auth_user"]) as? String
                        return ParsedRemoteControlTarget(
                            instanceId: cleanId,
                            conversationId: conv,
                            authUser: auth
                        )
                    }
                }
            }
            return nil
        }

        // 2. Multi-word pasted CLI / prose text containing an embedded URL
        if trimmed.contains(where: \.isWhitespace) {
            let trimPunctuation = CharacterSet(charactersIn: "\"'<>()[]{},;")
            for rawToken in trimmed.components(separatedBy: .whitespacesAndNewlines) where !rawToken.isEmpty {
                var token = rawToken.trimmingCharacters(in: trimPunctuation)
                while token.hasSuffix(".") {
                    token.removeLast()
                }
                let lowerToken = token.lowercased()
                if lowerToken.contains("://")
                    || lowerToken.contains("antigravity.")
                    || lowerToken.contains(".google")
                    || lowerToken.hasPrefix("g.co/")
                    || lowerToken.hasPrefix("c.gle/") {
                    if let extracted = parseRemoteControlTargetInternal(token, depth: depth + 1) {
                        return extracted
                    }
                }
            }
            return nil
        }

        // 3. Inputs without an explicit `://` scheme (scheme-less URLs vs bare device slugs/UUIDs)
        if !trimmed.contains("://") {
            let lower = trimmed.lowercased()
            let looksLikeSchemelessURL =
                trimmed.contains("/")
                || trimmed.contains("?")
                || lower.hasPrefix("antigravity.")
                || lower.contains(".google.com")
                || lower.hasSuffix(".google")
                || lower.hasPrefix("g.co")
                || lower.hasPrefix("c.gle")
                || lower.hasPrefix("goo.gl")
                || lower.contains(".page.link")

            if looksLikeSchemelessURL {
                return parseRemoteControlTargetInternal("https://\(trimmed)", depth: depth + 1)
            }

            // Bare instance UUID or device slug (e.g. `lt74xt6l0m-golden-star` or `0f5819ac-9308-40d8-a308-98b55122c533-v2`)
            let isBareSlug =
                trimmed.count >= 3
                && trimmed.count <= 128
                && !trimmed.contains(":")
                && !trimmed.contains(".")
                && !trimmed.contains("@")
                && !trimmed.contains("=")
                && !trimmed.contains("&")
                && trimmed.unicodeScalars.allSatisfy { scalar in
                    CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_"
                }
            if isBareSlug {
                return ParsedRemoteControlTarget(instanceId: trimmed)
            }
            return nil
        }

        guard let comps = URLComponents(string: trimmed),
              let scheme = comps.scheme?.lowercased() else {
            return nil
        }

        // 4. Custom Antigravity deep-link schemes (`antigravity://`, `agy://`, `google-antigravity://`)
        if scheme == "antigravity" || scheme == "agy" || scheme == "google-antigravity" {
            let hostLower = comps.host?.lowercased() ?? ""
            if scheme == "antigravity" && hostLower == "verify" {
                return nil
            }
            if let nested = unwrapRedirectQueryParameter(from: comps, depth: depth) {
                return nested
            }
            let parts = comps.path.split(separator: "/").map(String.init)
            var extracted = extractMetadata(parts: parts, queryItems: comps.queryItems, fragment: comps.fragment)
            if extracted.instanceId.isEmpty {
                if hostLower == "r", let firstPart = parts.first {
                    extracted.instanceId = firstPart
                } else if ["remote", "remote-control", "connect", "instance", "host", "open", ""].contains(hostLower),
                          let firstPart = parts.first,
                          !["c", "u"].contains(firstPart.lowercased()) {
                    extracted.instanceId = firstPart
                } else if !hostLower.isEmpty,
                          !["remote", "remote-control", "connect", "instance", "host", "open", "c", "u"].contains(hostLower),
                          parts.isEmpty {
                    extracted.instanceId = comps.host ?? ""
                }
            }
            return ParsedRemoteControlTarget(
                instanceId: extracted.instanceId,
                conversationId: extracted.conversationId,
                authUser: extracted.authUser,
                relayOrigin: "https://antigravity.google.com",
                originalURLString: trimmed
            )
        }

        // 5. Standard `https://` / `http://` URLs
        guard (scheme == "https" || scheme == "http"),
              let rawHost = comps.host,
              !rawHost.isEmpty else {
            return nil
        }
        let host = rawHost.lowercased()
        let parts = comps.path.split(separator: "/").map(String.init)

        // 5a. Unwrap Google AccountChooser / ServiceLogin / Redirector URLs (`?continue=...`, `?q=...`, `?link=...`)
        if var nested = unwrapRedirectQueryParameter(from: comps, depth: depth) {
            if nested.authUser == nil {
                let outerMeta = extractMetadata(parts: parts, queryItems: comps.queryItems, fragment: comps.fragment)
                nested.authUser = outerMeta.authUser
            }
            nested.originalURLString = trimmed
            return nested
        }

        // 5b. Official Google shortlinks (`g.co/...`, `c.gle/...`, `goo.gl/...`, `*.page.link/...`)
        //     or `accounts.google.com` flows explicitly referencing Antigravity
        if isGoogleShortlinkHost(host) {
            guard !parts.isEmpty else { return nil }
            return ParsedRemoteControlTarget(
                instanceId: "",
                conversationId: nil,
                authUser: nil,
                relayOrigin: "https://antigravity.google.com",
                originalURLString: trimmed,
                requiresRedirectResolution: true
            )
        }
        if host == "accounts.google.com" && (trimmed.lowercased().contains("antigravity") || trimmed.lowercased().contains("jetski")) {
            return ParsedRemoteControlTarget(
                instanceId: "",
                conversationId: nil,
                authUser: nil,
                relayOrigin: "https://antigravity.google.com",
                originalURLString: trimmed,
                requiresRedirectResolution: true
            )
        }

        // 5c. Antigravity Relay hosts vs local mock loopback servers
        let isAntigravity = isAntigravityRelayHost(host)
        let isLoopback = isLoopbackHost(host)
        if isLoopback {
            let lowerParts = parts.map { $0.lowercased() }
            let hasRemoteControlPath =
                lowerParts.contains("r")
                || lowerParts.contains("remote")
                || lowerParts.contains("remote-control")
            guard hasRemoteControlPath else {
                return nil
            }
        } else if !isAntigravity {
            return nil
        }

        let extracted = extractMetadata(parts: parts, queryItems: comps.queryItems, fragment: comps.fragment)
        let origin: String
        if let port = comps.port {
            origin = "\(scheme)://\(host):\(port)"
        } else {
            origin = "\(scheme)://\(host)"
        }

        return ParsedRemoteControlTarget(
            instanceId: extracted.instanceId,
            conversationId: extracted.conversationId,
            authUser: extracted.authUser,
            relayOrigin: origin,
            originalURLString: trimmed,
            requiresRedirectResolution: false
        )
    }

    private static func unwrapRedirectQueryParameter(
        from comps: URLComponents,
        depth: Int
    ) -> ParsedRemoteControlTarget? {
        let redirectKeys: Set<String> = [
            "continue", "url", "q", "redirect_uri", "redirect",
            "target", "link", "deep_link_id", "dest", "destination",
            "next", "followup"
        ]
        var candidateItems: [URLQueryItem] = comps.queryItems ?? []
        if let fragment = comps.fragment, fragment.contains("="),
           let fragComps = URLComponents(string: "https://placeholder.invalid?\(fragment)"),
           let fragItems = fragComps.queryItems {
            candidateItems.append(contentsOf: fragItems)
        }
        for item in candidateItems where redirectKeys.contains(item.name.lowercased()) {
            guard let rawValue = item.value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawValue.isEmpty else {
                continue
            }
            if let direct = parseRemoteControlTargetInternal(rawValue, depth: depth + 1) {
                return direct
            }
            if let onceDecoded = rawValue.removingPercentEncoding,
               onceDecoded != rawValue,
               let decoded = parseRemoteControlTargetInternal(onceDecoded, depth: depth + 1) {
                return decoded
            }
        }
        return nil
    }

    private static func extractMetadata(
        parts: [String],
        queryItems: [URLQueryItem]?,
        fragment: String?
    ) -> (instanceId: String, conversationId: String?, authUser: String?) {
        let markerPrefixes: Set<String> = [
            "r", "remote", "remote-control", "instances", "instance", "host", "hosts", "d"
        ]
        let reservedSegments: Set<String> = [
            "c", "u", "login", "signin", "settings", "auth"
        ]

        var instanceId = ""
        if let markerIdx = parts.firstIndex(where: { markerPrefixes.contains($0.lowercased()) }),
           parts.count > markerIdx + 1 {
            let candidate = parts[markerIdx + 1]
            if !reservedSegments.contains(candidate.lowercased()) {
                instanceId = candidate
            }
        }

        var authUser: String? = nil
        if let qAuth = queryItems?.first(where: { $0.name.lowercased() == "authuser" })?.value,
           !qAuth.isEmpty,
           qAuth.allSatisfy(\.isNumber) {
            authUser = qAuth
        } else if let uIndex = parts.firstIndex(where: { $0.lowercased() == "u" }),
                  parts.count > uIndex + 1,
                  !parts[uIndex + 1].isEmpty,
                  parts[uIndex + 1].allSatisfy(\.isNumber) {
            authUser = parts[uIndex + 1]
        }

        var conversationId: String? = nil
        if let queryItems {
            if let rawP = queryItems.first(where: { $0.name.lowercased() == "p" })?.value {
                let decodedP = rawP.removingPercentEncoding ?? rawP
                let normalizedP = decodedP.hasPrefix("/") ? String(decodedP.dropFirst()) : decodedP
                if normalizedP.hasPrefix("c/") {
                    let cid = String(normalizedP.dropFirst(2))
                    if !cid.isEmpty {
                        conversationId = cid
                    }
                }
            }
            if conversationId == nil {
                let convKeys: Set<String> = [
                    "c", "cascade", "cascade_id", "cascadeid",
                    "conversation", "conversation_id", "conversationid"
                ]
                if let rawConv = queryItems.first(where: { convKeys.contains($0.name.lowercased()) })?.value {
                    let decoded = (rawConv.removingPercentEncoding ?? rawConv).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !decoded.isEmpty {
                        conversationId = decoded
                    }
                }
            }
            if instanceId.isEmpty {
                let idKeys: Set<String> = [
                    "instance", "instance_id", "instanceid",
                    "host", "host_id", "hostid",
                    "device", "device_id", "deviceid",
                    "uuid", "r", "id", "slug"
                ]
                if let rawInst = queryItems.first(where: { idKeys.contains($0.name.lowercased()) })?.value {
                    let decoded = (rawInst.removingPercentEncoding ?? rawInst).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !decoded.isEmpty {
                        instanceId = decoded
                    }
                }
            }
        }

        if conversationId == nil,
           let cIdx = parts.firstIndex(where: { $0.lowercased() == "c" }),
           parts.count > cIdx + 1 {
            let joined = parts[(cIdx + 1)...].joined(separator: "/")
            if !joined.isEmpty {
                conversationId = joined
            }
        }

        // SPA hash-route fallback (`#/r/<id>?p=c%2F<conv>` or `#instance=<id>`)
        if let fragment, !fragment.isEmpty,
           (instanceId.isEmpty || conversationId == nil || authUser == nil) {
            let fragPartsAndQuery = fragment.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            let fragPathRaw = fragPartsAndQuery[0]
            let fragQueryRaw: String? = {
                if fragPartsAndQuery.count > 1 { return fragPartsAndQuery[1] }
                if !fragPathRaw.contains("/") && fragPathRaw.contains("=") { return fragPathRaw }
                return nil
            }()
            let fragParts = fragPathRaw.contains("=") && !fragPathRaw.contains("/")
                ? []
                : fragPathRaw.split(separator: "/").map(String.init)
            let fragQueryItems = fragQueryRaw.flatMap {
                URLComponents(string: "https://placeholder.invalid?\($0)")?.queryItems
            }
            if !fragParts.isEmpty || fragQueryItems != nil {
                let fragMeta = extractMetadata(parts: fragParts, queryItems: fragQueryItems, fragment: nil)
                if instanceId.isEmpty { instanceId = fragMeta.instanceId }
                if conversationId == nil { conversationId = fragMeta.conversationId }
                if authUser == nil { authUser = fragMeta.authUser }
            }
        }

        return (instanceId, conversationId, authUser)
    }

    /// Parses an official Antigravity Remote Control QR URL (`https://antigravity.google.com/r/<id>?p=c%2F<conv>`).
    public static func parseRemoteControlQR(urlString: String) -> (instanceId: String, conversationId: String?)? {
        guard let target = parseRemoteControlTarget(urlString),
              !target.instanceId.isEmpty,
              urlString.contains("://") else {
            return nil
        }
        return (target.instanceId, target.conversationId)
    }
}

public struct WorkspaceInfo: Codable, Sendable, Equatable, Identifiable {
    public var id: String { workspaceUri }
    public var workspaceUri: String
    public var displayName: String
    public var activeBranch: String
    public var worktrees: [String]
    public var activeCascadeCount: Int
    public var indexedFiles: [String]
    public var isCloud: Bool

    public init(
        workspaceUri: String,
        displayName: String,
        activeBranch: String = "main",
        worktrees: [String] = ["main"],
        activeCascadeCount: Int = 0,
        indexedFiles: [String] = [],
        isCloud: Bool? = nil
    ) {
        self.workspaceUri = workspaceUri
        self.displayName = displayName
        self.activeBranch = activeBranch
        self.worktrees = worktrees
        self.activeCascadeCount = activeCascadeCount
        self.indexedFiles = indexedFiles
        self.isCloud = isCloud ?? AntigravityCloudDetector.isCloudWorkspaceURI(workspaceUri)
    }

    private enum CodingKeys: String, CodingKey {
        case workspaceUri
        case displayName
        case activeBranch
        case worktrees
        case activeCascadeCount
        case indexedFiles
        case isCloud
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uri = try container.decode(String.self, forKey: .workspaceUri)
        self.workspaceUri = uri
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.activeBranch = try container.decodeIfPresent(String.self, forKey: .activeBranch) ?? "main"
        self.worktrees = try container.decodeIfPresent([String].self, forKey: .worktrees) ?? ["main"]
        self.activeCascadeCount = try container.decodeIfPresent(Int.self, forKey: .activeCascadeCount) ?? 0
        self.indexedFiles = try container.decodeIfPresent([String].self, forKey: .indexedFiles) ?? []
        self.isCloud = try container.decodeIfPresent(Bool.self, forKey: .isCloud)
            ?? AntigravityCloudDetector.isCloudWorkspaceURI(uri)
    }
}

/// Legacy filter category retained for compatibility.
public enum SessionFilterCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case waitingApproval = "Waiting"
    case running = "Running"
    case pinned = "Pinned"
    case done = "Completed"

    public var id: String { rawValue }
}

// MARK: - Model, Mode & Agent Configuration (UE09)

public enum ThinkingEffortLevel: String, Codable, Sendable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    public var id: String { rawValue }
}

public enum CascadeExecutionMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case planning = "Planning"
    case fast = "Fast"

    public var id: String { rawValue }

    public var summaryDescription: String {
        switch self {
        case .planning:
            return "Plans first and writes artifacts for you to review"
        case .fast:
            return "Acts directly — best for small, local edits"
        }
    }
}

/// Model, execution mode, and custom agent persona configuration (`UE07`, `UE09`).
public struct CascadeModelConfig: Codable, Sendable, Equatable, Identifiable {
    public var id: String { modelId }
    public var modelId: String
    public var displayName: String
    public var subtitle: String
    public var hasThinkingBadge: Bool
    public var requiresUpgradeNote: String?
    public var mode: CascadeExecutionMode
    public var agentPersona: String
    public var effort: ThinkingEffortLevel

    public init(
        modelId: String,
        displayName: String,
        subtitle: String = "Deep reasoning for long, multi-step tasks",
        hasThinkingBadge: Bool = false,
        requiresUpgradeNote: String? = nil,
        mode: CascadeExecutionMode = .planning,
        agentPersona: String = "Default",
        effort: ThinkingEffortLevel = .high
    ) {
        self.modelId = modelId
        self.displayName = displayName
        self.subtitle = subtitle
        self.hasThinkingBadge = hasThinkingBadge
        self.requiresUpgradeNote = requiresUpgradeNote
        self.mode = mode
        self.agentPersona = agentPersona
        self.effort = effort
    }

    public var supportsThinkingBadge: Bool { hasThinkingBadge }
    public var requiresProBadge: Bool { requiresUpgradeNote != nil }

    public static let availableAgents: [String] = [
        "Default",
        "go-reviewer",
        "release-captain"
    ]

    public static let catalog: [CascadeModelConfig] = [
        CascadeModelConfig(
            modelId: "gemini-3-1-pro",
            displayName: "Gemini 3.1 Pro",
            subtitle: "Deep reasoning for long, multi-step tasks",
            hasThinkingBadge: false,
            requiresUpgradeNote: nil,
            mode: .planning,
            agentPersona: "Default",
            effort: .high
        ),
        CascadeModelConfig(
            modelId: "gemini-3-8-flash",
            displayName: "Gemini 3.8 Flash",
            subtitle: "Fastest responses, lowest cost",
            hasThinkingBadge: false,
            requiresUpgradeNote: nil,
            mode: .planning,
            agentPersona: "Default",
            effort: .medium
        ),
        CascadeModelConfig(
            modelId: "claude-opus-5-5",
            displayName: "Claude Opus 5.5",
            subtitle: "Requires Google AI Pro or Ultra",
            hasThinkingBadge: true,
            requiresUpgradeNote: "Requires Google AI Pro or Ultra",
            mode: .planning,
            agentPersona: "Default",
            effort: .high
        ),
        CascadeModelConfig(
            modelId: "claude-sonnet-5-5",
            displayName: "Claude Sonnet 5.5",
            subtitle: "Requires Google AI Pro or Ultra",
            hasThinkingBadge: true,
            requiresUpgradeNote: "Requires Google AI Pro or Ultra",
            mode: .planning,
            agentPersona: "Default",
            effort: .high
        )
    ]
}

// MARK: - Composer Slash Commands & Attachment Chips (UE07, UE08)

/// Represents a `/slash` workflow command available in `ChatComposerView`.
public struct SlashCommandItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String { command }
    public var command: String
    public var title: String
    public var summary: String
    public var iconName: String

    public init(command: String, title: String, summary: String, iconName: String) {
        self.command = command
        self.title = title
        self.summary = summary
        self.iconName = iconName
    }

    public static let allCommands: [SlashCommandItem] = [
        SlashCommandItem(
            command: "/plan",
            title: "Implementation Plan",
            summary: "Draft a step-by-step architecture & verification plan before coding",
            iconName: "doc.text.magnifyingglass"
        ),
        SlashCommandItem(
            command: "/boost",
            title: "Extra Multi-Agent Reasoning Pass",
            summary: "Action · extra multi-agent reasoning pass",
            iconName: "bolt.fill"
        ),
        SlashCommandItem(
            command: "/goal",
            title: "Autonomous Goal Loop",
            summary: "Run thorough multi-step execution until all ESDD acceptance criteria pass",
            iconName: "flag.checkered.2.crossed"
        ),
        SlashCommandItem(
            command: "/grill-me",
            title: "Interactive Design Alignment",
            summary: "Clarify ambiguous trade-offs via structured ask_question cards",
            iconName: "questionmark.bubble.fill"
        ),
        SlashCommandItem(
            command: "/teamwork",
            title: "Multi-Agent Swarm",
            summary: "Spawn parallel subagents for research, implementation, and verification",
            iconName: "person.3.sequence.fill"
        )
    ]
}

/// Represents a context chip attached to the Composer Input Box (`@ratelimit.go`, skill, mention, etc.).
public struct ComposerAttachmentChip: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case fileMention
        case folder
        case conversationMention
        case imageScreenshot
        case terminalLog
        case action
        case skill
    }

    public var id: String
    public var kind: Kind
    public var label: String
    public var targetUri: String

    public init(id: String = UUID().uuidString, kind: Kind, label: String, targetUri: String) {
        self.id = id
        self.kind = kind
        self.label = label
        self.targetUri = targetUri
    }
}
