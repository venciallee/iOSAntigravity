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
        switch runtime {
        case .macBookPro:
            return "Local · \(hostName) · \(activeBranch)"
        case .cloud:
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

    /// Parses an official Antigravity Remote Control QR URL (`https://antigravity.google.com/r/<id>?p=c%2F<conv>`).
    public static func parseRemoteControlQR(urlString: String) -> (instanceId: String, conversationId: String?)? {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased(),
              host.contains("antigravity.google") else {
            return nil
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0] == "r" else { return nil }
        let instanceId = parts[1]
        var conversationId: String?
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let pValue = queryItems.first(where: { $0.name == "p" })?.value?.removingPercentEncoding,
           pValue.hasPrefix("c/") {
            conversationId = String(pValue.dropFirst(2))
        }
        return (instanceId, conversationId)
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

    public init(
        workspaceUri: String,
        displayName: String,
        activeBranch: String = "main",
        worktrees: [String] = ["main"],
        activeCascadeCount: Int = 0,
        indexedFiles: [String] = []
    ) {
        self.workspaceUri = workspaceUri
        self.displayName = displayName
        self.activeBranch = activeBranch
        self.worktrees = worktrees
        self.activeCascadeCount = activeCascadeCount
        self.indexedFiles = indexedFiles
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
