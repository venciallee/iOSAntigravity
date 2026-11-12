import Foundation
import Observation

/// Active navigation destination in `AntigravityShellController` across all 13 UE screens.
public enum AntigravityNavigationRoute: Sendable, Equatable, Hashable {
    case tabRoot
    case projectDetail(String)
    case cascadeChat(String)
    case planReview
    case turnDiffReview
    case pairingSettings

    // Compatibility aliases
    public static var workspaceHome: AntigravityNavigationRoute { .tabRoot }
    public static var chatAndComposer: AntigravityNavigationRoute { .cascadeChat("cas-rate-limiter") }
    public static var artifactInspector: AntigravityNavigationRoute { .planReview }
    public static var turnDiffInspector: AntigravityNavigationRoute { .turnDiffReview }
    public static var pairingQR: AntigravityNavigationRoute { .pairingSettings }
}

/// Modal sheet presentation state in `AntigravityShellController`.
public enum AntigravityModalSheet: Identifiable, Sendable, Equatable {
    case displayOptions
    case contextMenuPreview(cascadeId: String)
    case createProject
    case addContext
    case modelAndMode
    case permissionGate(stepIndex: Int)
    case askQuestion(stepIndex: Int)
    case modelConfigPicker
    case fileMentionPicker
    case newCascadeSheet

    public var id: String {
        switch self {
        case .displayOptions: return "display-options"
        case .contextMenuPreview(let cid): return "context-menu-\(cid)"
        case .createProject: return "create-project"
        case .addContext: return "add-context"
        case .modelAndMode: return "model-and-mode"
        case .permissionGate(let idx): return "permission-\(idx)"
        case .askQuestion(let idx): return "question-\(idx)"
        case .modelConfigPicker: return "model-picker"
        case .fileMentionPicker: return "file-picker"
        case .newCascadeSheet: return "new-cascade"
        }
    }
}

/// Central `@Observable` state coordinator for `iOSAntigravity` (v2.0 UE Aligned).
/// Drives all 13 UE screens: Agents Home (`UE01`), Display Options (`UE02`), Long-Press & Pin (`UE03`),
/// Project Detail (`UE04`), Create New Project (`UE05`), Automations (`UE06`), Chat & Composer (`UE07`),
/// Add Context (`UE08`), Model & Mode (`UE09`), Structured Multi-Step Question (`UE10`),
/// Implementation Plan Review (`UE11`), Turn Diff Line Review (`UE12`), and Live Activity (`UE13`).
@MainActor
@Observable
public final class AntigravitySessionStore {

    // MARK: - Top-Level Navigation & Sheet State
    public var selectedTab: PrimaryTab = .agents
    public var activeRoute: AntigravityNavigationRoute = .tabRoot
    public var presentedSheet: AntigravityModalSheet? = nil

    public var currentRoute: AntigravityNavigationRoute {
        get { activeRoute }
        set {
            if newValue == .chatAndComposer {
                activeRoute = .cascadeChat(activeCascadeId)
            } else {
                activeRoute = newValue
            }
        }
    }

    // MARK: - Agents Home, Display Options & Search State (`UE01`, `UE02`, `UE03`)
    public var quickFilter: AgentsQuickFilter = .all
    public var displayOptions: AgentDisplayOptions = AgentDisplayOptions()
    public var isSortPopoverPresented: Bool = true
    public var searchQuery: String = ""
    public var selectedFilterCategory: SessionFilterCategory = .all
    public var selectedWorktreeFilter: String? = nil
    public var isRefreshingSummaries: Bool = false
    public var contextMenuTargetCascadeId: String = "cas-flaky-settlement"
    public var swipePreviewCascadeId: String = "cas-upgrade-go"

    // MARK: - Hosts, Projects & Create Project State (`UE01`, `UE04`, `UE05`)
    public var hosts: [RemoteHostInstance]
    public var activeHost: RemoteHostInstance
    public var projects: [ProjectWorkspace]
    public var selectedProjectId: String = "ledger-svc"
    public var selectedProjectTab: ProjectDetailTab = .active
    public var newProjectDraft: NewProjectDraft = NewProjectDraft()
    public var availableGitHubRepos: [GitHubRepoItem] = GitHubRepoItem.sampleCatalog
    public var workspaces: [WorkspaceInfo]
    public var selectedWorkspaceUri: String

    // MARK: - Conversations, Automations & Context State (`UE01`, `UE06`, `UE08`)
    public var summaries: [CascadeSummary]
    public var automations: [AutomationItem]
    public var automationPromptDraft: String = ""
    public var contextCandidates: [ContextCandidateItem]
    public var contextSearchQuery: String = ""
    public var selectedContextCategoryFilter: ContextCategory? = nil

    // MARK: - Active Trajectory & Message List State (`UE07`)
    public var activeCascadeId: String
    public var stepsByCascadeId: [String: [CascadeStep]] = [:]
    public var expandedThinkingStepIds: Set<String> = []
    public var expandedEvidenceGroupIds: Set<String> = []
    public var expandedTerminalStepIds: Set<String> = []
    public var isAutoScrollPinnedToBottom: Bool = true
    public var unreadStreamingStepCount: Int = 0

    // MARK: - Composer & Model Config State (`UE07`, `UE08`, `UE09`)
    public var composerDraftText: String = ""
    public var composerAttachments: [ComposerAttachmentChip] = []
    public var selectedModelConfig: CascadeModelConfig
    public var availableModels: [CascadeModelConfig]
    public var availableAgents: [String]
    public var isSlashPopupDismissedManually: Bool = false

    // MARK: - Structured Multi-Step Question State (`UE10`)
    public var questionSteps: [StructuredQuestionStepItem]
    public var activeQuestionStepIndex: Int = 1
    public var questionFreeformReplyDraft: String = ""

    // MARK: - Implementation Plan Review State (`UE11`)
    public var safeAutoAcceptEnabled: Bool
    public var activeTurnGrants: Set<String> = ["ReadOnlyWorkspace", "verification/*"]
    public var activeArtifacts: [ArtifactSnapshot]
    public var selectedArtifactPath: String = "/brain/implementation_plan.md"
    public var planChanges: [PlanProposedFileChange]
    public var planComments: [PlanInlineComment]

    // MARK: - Multi-Turn Line-Level Diff Review State (`UE12`)
    public var activeTurnDiffs: [FilePatchDiff]
    public var selectedDiffTurn: Int = 3
    public var selectedDiffFileIndex: Int = 0
    public var selectedDiffLineNumber: Int? = 29
    public var activeLineCommentDraft: String
    public var diffComments: [DiffLineComment] = []
    public var lastDispatchedInteraction: CascadeUserInteractionPayload? = nil

    // MARK: - Live Backend Connectivity & Auth State
    public var isVerificationMode: Bool = false
    public var isInitialSessionCheckComplete: Bool = false
    public var hasPairedBackend: Bool = false
    public var isLiveBackendConnected: Bool = false
    public var isConnectingToBackend: Bool = false
    public var connectionStatusText: String = "Not Connected"
    public var connectionErrorText: String? = nil
    public var lastPingLatencyMs: Int? = nil
    public var availableRelayInstances: [RelayInstanceInfo] = []
    public var activeAuthUser: String = "0"
    public var lastScannedRelayURL: String = ""
    public var isLoadingSteps: Bool = false
    public var stepLoadErrorText: String? = nil
    public var cloudAgentWarmingUp: Bool = false

    // MARK: - Dependencies
    private let projectionStore: LocalProjectionStore
    private var rpcClient: AntigravityRPCClient?
    private var summaryStreamTask: Task<Void, Never>? = nil
    private var cloudSummaryStreamTask: Task<Void, Never>? = nil
    private var summaryPollingTask: Task<Void, Never>? = nil
    private var stepPollingTask: Task<Void, Never>? = nil
    private var locallyViewedAtByCascadeId: [String: Date] = [:]
    private var optimisticActiveUntilByCascadeId: [String: Date] = [:]
    private var consecutiveSyncFailures: Int = 0
    private var backgroundPollCounter: Int = 0
    private var syncedConfigCascadeIds: Set<String> = []

    public init(
        hosts: [RemoteHostInstance] = [],
        activeHost: RemoteHostInstance,
        projects: [ProjectWorkspace] = [],
        workspaces: [WorkspaceInfo] = [],
        selectedWorkspaceUri: String = "",
        summaries: [CascadeSummary] = [],
        automations: [AutomationItem] = [],
        contextCandidates: [ContextCandidateItem] = [],
        questionSteps: [StructuredQuestionStepItem] = [],
        activeQuestionStepIndex: Int = 1,
        planChanges: [PlanProposedFileChange] = [],
        planComments: [PlanInlineComment] = [],
        activeCascadeId: String = "",
        stepsByCascadeId: [String: [CascadeStep]] = [:],
        activeSteps: [CascadeStep] = [],
        activeArtifacts: [ArtifactSnapshot] = [],
        activeTurnDiffs: [FilePatchDiff] = [],
        selectedDiffTurn: Int = 3,
        selectedDiffFileIndex: Int = 0,
        activeLineCommentDraft: String = "",
        selectedModelConfig: CascadeModelConfig = CascadeModelConfig.catalog[0],
        availableModels: [CascadeModelConfig] = CascadeModelConfig.catalog,
        availableAgents: [String] = CascadeModelConfig.availableAgents,
        safeAutoAcceptEnabled: Bool = true,
        projectionStore: LocalProjectionStore = LocalProjectionStore()
    ) {
        self.hosts = hosts.isEmpty ? [activeHost] : hosts
        self.activeHost = activeHost
        self.projects = projects
        self.workspaces = workspaces
        self.selectedWorkspaceUri = selectedWorkspaceUri
        self.summaries = summaries
        self.automations = automations
        self.contextCandidates = contextCandidates
        self.questionSteps = questionSteps
        self.activeQuestionStepIndex = activeQuestionStepIndex
        self.planChanges = planChanges
        self.planComments = planComments
        self.activeCascadeId = activeCascadeId
        var mergedSteps = stepsByCascadeId
        if !activeCascadeId.isEmpty && mergedSteps[activeCascadeId] == nil && !activeSteps.isEmpty {
            mergedSteps[activeCascadeId] = activeSteps
        }
        self.stepsByCascadeId = mergedSteps
        self.activeArtifacts = activeArtifacts
        self.activeTurnDiffs = activeTurnDiffs
        self.selectedDiffTurn = selectedDiffTurn
        self.selectedDiffFileIndex = selectedDiffFileIndex
        self.activeLineCommentDraft = activeLineCommentDraft
        self.selectedModelConfig = selectedModelConfig
        self.availableModels = availableModels
        self.availableAgents = availableAgents
        self.safeAutoAcceptEnabled = safeAutoAcceptEnabled
        self.projectionStore = projectionStore
        self.rpcClient = AntigravityRPCClient(
            host: activeHost,
            csrfToken: "csrf-antigravity-ios-session-token"
        )
    }

    // MARK: - Computed Properties for Agents Home & Project Hub (`UE01`, `UE02`, `UE04`)

    public var currentWorkspace: WorkspaceInfo? {
        workspaces.first(where: { $0.workspaceUri == selectedWorkspaceUri }) ?? workspaces.first
    }

    public var selectedProject: ProjectWorkspace? {
        projects.first(where: { $0.id == selectedProjectId }) ?? projects.first
    }

    public var availableWorktrees: [String] {
        selectedProject?.worktrees ?? currentWorkspace?.worktrees ?? ["main"]
    }

    public var runningCount: Int {
        summaries.filter { !$0.isArchived && ($0.status == .inProgress || $0.status == .pending) }.count
    }

    public var runningCascadeCount: Int { runningCount }

    public var needsYouCount: Int {
        summaries.filter { !$0.isArchived && ($0.status == .waiting || $0.status == .blocked) }.count
    }

    public var waitingApprovalCount: Int { needsYouCount }

    public var unreadCount: Int {
        summaries.filter { !$0.isArchived && $0.isUnread }.count
    }

    /// Filtered and sorted conversation summaries driven by `quickFilter`, `displayOptions`, and `searchQuery`.
    public var filteredSummaries: [CascadeSummary] {
        summaries
            .filter { summary in
                if displayOptions.archivedOnly {
                    if !summary.isArchived { return false }
                } else {
                    if summary.isArchived { return false }
                }
                if let branch = selectedWorktreeFilter, !branch.isEmpty, summary.branchName != branch {
                    return false
                }
                switch quickFilter {
                case .all:
                    break
                case .running:
                    if summary.status != .inProgress && summary.status != .pending { return false }
                case .needsYou:
                    if summary.status != .waiting && summary.status != .blocked { return false }
                case .unread:
                    if !summary.isUnread { return false }
                }
                switch selectedFilterCategory {
                case .all:
                    break
                case .waitingApproval:
                    if summary.status != .waiting && summary.status != .blocked { return false }
                case .running:
                    if summary.status != .inProgress && summary.status != .pending { return false }
                case .pinned:
                    if !summary.isPinned { return false }
                case .done:
                    if summary.status != .done { return false }
                }
                let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !q.isEmpty {
                    let matchesTitle = summary.title.lowercased().contains(q)
                    let matchesProject = summary.projectSlug.lowercased().contains(q)
                    let matchesSubtitle = summary.statusSubtitle.lowercased().contains(q)
                    let matchesBranch = summary.branchName.lowercased().contains(q)
                    let matchesPreview = (summary.lastMessagePreview ?? "").lowercased().contains(q)
                    return matchesTitle || matchesProject || matchesSubtitle || matchesBranch || matchesPreview
                }
                return true
            }
            .sorted { lhs, rhs in
                switch displayOptions.sortBy {
                case .title:
                    let cmp = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                    return displayOptions.newestFirst ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                case .lastUpdated, .dateCreated:
                    return displayOptions.newestFirst ? (lhs.updatedAt > rhs.updatedAt) : (lhs.updatedAt < rhs.updatedAt)
                }
            }
    }

    public var pinnedSummaries: [CascadeSummary] {
        filteredSummaries.filter { $0.isPinned }
    }

    public var unpinnedSummaries: [CascadeSummary] {
        filteredSummaries.filter { !$0.isPinned }
    }

    public func unpinnedSummaries(forProject projectSlug: String) -> [CascadeSummary] {
        unpinnedSummaries.filter { $0.projectSlug == projectSlug }
    }

    public func activeSummaries(forProject projectSlug: String) -> [CascadeSummary] {
        summaries.filter { $0.projectSlug == projectSlug && !$0.isArchived }
    }

    public func archivedSummaries(forProject projectSlug: String) -> [CascadeSummary] {
        summaries.filter { $0.projectSlug == projectSlug && $0.isArchived }
    }

    public func totalConversationCount(forProject projectSlug: String) -> Int {
        summaries.filter { $0.projectSlug == projectSlug }.count
    }

    public func automations(forProject projectSlug: String) -> [AutomationItem] {
        automations.filter { $0.projectSlug == projectSlug }
    }

    public var filteredGitHubRepos: [GitHubRepoItem] {
        let q = newProjectDraft.repoSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return availableGitHubRepos }
        return availableGitHubRepos.filter {
            $0.fullName.lowercased().contains(q) || $0.visibilityLabel.lowercased().contains(q)
        }
    }

    // MARK: - Computed Properties for Automations & Context (`UE06`, `UE08`)

    public var scheduledAutomations: [AutomationItem] {
        automations.filter { $0.section == .scheduled }
    }

    public var alwaysOnAutomations: [AutomationItem] {
        automations.filter { $0.section == .alwaysOn }
    }

    public var pausedAutomations: [AutomationItem] {
        automations.filter { $0.section == .paused }
    }

    public var filteredContextCandidates: [ContextCandidateItem] {
        let q = contextSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return contextCandidates.filter { item in
            if let cat = selectedContextCategoryFilter, item.category != cat {
                return false
            }
            if !q.isEmpty {
                return item.title.lowercased().contains(q) || item.subtitle.lowercased().contains(q)
            }
            return true
        }
    }

    public var selectedContextCount: Int {
        contextCandidates.filter { $0.isSelected }.count
    }

    // MARK: - Computed Properties for Active Chat, Question, Plan & Diff (`UE07`, `UE10`, `UE11`, `UE12`)

    public var activeSummary: CascadeSummary? {
        summaries.first(where: { $0.cascadeId == activeCascadeId })
    }

    public var contextMenuTargetSummary: CascadeSummary? {
        summaries.first(where: { $0.cascadeId == contextMenuTargetCascadeId }) ?? summaries.first
    }

    public var activeSteps: [CascadeStep] {
        get { stepsByCascadeId[activeCascadeId] ?? [] }
        set { stepsByCascadeId[activeCascadeId] = newValue }
    }

    public var displayItems: [CascadeDisplayItem] {
        CascadeDisplayItem.buildDisplayItems(from: activeSteps)
    }

    public var activeTaskBoundary: TaskBoundaryPayload? {
        activeSteps.last(where: { $0.type == .taskBoundary })?.taskBoundary
    }

    public var pendingWaitingStep: CascadeStep? {
        activeSteps.first(where: { $0.status == .waiting })
    }

    public var isCascadeStreaming: Bool {
        if let summary = activeSummary, summary.status == .inProgress || summary.status == .pending {
            return true
        }
        return activeSteps.contains(where: { $0.status == .inProgress || $0.status == .pending })
    }

    public var currentQuestionStep: StructuredQuestionStepItem? {
        guard questionSteps.indices.contains(activeQuestionStepIndex) else { return questionSteps.first }
        return questionSteps[activeQuestionStepIndex]
    }

    public var currentDiffFile: FilePatchDiff? {
        guard !activeTurnDiffs.isEmpty else { return nil }
        let clamped = min(max(0, selectedDiffFileIndex), activeTurnDiffs.count - 1)
        return activeTurnDiffs[clamped]
    }

    public var selectedDiffFilePath: String {
        get { currentDiffFile?.filePath ?? "middleware/ratelimit.go" }
        set {
            if let idx = activeTurnDiffs.firstIndex(where: { $0.filePath == newValue }) {
                selectedDiffFileIndex = idx
            }
        }
    }

    public var totalDiffAdditions: Int {
        let sum = activeTurnDiffs.reduce(0) { $0 + $1.additions }
        if sum > 0 { return sum }
        let stepSum = activeSteps.compactMap(\.codeAction).reduce(0) { $0 + $1.additions }
        if stepSum > 0 { return stepSum }
        if isLiveBackendConnected {
            return activeSummary?.totalAdditions ?? 0
        }
        return activeSummary?.totalAdditions ?? 128
    }

    public var totalDiffDeletions: Int {
        let sum = activeTurnDiffs.reduce(0) { $0 + $1.deletions }
        if sum > 0 { return sum }
        let stepSum = activeSteps.compactMap(\.codeAction).reduce(0) { $0 + $1.deletions }
        if stepSum > 0 { return stepSum }
        if isLiveBackendConnected {
            return activeSummary?.totalDeletions ?? 0
        }
        return activeSummary?.totalDeletions ?? 14
    }

    // MARK: - Composer Suggestions (`UE07`)

    public var activeSlashCommandSuggestions: [SlashCommandItem] {
        guard !isSlashPopupDismissedManually else { return [] }
        let trimmed = composerDraftText.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("/") else { return [] }
        let token = String(trimmed.split(separator: " ").first ?? Substring(trimmed)).lowercased()
        if token == "/" {
            return SlashCommandItem.allCommands
        }
        return SlashCommandItem.allCommands.filter {
            $0.command.lowercased().hasPrefix(token) || $0.title.lowercased().contains(token.dropFirst())
        }
    }

    public var activeFileMentionSuggestions: [String] {
        guard let lastWord = composerDraftText.split(separator: " ").last,
              lastWord.hasPrefix("@") else {
            return []
        }
        let query = String(lastWord.dropFirst()).lowercased()
        let files = currentWorkspace?.indexedFiles ?? [
            "internal/middleware/ratelimit.go",
            "internal/router/transfers.go",
            "internal/settlement/batch.go",
            "internal/settlement/settlement_test.go",
            "load/transfers.txt"
        ]
        if query.isEmpty { return Array(files.prefix(5)) }
        return files.filter { $0.lowercased().contains(query) }
    }

    public var canSendCurrentDraft: Bool {
        !composerDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !composerAttachments.isEmpty
    }

    // MARK: - Live Backend Login, Pairing & Streaming Actions

    private static let esddFixtureProjectIds: Set<String> = ["ledger-svc", "web-console"]
    private static let esddFixtureCascadeIds: Set<String> = [
        "cas-rate-limiter",
        "cas-release-checklist",
        "cas-flaky-settlement",
        "cas-upgrade-go",
        "cas-idempotency-payouts",
        "cas-pgx-v5-migration",
        "cas-audit-csp-headers",
        "cas-audit-log-admin"
    ]
    private static let esddFixtureAutomationIds: Set<String> = [
        "auto-nightly-audit",
        "auto-weekly-flaky",
        "auto-pr-triage",
        "auto-bundle-size"
    ]

    /// Restores saved Keychain credentials on launch and connects to the live backend if available.
    /// If the saved host is temporarily offline on launch, retains paired mode (`hasPairedBackend = true`),
    /// marks `activeHost.isOnline = false`, hydrates cached sessions from `LocalProjectionStore`,
    /// and starts background reconnect polling.
    @discardableResult
    public func restoreSavedBackendSession() async -> Bool {
        guard let saved = await KeychainStore.shared.loadCredentials() else {
            return false
        }
        switch saved.channel {
        case .directHost:
            return await connectDirectLAN(
                endpointURLString: saved.endpointURLString,
                csrfToken: saved.csrfToken ?? "",
                certSHA256: saved.certFingerprintSHA256,
                hostName: saved.hostname,
                isRestoringSavedSession: true
            )
        case .cloudRelay:
            return await connectCloudRelay(
                relayURLString: saved.endpointURLString,
                sessionCookie: saved.sessionCookie ?? "",
                authUser: saved.authUser,
                resolvedInstanceUuid: saved.resolvedInstanceUuid,
                hostName: saved.hostname,
                isRestoringSavedSession: true
            )
        }
    }

    /// Reads any previously saved Google Cloud Relay session cookie from Keychain so scanning a new QR code
    /// connects immediately without asking the user to sign in again.
    public func loadSavedSessionCookie() async -> (cookie: String, authUser: String?)? {
        guard let saved = await KeychainStore.shared.loadCredentials(),
              let cookie = saved.sessionCookie,
              !cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return (cookie, saved.authUser)
    }

    /// Parses and connects via QR / Deep Link URI:
    /// - Official Antigravity Desktop QR: `https://antigravity.google.com/r/<instance-id>?p=c%2F<cascadeId>`
    /// - Optional LAN / Bridge Deep Link: `antigravity://pair?url=https://192.168.1.20:8787&csrf=<token>&sha256=<fp>&name=MacBook%20Pro`
    @discardableResult
    public func connectWithPairingURI(_ rawURI: String, fallbackCookie: String = "") async -> Bool {
        let trimmed = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
        if RemoteHostInstance.isDirectLANPairingURI(trimmed),
           let comps = URLComponents(string: trimmed),
           let targetURL = comps.queryItems?.first(where: { $0.name == "url" })?.value {
            let csrf = comps.queryItems?.first(where: { $0.name == "csrf" })?.value ?? ""
            let sha256 = comps.queryItems?.first(where: { $0.name == "sha256" })?.value
            let name = comps.queryItems?.first(where: { $0.name == "name" })?.value ?? "MacBook Pro"
            return await connectDirectLAN(
                endpointURLString: targetURL,
                csrfToken: csrf,
                certSHA256: sha256,
                hostName: name
            )
        }

        if let target = RemoteHostInstance.parseRemoteControlTarget(trimmed) {
            lastScannedRelayURL = target.canonicalRelayURLString
            var effectiveCookie = fallbackCookie.trimmingCharacters(in: .whitespacesAndNewlines)
            var savedAuthUser = target.authUser
            if effectiveCookie.isEmpty, let cached = await loadSavedSessionCookie() {
                effectiveCookie = cached.cookie
                if savedAuthUser == nil {
                    savedAuthUser = cached.authUser
                }
            }
            let displayHost = target.instanceId.isEmpty ? "Antigravity Desktop" : target.instanceId
            return await connectCloudRelay(
                relayURLString: trimmed,
                sessionCookie: effectiveCookie,
                authUser: savedAuthUser,
                deepLinkedConversationId: target.conversationId,
                hostName: displayHost
            )
        }

        return await connectDirectLAN(endpointURLString: trimmed, csrfToken: fallbackCookie)
    }

    /// Connects directly to Mac `language_server` or `mac-companion-bridge.py` over LAN / Tailscale
    /// using `x-codeium-csrf-token` + SHA-256 certificate pinning / TOFU.
    @discardableResult
    public func connectDirectLAN(
        endpointURLString: String,
        csrfToken: String,
        certSHA256: String? = nil,
        hostName: String = "MacBook Pro",
        isRestoringSavedSession: Bool = false
    ) async -> Bool {
        guard let url = URL(string: endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil else {
            connectionErrorText = "Invalid endpoint URL: \(endpointURLString)"
            return false
        }

        isConnectingToBackend = true
        connectionErrorText = nil
        connectionStatusText = "Handshaking with \(url.host ?? endpointURLString)..."
        defer { isConnectingToBackend = false }

        let hostInstance = RemoteHostInstance(
            instanceId: "direct-\(url.host ?? "mac")",
            hostname: hostName,
            channel: .directHost,
            endpointURL: url,
            isOnline: true,
            certificateFingerprintSHA256: certSHA256 ?? "TOFU-LOCAL-TLS"
        )
        let candidateClient = AntigravityRPCClient(
            host: hostInstance,
            csrfToken: csrfToken,
            pinnedFingerprintSHA256: certSHA256
        )

        do {
            let handshake = try await candidateClient.verifyConnection()
            applyVerifiedLiveConnection(
                host: hostInstance,
                client: candidateClient,
                handshake: handshake
            )
            await KeychainStore.shared.saveCredentials(
                SavedBackendCredentials(
                    endpointURLString: url.absoluteString,
                    channel: .directHost,
                    hostname: hostName,
                    csrfToken: csrfToken,
                    certFingerprintSHA256: certSHA256
                )
            )
            return true
        } catch let AntigravityRPCError.unauthorized(reason) {
            let errMsg = "Authentication rejected (401/403): check x-codeium-csrf-token. \(reason)"
            let statusMsg = "Auth Failed · Invalid CSRF Token"
            if isRestoringSavedSession || hasPairedBackend {
                await applyOfflinePairedSession(
                    host: hostInstance,
                    client: candidateClient,
                    errorText: errMsg,
                    statusText: "Offline · \(hostName) (Auth Expired)"
                )
            } else {
                isLiveBackendConnected = false
                connectionErrorText = errMsg
                connectionStatusText = statusMsg
            }
            return false
        } catch {
            let errMsg = "Connection failed: \(error.localizedDescription)"
            if isRestoringSavedSession || hasPairedBackend {
                await applyOfflinePairedSession(
                    host: hostInstance,
                    client: candidateClient,
                    errorText: errMsg,
                    statusText: "Offline · \(hostName)"
                )
            } else {
                isLiveBackendConnected = false
                connectionErrorText = errMsg
                connectionStatusText = "Unreachable · \(url.host ?? endpointURLString)"
            }
            return false
        }
    }

    ///Resolves HTTP redirects for official Google shortlinks (`g.co`, `c.gle`, `goo.gl`, `*.page.link`)
    /// using an ephemeral `URLSession` (without attaching session cookies) so the target `/r/<instance-id>` is discovered.
    nonisolated private static func resolveShortlinkRedirectIfNeeded(_ urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 10
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        var headReq = URLRequest(url: url)
        headReq.httpMethod = "HEAD"
        if let (_, resp) = try? await session.data(for: headReq),
           let finalStr = resp.url?.absoluteString,
           finalStr != urlString,
           RemoteHostInstance.parseRemoteControlTarget(finalStr) != nil {
            return finalStr
        }

        var getReq = URLRequest(url: url)
        getReq.httpMethod = "GET"
        if let (_, resp) = try? await session.data(for: getReq),
           let finalStr = resp.url?.absoluteString,
           finalStr != urlString,
           RemoteHostInstance.parseRemoteControlTarget(finalStr) != nil {
            return finalStr
        }
        return nil
    }

    /// Connects to official Google Cloud Remote Control Relay (`https://antigravity.google.com/r/<instance-id>`)
    /// via `devtools_jetski_boq_api_proto.ApiService` (`ListInstances` + `ProxyCommand` + `SAPISIDHASH`).
    @discardableResult
    public func connectCloudRelay(
        relayURLString: String,
        sessionCookie: String,
        authUser: String? = nil,
        resolvedInstanceUuid: String? = nil,
        deepLinkedConversationId: String? = nil,
        hostName: String = "Antigravity Desktop",
        isRestoringSavedSession: Bool = false
    ) async -> Bool {
        let trimmedInput = relayURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        var parsedTarget = RemoteHostInstance.parseRemoteControlTarget(
            trimmedInput.isEmpty ? SAPISIDHashGenerator.defaultOrigin : trimmedInput
        )
        var canonicalURLString = parsedTarget?.canonicalRelayURLString ?? trimmedInput
        guard URL(string: canonicalURLString)?.scheme != nil else {
            connectionErrorText = "Invalid Remote Control QR link: \(relayURLString)"
            return false
        }

        lastScannedRelayURL = canonicalURLString
        let trimmedCookie = sessionCookie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCookie.isEmpty else {
            isLiveBackendConnected = false
            let fallbackName = parsedTarget?.instanceId.isEmpty == false ? parsedTarget!.instanceId : "Antigravity Desktop"
            connectionErrorText = "Google Sign-In required: sign in once to pair with \(fallbackName)."
            connectionStatusText = "Sign in with Google to pair Remote Control"
            return false
        }

        isConnectingToBackend = true
        connectionErrorText = nil
        defer { isConnectingToBackend = false }

        if parsedTarget?.requiresRedirectResolution == true,
           let origURL = parsedTarget?.originalURLString {
            connectionStatusText = "Resolving Remote Control link..."
            if let resolvedStr = await Self.resolveShortlinkRedirectIfNeeded(origURL),
               let resolvedTarget = RemoteHostInstance.parseRemoteControlTarget(resolvedStr) {
                parsedTarget = resolvedTarget
                canonicalURLString = resolvedTarget.canonicalRelayURLString
                lastScannedRelayURL = canonicalURLString
            }
        }

        guard let url = URL(string: canonicalURLString), url.scheme != nil else {
            connectionErrorText = "Invalid Remote Control QR link: \(relayURLString)"
            return false
        }

        let targetBadge = parsedTarget?.instanceId.isEmpty == false ? parsedTarget!.instanceId : "Cloud Relay"
        connectionStatusText = "Pairing with \(targetBadge) via Google Cloud Relay..."

        let effectiveAuthUser = authUser ?? parsedTarget?.authUser
        let initialInstanceId = parsedTarget?.instanceId.isEmpty == false ? parsedTarget!.instanceId : "auto"
        let deepLinkConv = deepLinkedConversationId ?? parsedTarget?.conversationId

        let hostInstance = RemoteHostInstance(
            instanceId: resolvedInstanceUuid ?? initialInstanceId,
            hostname: hostName,
            channel: .cloudRelay,
            endpointURL: url,
            isOnline: true
        )
        let candidateClient = AntigravityRPCClient(
            host: hostInstance,
            sessionCookie: trimmedCookie,
            authUser: effectiveAuthUser,
            resolvedInstanceUuid: resolvedInstanceUuid
        )

        do {
            let handshake = try await candidateClient.verifyConnection()
            let finalHostName = handshake.resolvedHostname ?? hostName
            let finalUuid = handshake.resolvedInstanceUuid ?? hostInstance.instanceId
            let finalAuthUser = handshake.resolvedAuthUser ?? effectiveAuthUser ?? "0"
            let originPrefix = parsedTarget?.relayOrigin ?? SAPISIDHashGenerator.defaultOrigin
            let finalRelayURL = URL(string: "\(originPrefix)/r/\(finalUuid)") ?? url

            let verifiedHost = RemoteHostInstance(
                instanceId: finalUuid,
                hostname: finalHostName,
                version: handshake.serverVersion,
                channel: .cloudRelay,
                endpointURL: finalRelayURL,
                isOnline: true,
                latencyMs: handshake.latencyMs
            )

            availableRelayInstances = handshake.availableRelayInstances
            activeAuthUser = finalAuthUser
            applyVerifiedLiveConnection(
                host: verifiedHost,
                client: candidateClient,
                handshake: handshake
            )

            // Register all reachable Cloud Relay instances in `hosts` so the user can switch Macs from Home
            for inst in handshake.availableRelayInstances where inst.uuid != finalUuid {
                let instURL = URL(string: "\(originPrefix)/r/\(inst.uuid)") ?? finalRelayURL
                let peerHost = RemoteHostInstance(
                    instanceId: inst.uuid,
                    hostname: inst.name,
                    version: inst.version,
                    channel: .cloudRelay,
                    endpointURL: instURL,
                    isOnline: inst.status.isReachable,
                    latencyMs: handshake.latencyMs
                )
                if let existingIdx = hosts.firstIndex(where: { $0.instanceId == peerHost.instanceId }) {
                    hosts[existingIdx] = peerHost
                } else {
                    hosts.append(peerHost)
                }
            }

            await KeychainStore.shared.saveCredentials(
                SavedBackendCredentials(
                    endpointURLString: finalRelayURL.absoluteString,
                    channel: .cloudRelay,
                    hostname: finalHostName,
                    sessionCookie: trimmedCookie,
                    authUser: finalAuthUser,
                    resolvedInstanceUuid: finalUuid
                )
            )

            if let deepLinkConv, !deepLinkConv.isEmpty {
                selectCascade(deepLinkConv)
            }
            return true
        } catch let AntigravityRPCError.unauthorized(reason) {
            let errMsg = "Google session unauthorized: please sign in again. (\(reason))"
            if isRestoringSavedSession {
                await applyOfflinePairedSession(
                    host: hostInstance,
                    client: candidateClient,
                    errorText: errMsg,
                    statusText: "Google Sign-In Expired"
                )
            } else {
                isLiveBackendConnected = false
                connectionErrorText = errMsg
                connectionStatusText = "Google Sign-In Expired"
            }
            return false
        } catch let AntigravityRPCError.httpError(code, body) {
            let errMsg = "Cloud Relay error (\(code)): \(body)"
            if (isRestoringSavedSession || hasPairedBackend) && (code == 502 || code == 503 || code == 504) {
                await applyOfflinePairedSession(
                    host: hostInstance,
                    client: candidateClient,
                    errorText: errMsg,
                    statusText: "Offline · \(hostName)"
                )
            } else {
                isLiveBackendConnected = false
                connectionErrorText = errMsg
                connectionStatusText = "Cloud Relay Handshake Failed"
            }
            return false
        } catch {
            let errMsg = "Cloud Relay handshake failed: \(error.localizedDescription)"
            if isRestoringSavedSession || hasPairedBackend {
                await applyOfflinePairedSession(
                    host: hostInstance,
                    client: candidateClient,
                    errorText: errMsg,
                    statusText: "Offline · \(hostName)"
                )
            } else {
                isLiveBackendConnected = false
                connectionErrorText = errMsg
                connectionStatusText = "Cloud Relay Disconnected"
            }
            return false
        }
    }

    public func disconnectBackendAndClearKeychain() async {
        summaryStreamTask?.cancel()
        cloudSummaryStreamTask?.cancel()
        summaryPollingTask?.cancel()
        stepPollingTask?.cancel()
        hasPairedBackend = false
        isLiveBackendConnected = false
        cloudAgentWarmingUp = false
        consecutiveSyncFailures = 0
        backgroundPollCounter = 0
        optimisticActiveUntilByCascadeId.removeAll()
        syncedConfigCascadeIds.removeAll()
        rpcClient = nil
        lastPingLatencyMs = nil
        availableRelayInstances = []
        connectionErrorText = nil
        connectionStatusText = "Not Connected"
        if !isVerificationMode {
            projects = []
            workspaces = []
            summaries = []
            automations = []
            stepsByCascadeId = [:]
            activeArtifacts = []
            activeTurnDiffs = []
            planChanges = []
            planComments = []
            composerAttachments = []
            composerDraftText = ""
            selectedProjectId = ""
            selectedWorkspaceUri = ""
            activeCascadeId = ""
            activeRoute = .tabRoot
        }
        await KeychainStore.shared.clearCredentials()
    }

    private func applyOfflinePairedSession(
        host: RemoteHostInstance,
        client: AntigravityRPCClient,
        errorText: String,
        statusText: String
    ) async {
        var offlineHost = host
        offlineHost.isOnline = false
        activeHost = offlineHost
        if let existingIdx = hosts.firstIndex(where: { $0.instanceId == offlineHost.instanceId }) {
            hosts[existingIdx] = offlineHost
        } else {
            hosts.insert(offlineHost, at: 0)
        }

        let wasInESDDDemoState = !hasPairedBackend
        hasPairedBackend = true
        isLiveBackendConnected = false
        lastPingLatencyMs = nil
        rpcClient = client
        connectionErrorText = errorText
        connectionStatusText = statusText

        if wasInESDDDemoState {
            let cachedProjects = (await projectionStore.loadProjects()).filter {
                !Self.esddFixtureProjectIds.contains($0.id)
            }
            let cachedSummaries = (await projectionStore.loadProjectedSummaries()).filter {
                !Self.esddFixtureCascadeIds.contains($0.cascadeId)
            }
            var hydratedSummaries = cachedSummaries
            if !cachedProjects.isEmpty || !hydratedSummaries.isEmpty {
                projects = Self.reconcileLiveProjects(
                    workspaces: [],
                    summaries: &hydratedSummaries,
                    existingProjects: cachedProjects,
                    hostName: offlineHost.hostname
                )
                summaries = hydratedSummaries
            } else {
                projects = []
                summaries = []
            }
            workspaces = []
            stepsByCascadeId = [:]
            automations = (await projectionStore.loadAutomations()).filter {
                !Self.esddFixtureAutomationIds.contains($0.id)
            }
            selectedProjectId = projects.first?.id ?? ""
            selectedWorkspaceUri = projects.first?.workspaceUri ?? ""
            activeCascadeId = summaries.first?.cascadeId ?? ""
        }

        startSummarySubscriptionStream()
    }

    internal static func isBackendOfflineError(_ error: Error) -> Bool {
        if error is CancellationError {
            return false
        }
        if let rpcErr = error as? AntigravityRPCError {
            switch rpcErr {
            case .unauthorized, .invalidEndpoint:
                return true
            case .httpError(let statusCode, _):
                return statusCode == -1 || statusCode == 502 || statusCode == 503 || statusCode == 504
            case .decodingError, .interactionRejected:
                return false
            }
        }
        if error is URLError {
            return true
        }
        let nsErr = error as NSError
        if nsErr.domain == NSURLErrorDomain || nsErr.domain == NSPOSIXErrorDomain {
            return true
        }
        return false
    }

    internal func markBackendOffline(error: Error) {
        guard hasPairedBackend || isLiveBackendConnected else { return }
        summaryStreamTask?.cancel()
        summaryStreamTask = nil
        cloudSummaryStreamTask?.cancel()
        cloudSummaryStreamTask = nil
        isLiveBackendConnected = false
        lastPingLatencyMs = nil

        var updatedHost = activeHost
        updatedHost.isOnline = false
        activeHost = updatedHost
        if let idx = hosts.firstIndex(where: { $0.instanceId == updatedHost.instanceId }) {
            hosts[idx] = updatedHost
        }

        connectionErrorText = error.localizedDescription
        connectionStatusText = "Offline · \(updatedHost.hostname)"
    }

    private func markBackendReconnected() {
        let wasOffline = !isLiveBackendConnected || !activeHost.isOnline
        consecutiveSyncFailures = 0
        hasPairedBackend = true
        isLiveBackendConnected = true
        connectionErrorText = nil

        var updatedHost = activeHost
        updatedHost.isOnline = true
        activeHost = updatedHost
        if let idx = hosts.firstIndex(where: { $0.instanceId == updatedHost.instanceId }) {
            hosts[idx] = updatedHost
        }
        connectionStatusText = "Connected · \(updatedHost.hostname)"

        if wasOffline {
            ensureSummaryEnvelopeStreamRunning()
        }
    }

    internal static func normalizeNoProjectSummary(_ s: inout CascadeSummary) {
        guard !esddFixtureCascadeIds.contains(s.cascadeId) else { return }
        guard (s.cloudProjectId ?? "").isEmpty else { return }
        if AntigravityCloudDetector.isGenericContainerURI(s.workspaceUri) {
            s.workspaceUri = ""
        }
        let isScratch = AntigravityCloudDetector.isPlaygroundScratchURI(s.workspaceUri)
        if AntigravityCloudDetector.isNoProjectSlug(s.projectSlug) || isScratch {
            let hasCloudPrefix = s.projectSlug.lowercased().hasPrefix("cloud:")
            s.projectSlug = hasCloudPrefix
                ? "cloud:\(AntigravityCloudDetector.noProjectDisplayName)"
                : AntigravityCloudDetector.noProjectDisplayName
            s.branchName = ""
            if !isScratch && s.workspaceUri.isEmpty == false && AntigravityCloudDetector.isGenericContainerURI(s.workspaceUri) {
                s.workspaceUri = ""
            }
        }
    }

    internal static func reconcileLiveProjects(
        workspaces: [WorkspaceInfo],
        summaries: inout [CascadeSummary],
        existingProjects: [ProjectWorkspace],
        hostName: String,
        cloudProjects: [ProjectWorkspace] = []
    ) -> [ProjectWorkspace] {
        let nonDemoExisting = existingProjects.filter { existing in
            guard !esddFixtureProjectIds.contains(existing.id) else { return false }
            if (existing.cloudProjectId ?? "").isEmpty && AntigravityCloudDetector.isNoProjectSlug(existing.name) {
                return existing.name == AntigravityCloudDetector.noProjectDisplayName
            }
            return true
        }
        var expandedById: [String: Bool] = [:]
        var existingById: [String: ProjectWorkspace] = [:]
        for p in nonDemoExisting {
            expandedById[p.id] = p.isExpandedInHome
            existingById[p.id] = p
        }

        let cloudProjById: [String: ProjectWorkspace] = Dictionary(
            cloudProjects.map { ($0.cloudProjectId ?? $0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let cloudProjByName = Dictionary(grouping: cloudProjects, by: \.name)

        func baseSlug(for rawSlug: String) -> String {
            if rawSlug.hasPrefix("cloud:") {
                return String(rawSlug.dropFirst("cloud:".count))
            }
            return rawSlug
        }

        // Link summaries that carry a `cloudProjectId` to their canonical Cloud project name & URI,
        // and normalize unassigned / legacy `"workspace"` / scratch playground summaries to `"No Project"`.
        for idx in summaries.indices {
            if let cpid = summaries[idx].cloudProjectId, let cp = cloudProjById[cpid] {
                summaries[idx].isCloud = true
                summaries[idx].projectSlug = cp.name
                summaries[idx].workspaceUri = cp.workspaceUri
                summaries[idx].originHostName = "Antigravity"
            } else {
                normalizeNoProjectSummary(&summaries[idx])
            }
        }

        func preferredCloudUri(_ primary: String?, _ secondary: String) -> String {
            if let p = primary, !p.isEmpty {
                let pHasOwner = AntigravityCloudDetector.extractCloudLocationLabel(p)?.contains("/") == true
                let sHasOwner = AntigravityCloudDetector.extractCloudLocationLabel(secondary)?.contains("/") == true
                if !pHasOwner && sHasOwner {
                    return secondary
                }
                return p
            }
            return secondary
        }

        var orderedBaseSlugs: [String] = []
        var seenBaseSlugs = Set<String>()
        for s in summaries {
            let b = baseSlug(for: s.projectSlug)
            if !b.isEmpty && seenBaseSlugs.insert(b).inserted {
                orderedBaseSlugs.append(b)
            }
        }

        let wsByName = Dictionary(grouping: workspaces, by: \.displayName)
        var reconciled: [ProjectWorkspace] = []
        var knownIds = Set<String>()

        for slug in orderedBaseSlugs {
            let isNoProj = AntigravityCloudDetector.isNoProjectSlug(slug)
            let canonicalName = isNoProj ? AntigravityCloudDetector.noProjectDisplayName : slug
            let matchingIndices = summaries.indices.filter { baseSlug(for: summaries[$0].projectSlug) == slug }
            let cloudIndices = matchingIndices.filter { summaries[$0].isCloud }
            let localIndices = matchingIndices.filter { !summaries[$0].isCloud }

            let matchingWorkspaces = isNoProj ? [] : (wsByName[slug] ?? [])
            let cloudWs = matchingWorkspaces.first(where: \.isCloud)
            let localWs = matchingWorkspaces.first(where: { !$0.isCloud })
            let matchedCloudProj = isNoProj ? nil : cloudProjByName[slug]?.first

            if !cloudIndices.isEmpty && !localIndices.isEmpty {
                // Both active local Mac chats and active Cloud chats exist for the same group (`slug` or `No Project`):
                // keep local chats under `canonicalName` and separate Cloud chats under `cloud:<canonicalName>`.
                for idx in localIndices {
                    summaries[idx].projectSlug = canonicalName
                }
                let firstLocal = summaries[localIndices[0]]
                let localUri = isNoProj ? "" : (localWs?.workspaceUri ?? firstLocal.workspaceUri)
                let localBranch = isNoProj ? "" : (localWs?.activeBranch ?? firstLocal.branchName)
                let resolvedLocalHost = localWs?.originHostName ?? firstLocal.originHostName ?? hostName
                let localPathDisplay = isNoProj
                    ? "Unassigned · \(resolvedLocalHost)"
                    : localUri.replacingOccurrences(of: "file://", with: "")
                if knownIds.insert(canonicalName).inserted {
                    reconciled.append(
                        ProjectWorkspace(
                            id: canonicalName,
                            name: canonicalName,
                            pathDisplay: localPathDisplay,
                            workspaceUri: localUri,
                            runtime: .macBookPro,
                            hostName: resolvedLocalHost,
                            activeBranch: localBranch,
                            worktrees: isNoProj ? [] : (localWs?.worktrees.isEmpty == false ? localWs!.worktrees : [localBranch]),
                            isExpandedInHome: expandedById[canonicalName] ?? true,
                            originInstanceUuid: localWs?.originInstanceUuid ?? firstLocal.originInstanceUuid
                        )
                    )
                }

                let cloudId = "cloud:\(canonicalName)"
                for idx in cloudIndices {
                    summaries[idx].projectSlug = cloudId
                }
                let firstCloud = summaries[cloudIndices[0]]
                let cloudUri = isNoProj
                    ? ""
                    : preferredCloudUri(matchedCloudProj?.workspaceUri ?? cloudWs?.workspaceUri, firstCloud.workspaceUri)
                let cloudBranch = isNoProj
                    ? ""
                    : (matchedCloudProj?.activeBranch ?? cloudWs?.activeBranch ?? firstCloud.branchName)
                let cloudPathDisplay = isNoProj ? "Antigravity Cloud · Unassigned" : cloudUri
                if knownIds.insert(cloudId).inserted {
                    reconciled.append(
                        ProjectWorkspace(
                            id: cloudId,
                            name: canonicalName,
                            pathDisplay: cloudPathDisplay,
                            workspaceUri: cloudUri,
                            runtime: .cloud,
                            hostName: "Cloud",
                            activeBranch: cloudBranch,
                            worktrees: isNoProj ? [] : (cloudWs?.worktrees.isEmpty == false ? cloudWs!.worktrees : [cloudBranch]),
                            isExpandedInHome: expandedById[cloudId] ?? true,
                            cloudProjectId: isNoProj ? nil : (matchedCloudProj?.cloudProjectId ?? matchedCloudProj?.id ?? firstCloud.cloudProjectId ?? existingById[cloudId]?.cloudProjectId),
                            originInstanceUuid: matchedCloudProj?.originInstanceUuid ?? firstCloud.originInstanceUuid
                        )
                    )
                }
            } else if !cloudIndices.isEmpty {
                for idx in cloudIndices {
                    summaries[idx].projectSlug = canonicalName
                }
                let firstCloud = summaries[cloudIndices[0]]
                let cloudUri = isNoProj
                    ? ""
                    : preferredCloudUri(matchedCloudProj?.workspaceUri ?? cloudWs?.workspaceUri, firstCloud.workspaceUri)
                let cloudBranch = isNoProj
                    ? ""
                    : (matchedCloudProj?.activeBranch ?? cloudWs?.activeBranch ?? firstCloud.branchName)
                let cloudPathDisplay = isNoProj ? "Antigravity Cloud · Unassigned" : cloudUri
                if knownIds.insert(canonicalName).inserted {
                    reconciled.append(
                        ProjectWorkspace(
                            id: canonicalName,
                            name: canonicalName,
                            pathDisplay: cloudPathDisplay,
                            workspaceUri: cloudUri,
                            runtime: .cloud,
                            hostName: "Cloud",
                            activeBranch: cloudBranch,
                            worktrees: isNoProj ? [] : (cloudWs?.worktrees.isEmpty == false ? cloudWs!.worktrees : [cloudBranch]),
                            isExpandedInHome: expandedById[canonicalName] ?? true,
                            cloudProjectId: isNoProj ? nil : (matchedCloudProj?.cloudProjectId ?? matchedCloudProj?.id ?? firstCloud.cloudProjectId ?? existingById[canonicalName]?.cloudProjectId),
                            originInstanceUuid: matchedCloudProj?.originInstanceUuid ?? firstCloud.originInstanceUuid
                        )
                    )
                }
            } else if !localIndices.isEmpty {
                for idx in localIndices {
                    summaries[idx].projectSlug = canonicalName
                }
                let firstLocal = summaries[localIndices[0]]
                let isWsCloudOnly = !isNoProj && (cloudWs != nil && localWs == nil && AntigravityCloudDetector.isCloudWorkspaceURI(firstLocal.workspaceUri))
                let effectiveUri = isNoProj
                    ? ""
                    : ((isWsCloudOnly ? cloudWs?.workspaceUri : localWs?.workspaceUri) ?? firstLocal.workspaceUri)
                let effectiveBranch = isNoProj ? "" : (localWs?.activeBranch ?? firstLocal.branchName)
                let resolvedLocalHost = localWs?.originHostName ?? firstLocal.originHostName ?? hostName
                let pathDisplay = isNoProj
                    ? "Unassigned · \(resolvedLocalHost)"
                    : effectiveUri.replacingOccurrences(of: "file://", with: "")
                if knownIds.insert(canonicalName).inserted {
                    reconciled.append(
                        ProjectWorkspace(
                            id: canonicalName,
                            name: canonicalName,
                            pathDisplay: pathDisplay,
                            workspaceUri: effectiveUri,
                            runtime: isWsCloudOnly ? .cloud : .macBookPro,
                            hostName: isWsCloudOnly ? "Cloud" : resolvedLocalHost,
                            activeBranch: effectiveBranch,
                            worktrees: isNoProj ? [] : (localWs?.worktrees.isEmpty == false ? localWs!.worktrees : [effectiveBranch]),
                            isExpandedInHome: expandedById[canonicalName] ?? true,
                            originInstanceUuid: localWs?.originInstanceUuid ?? firstLocal.originInstanceUuid
                        )
                    )
                }
            }
        }

        // Append any open 0-conversation workspaces not yet represented above
        for ws in workspaces {
            let slug = ws.displayName
            guard !AntigravityCloudDetector.isNoProjectSlug(slug),
                  !AntigravityCloudDetector.isGenericContainerURI(ws.workspaceUri),
                  !AntigravityCloudDetector.isPlaygroundScratchURI(ws.workspaceUri) else {
                continue
            }
            let isCloud = ws.isCloud || AntigravityCloudDetector.isCloudWorkspaceURI(ws.workspaceUri)
            if reconciled.contains(where: { !$0.workspaceUri.isEmpty && $0.workspaceUri.caseInsensitiveCompare(ws.workspaceUri) == .orderedSame }) {
                continue
            }
            if knownIds.contains(slug) {
                if isCloud,
                   let idx = reconciled.firstIndex(where: { $0.id == slug }),
                   !summaries.contains(where: { $0.projectSlug == slug && !$0.isCloud }) {
                    let mergedUri = preferredCloudUri(reconciled[idx].workspaceUri, ws.workspaceUri)
                    reconciled[idx].runtime = .cloud
                    reconciled[idx].hostName = "Cloud"
                    reconciled[idx].workspaceUri = mergedUri
                    reconciled[idx].pathDisplay = mergedUri
                }
                continue
            }
            knownIds.insert(slug)
            reconciled.append(
                ProjectWorkspace(
                    id: slug,
                    name: slug,
                    pathDisplay: ws.workspaceUri.replacingOccurrences(of: "file://", with: ""),
                    workspaceUri: ws.workspaceUri,
                    runtime: isCloud ? .cloud : .macBookPro,
                    hostName: isCloud ? "Cloud" : (ws.originHostName ?? hostName),
                    activeBranch: ws.activeBranch,
                    worktrees: ws.worktrees.isEmpty ? [ws.activeBranch] : ws.worktrees,
                    isExpandedInHome: expandedById[slug] ?? true,
                    originInstanceUuid: ws.originInstanceUuid
                )
            )
        }

        // Append any 0-conversation Antigravity Cloud (`BACKEND_TYPE_REMOTE_AICODE`) projects
        for cp in cloudProjects {
            let cpid = cp.cloudProjectId ?? cp.id
            if let existingIdx = reconciled.firstIndex(where: { $0.cloudProjectId == cpid || ($0.runtime == .cloud && $0.name == cp.name) }) {
                reconciled[existingIdx].cloudProjectId = reconciled[existingIdx].cloudProjectId ?? cpid
                reconciled[existingIdx].originInstanceUuid = reconciled[existingIdx].originInstanceUuid ?? cp.originInstanceUuid
                continue
            }
            let targetId = knownIds.contains(cp.name) ? "cloud:\(cp.name)" : cp.name
            guard knownIds.insert(targetId).inserted else { continue }
            reconciled.append(
                ProjectWorkspace(
                    id: targetId,
                    name: cp.name,
                    pathDisplay: cp.workspaceUri,
                    workspaceUri: cp.workspaceUri,
                    runtime: .cloud,
                    hostName: "Cloud",
                    activeBranch: cp.activeBranch,
                    worktrees: [cp.activeBranch],
                    isExpandedInHome: expandedById[targetId] ?? true,
                    cloudProjectId: cpid,
                    originInstanceUuid: cp.originInstanceUuid
                )
            )
        }

        // Preserve any user-created empty projects from `existingById` if workspaces didn't report them yet
        if reconciled.isEmpty {
            return nonDemoExisting.map { existing in
                var copy = existing
                if copy.runtime == .macBookPro {
                    copy.hostName = hostName
                }
                return copy
            }
        }

        // Keep all named projects first (preserving recency order) and `No Project` sections cleanly at the bottom
        let namedProjects = reconciled.filter { !$0.isNoProject }
        let unassignedProjects = reconciled.filter(\.isNoProject)
        return namedProjects + unassignedProjects
    }

    /// Queries the connected `language_server` / `agy` daemon for live models, custom agents, and Cloud GitHub repos.
    public func refreshModelCatalog() async {
        guard let client = rpcClient else { return }
        let result = await client.fetchModelCatalog()
        if !result.models.isEmpty {
            availableModels = result.models
            availableAgents = result.agents.isEmpty ? ["Default"] : result.agents

            let currentMode = selectedModelConfig.mode
            let currentPersona = availableAgents.contains(selectedModelConfig.agentPersona)
                ? selectedModelConfig.agentPersona
                : (availableAgents.first ?? "Default")

            let matchedModel: CascadeModelConfig = {
                if let exact = result.models.first(where: { $0.modelId == selectedModelConfig.modelId }) {
                    return exact
                }
                if let defId = result.defaultModelId,
                   let defMatch = result.models.first(where: { $0.modelId == defId }) {
                    return defMatch
                }
                return result.models[0]
            }()

            selectedModelConfig = CascadeModelConfig(
                modelId: matchedModel.modelId,
                displayName: matchedModel.displayName,
                subtitle: matchedModel.subtitle,
                hasThinkingBadge: matchedModel.hasThinkingBadge,
                requiresUpgradeNote: matchedModel.requiresUpgradeNote,
                mode: currentMode,
                agentPersona: currentPersona,
                effort: matchedModel.effort,
                isModelAlias: matchedModel.isModelAlias
            )
        }

        let cloudRepos = await client.fetchCloudGitHubRepos()
        if !cloudRepos.isEmpty {
            availableGitHubRepos = cloudRepos
        }
    }

    private func applyRecordedConversationConfig(from step: CascadeStep) {
        guard step.recordedExecutionMode != nil || step.recordedModelId != nil else { return }
        let nextMode = step.recordedExecutionMode ?? selectedModelConfig.mode
        var matchedModel: CascadeModelConfig? = nil
        if let rawId = step.recordedModelId, !rawId.isEmpty {
            let normalized = AntigravityRPCClient.normalizeProtoModelEnum(rawId)
            matchedModel = availableModels.first(where: {
                $0.modelId == rawId || AntigravityRPCClient.normalizeProtoModelEnum($0.modelId) == normalized
            })
        }
        if let m = matchedModel {
            selectedModelConfig = CascadeModelConfig(
                modelId: m.modelId,
                displayName: m.displayName,
                subtitle: m.subtitle,
                hasThinkingBadge: m.hasThinkingBadge,
                requiresUpgradeNote: m.requiresUpgradeNote,
                mode: nextMode,
                agentPersona: selectedModelConfig.agentPersona,
                effort: m.effort,
                isModelAlias: m.isModelAlias
            )
        } else {
            selectedModelConfig.mode = nextMode
        }
    }

    private func applyVerifiedLiveConnection(
        host: RemoteHostInstance,
        client: AntigravityRPCClient,
        handshake: BackendHandshakeResult
    ) {
        var updatedHost = host
        updatedHost.latencyMs = handshake.latencyMs
        updatedHost.isOnline = true
        activeHost = updatedHost
        if let existingIdx = hosts.firstIndex(where: { $0.instanceId == updatedHost.instanceId }) {
            hosts[existingIdx] = updatedHost
        } else {
            hosts.insert(updatedHost, at: 0)
        }
        rpcClient = client
        consecutiveSyncFailures = 0
        hasPairedBackend = true
        isLiveBackendConnected = true
        lastPingLatencyMs = handshake.latencyMs
        connectionErrorText = nil
        connectionStatusText = "Connected · \(updatedHost.hostname) · \(handshake.latencyMs)ms"

        workspaces = handshake.workspaces
        var sortedSummaries = handshake.summaries.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.cascadeId < rhs.cascadeId
        }
        let nextProjects = Self.reconcileLiveProjects(
            workspaces: handshake.workspaces,
            summaries: &sortedSummaries,
            existingProjects: [],
            hostName: updatedHost.hostname,
            cloudProjects: handshake.cloudProjects
        )
        summaries = sortedSummaries
        projects = nextProjects
        let defaultProject = nextProjects.first(where: { !$0.isNoProject }) ?? nextProjects.first
        selectedProjectId = defaultProject?.id ?? ""
        selectedWorkspaceUri = defaultProject?.workspaceUri ?? ""
        activeCascadeId = sortedSummaries.first?.cascadeId ?? ""

        // Clear offline ESDD demo state when connected to a live backend
        stepsByCascadeId = [:]
        syncedConfigCascadeIds.removeAll()
        activeTurnDiffs = []
        composerDraftText = ""
        composerAttachments = []
        stepLoadErrorText = nil
        automations = []

        let projectsSnapshot = projects
        let summariesSnapshot = summaries
        let storeRef = projectionStore
        Task { [weak self] in
            await storeRef.saveProjects(projectsSnapshot)
            await storeRef.saveProjectedSummaries(summariesSnapshot)
            await self?.refreshModelCatalog()
            await self?.refreshWorkspacesAndSummaries()
            if let liveAutos = try? await client.listAutomations() {
                self?.automations = liveAutos
                await storeRef.saveAutomations(liveAutos)
            }
        }

        startSummarySubscriptionStream()
        if !activeCascadeId.isEmpty {
            syncStepsForCascade(activeCascadeId, pollUntilIdle: false)
        }
    }

    private func ensureSummaryEnvelopeStreamRunning() {
        guard let client = rpcClient else { return }
        if summaryStreamTask == nil {
            summaryStreamTask = Task { [weak self] in
                defer {
                    self?.summaryStreamTask = nil
                }
                guard let stream = try? await client.subscribeEnvelopeStream(method: "JetboxSubscribeToSummaries") else {
                    return
                }
                do {
                    for try await event in stream {
                        guard let self, !Task.isCancelled else { break }
                        self.applyJetboxSummaryEvent(event, forceCloud: false)
                    }
                } catch {
                    // Stream ended or closed; concurrent polling task keeps state synchronized and reconnects.
                }
            }
        }

        if cloudSummaryStreamTask == nil {
            cloudSummaryStreamTask = Task { [weak self] in
                defer {
                    self?.cloudSummaryStreamTask = nil
                }
                guard let stream = try? await client.subscribeEnvelopeStream(
                    method: "JetboxSubscribeToSummaries",
                    requestPayload: ["backend": .string("BACKEND_TYPE_REMOTE_AICODE")]
                ) else {
                    return
                }
                do {
                    for try await event in stream {
                        guard let self, !Task.isCancelled else { break }
                        self.applyJetboxSummaryEvent(event, forceCloud: true)
                    }
                } catch {
                    // Cloud summary stream ended or unsupported on mock server.
                }
            }
        }
    }

    /// Subscribes to Connect-RPC 5-byte framed `JetboxSubscribeToSummaries` stream (both Local and Antigravity Cloud)
    /// AND runs a concurrent live sync / health-check loop so Desktop & Cloud sidebar changes AND offline/online
    /// host transitions reflect automatically on iOS in real time.
    public func startSummarySubscriptionStream() {
        summaryStreamTask?.cancel()
        summaryStreamTask = nil
        cloudSummaryStreamTask?.cancel()
        cloudSummaryStreamTask = nil
        summaryPollingTask?.cancel()
        guard rpcClient != nil else { return }

        if isLiveBackendConnected {
            ensureSummaryEnvelopeStreamRunning()
        }

        summaryPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                let isRelay = (self?.activeHost.channel == .cloudRelay)
                let intervalNs: UInt64 = {
                    if isRelay {
                        return (self?.isLiveBackendConnected == true) ? 7_000_000_000 : 3_000_000_000
                    }
                    return (self?.isLiveBackendConnected == true) ? 1_500_000_000 : 2_000_000_000
                }()
                try? await Task.sleep(nanoseconds: intervalNs)
                guard let self, !Task.isCancelled, (self.hasPairedBackend || self.isLiveBackendConnected) else { break }
                await self.refreshWorkspacesAndSummaries()
            }
        }
    }

    /// Handles both Antigravity 2.0.11+ `{"updates": {"<cascadeId>": {...}}, "deletes": [...]}` frames
    /// and single-cascade `{"cascadeId": "...", "status": "..."}` frames.
    private func applyJetboxSummaryEvent(_ event: [String: JSONValue], forceCloud: Bool = false) {
        var changedIds = Set<String>()
        let existingCloudProjects = projects.filter { $0.runtime == .cloud && $0.cloudProjectId != nil }
        let cloudProjById: [String: ProjectWorkspace] = Dictionary(
            existingCloudProjects.compactMap { cp in
                guard let cpid = cp.cloudProjectId, !cpid.isEmpty else { return nil }
                return (cpid, cp)
            },
            uniquingKeysWith: { first, _ in first }
        )

        let decodedBatch = AntigravityRPCClient.decodeJetboxSummariesEvent(
            event,
            forceCloud: forceCloud,
            originInstanceUuid: activeHost.instanceId,
            originHostName: forceCloud ? "Antigravity" : activeHost.hostname,
            cloudProjectsById: cloudProjById
        )
        if !decodedBatch.upserts.isEmpty {
            for decoded in decodedBatch.upserts {
                let cid = decoded.cascadeId
                changedIds.insert(cid)
                if let idx = summaries.firstIndex(where: { $0.cascadeId == cid }) {
                    let prevStepCount = summaries[idx].stepCount
                    var merged = decoded
                    if summaries[idx].title != "New Conversation" && merged.title == "New Conversation" {
                        merged.title = summaries[idx].title
                    }
                    if summaries[idx].isCloud && !merged.isCloud {
                        merged.isCloud = true
                        merged.originHostName = "Antigravity"
                    }
                    merged.isPinned = summaries[idx].isPinned || decoded.isPinned
                    merged.isArchived = summaries[idx].isArchived || decoded.isArchived
                    merged.stepCount = max(prevStepCount, decoded.stepCount)
                    merged.cloudProjectId = decoded.cloudProjectId ?? summaries[idx].cloudProjectId
                    if let optimisticExpiry = optimisticActiveUntilByCascadeId[cid],
                       optimisticExpiry > Date(),
                       merged.status != .waiting && merged.status != .blocked && merged.status != .error {
                        merged.status = .inProgress
                    }
                    if merged.stepCount > prevStepCount && activeRoute != .cascadeChat(cid) {
                        merged.isUnread = true
                        locallyViewedAtByCascadeId.removeValue(forKey: cid)
                    }
                    summaries[idx] = merged
                } else {
                    summaries.insert(decoded, at: 0)
                }
            }
            var updatedSummaries = summaries
            projects = Self.reconcileLiveProjects(
                workspaces: workspaces,
                summaries: &updatedSummaries,
                existingProjects: projects,
                hostName: activeHost.hostname,
                cloudProjects: existingCloudProjects
            )
            summaries = updatedSummaries
        }

        if !decodedBatch.deletes.isEmpty {
            let deletedIds = Set(decodedBatch.deletes)
            summaries.removeAll { deletedIds.contains($0.cascadeId) }
        }

        if let cid = event["cascadeId"]?.stringValue {
            changedIds.insert(cid)
            let statusRaw = event["status"]?.stringValue ?? "CORTEX_STEP_STATUS_IN_PROGRESS"
            let newStatus = CortexStepStatus.from(jsonName: statusRaw)
            let stepCount = event["stepCount"]?.intValue
            let title = event["title"]?.stringValue
            if let idx = summaries.firstIndex(where: { $0.cascadeId == cid }) {
                summaries[idx].status = newStatus
                if let stepCount { summaries[idx].stepCount = stepCount }
                if let title, !title.isEmpty { summaries[idx].title = title }
                summaries[idx].updatedAt = Date()
                summaries[idx].relativeTimeLabel = "now"
                summaries[idx].statusSubtitle = AntigravityRPCClient.buildLiveStatusSubtitle(
                    status: newStatus,
                    stepCount: summaries[idx].stepCount,
                    isUnread: summaries[idx].isUnread,
                    explicitSubtitle: event["summary"]?.stringValue
                )
            }
        }

        if !activeCascadeId.isEmpty && changedIds.contains(activeCascadeId) {
            syncStepsForCascade(activeCascadeId, pollUntilIdle: activeRoute == .cascadeChat(activeCascadeId))
        }
    }

    /// Reconciles summary streaming state from fetched trajectory steps without prematurely flipping
    /// an active turn to `.done` while the agent is preparing its first step or thinking between tool calls.
    public static func reconcileSummaryStreamingStatus(
        currentStatus: CortexStepStatus,
        remoteSteps: [CascadeStep],
        withinOptimisticSendWindow: Bool
    ) -> (status: CortexStepStatus, stillActive: Bool) {
        if remoteSteps.contains(where: { $0.status == .waiting || $0.status == .blocked }) {
            return (.waiting, false)
        }
        if remoteSteps.contains(where: { $0.status == .inProgress || $0.status == .pending }) {
            return (.inProgress, true)
        }
        if let lastStep = remoteSteps.last, (lastStep.status == .error || lastStep.status == .cancelled) {
            return (lastStep.status, false)
        }

        let lastUserIdx = remoteSteps.lastIndex(where: { $0.type == .userInput })
        let turnTail: ArraySlice<CascadeStep> = {
            if let lastUserIdx {
                return remoteSteps[(lastUserIdx + 1)...]
            }
            return remoteSteps[...]
        }()
        let hasCompletedAssistantReply = turnTail.contains { step in
            (step.type == .plannerResponse || step.type == .notifyUser)
                && step.status == .done
                && !(step.plannerResponse?.response ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let lastVisible = remoteSteps.last(where: { $0.hasRenderableChatContent }) ?? remoteSteps.last
        let endsMidTurn: Bool = {
            guard let lastVisible else { return remoteSteps.isEmpty }
            if lastVisible.status == .error || lastVisible.status == .cancelled {
                return false
            }
            switch lastVisible.type {
            case .userInput, .taskBoundary, .viewFile, .viewContentChunk, .search, .listDirectory, .codeAction:
                return true
            case .runCommand:
                return lastVisible.runCommand?.exitCode == nil || !hasCompletedAssistantReply
            default:
                return false
            }
        }()

        if withinOptimisticSendWindow && !hasCompletedAssistantReply {
            return (.inProgress, true)
        }
        if currentStatus == .inProgress || currentStatus == .pending {
            if hasCompletedAssistantReply && !endsMidTurn {
                return (.done, false)
            }
            if remoteSteps.isEmpty || endsMidTurn || !hasCompletedAssistantReply {
                return (.inProgress, true)
            }
            return (.done, false)
        }
        return (currentStatus, false)
    }

    /// Synchronizes `GetCascadeTrajectorySteps` (`stepOffset` JSON `<600`, Binary Protobuf `>=600`) for `cascadeId`.
    /// Polls every 350ms while the agent turn is actively streaming (`inProgress` or `pending`), and every 1.0s
    /// while the user is viewing the conversation (`activeRoute == .cascadeChat(cascadeId)`) so PC/Cloud-originated
    /// messages appear on iOS immediately.
    public func syncStepsForCascade(_ cascadeId: String, pollUntilIdle: Bool = true) {
        stepPollingTask?.cancel()
        guard (hasPairedBackend || isLiveBackendConnected), let client = rpcClient, !cascadeId.isEmpty else { return }

        stepLoadErrorText = nil

        // Local optimistic IDs (`cas-<8hex>`) have not been materialized on the server via `StartCascade` yet.
        // Never show a stuck "Loading conversation history..." spinner or `not_found` error on them.
        if cascadeId.hasPrefix("cas-") && !Self.esddFixtureCascadeIds.contains(cascadeId) {
            isLoadingSteps = false
            return
        }

        let initialSummary = summaries.first(where: { $0.cascadeId == cascadeId })
        let withinInitialOptimisticSend = (optimisticActiveUntilByCascadeId[cascadeId].map { $0 > Date() } ?? false)
        let isBrandNewEmptySession = (initialSummary != nil)
            && (initialSummary?.stepCount == 0)
            && (initialSummary?.status != .inProgress)
            && (initialSummary?.status != .pending)
            && !withinInitialOptimisticSend
        let isKnownOfflineLocal = hasPairedBackend
            && (!isLiveBackendConnected || !activeHost.isOnline)
            && (initialSummary?.isCloud != true)

        if isBrandNewEmptySession && isKnownOfflineLocal {
            isLoadingSteps = false
            return
        }

        if (stepsByCascadeId[cascadeId] ?? []).isEmpty && !isBrandNewEmptySession {
            isLoadingSteps = true
        } else {
            isLoadingSteps = false
        }
        let storeRef = projectionStore

        stepPollingTask = Task { [weak self] in
            defer {
                if self?.activeCascadeId == cascadeId {
                    self?.isLoadingSteps = false
                }
            }
            if (self?.stepsByCascadeId[cascadeId] ?? []).isEmpty {
                let cached = await storeRef.loadProjectedSteps(cascadeId: cascadeId)
                if !cached.isEmpty, let self, (self.stepsByCascadeId[cascadeId] ?? []).isEmpty {
                    self.stepsByCascadeId[cascadeId] = cached
                    if self.activeCascadeId == cascadeId {
                        self.isLoadingSteps = false
                    }
                }
            }

            var attempts = 0
            let maxAttempts = pollUntilIdle ? 10_000 : 1
            while !Task.isCancelled && attempts < maxAttempts {
                attempts += 1
                let summaryMeta = self?.summaries.first(where: { $0.cascadeId == cascadeId })
                let knownCount = summaryMeta?.stepCount ?? 0
                let originUuid = summaryMeta?.originInstanceUuid
                let isEmptyNewSessionNow = (summaryMeta != nil)
                    && knownCount == 0
                    && summaryMeta?.status != .inProgress
                    && summaryMeta?.status != .pending
                    && !(self?.optimisticActiveUntilByCascadeId[cascadeId].map { $0 > Date() } ?? false)
                var stillActive = false
                do {
                    let remoteSteps = try await client.fetchAllTrajectorySteps(
                        cascadeId: cascadeId,
                        knownStepCount: knownCount,
                        instanceUuidOverride: originUuid
                    )
                    guard let self, !Task.isCancelled else { return }
                    if self.hasPairedBackend && (!self.isLiveBackendConnected || !self.activeHost.isOnline) {
                        self.markBackendReconnected()
                    }
                    self.stepLoadErrorText = nil
                    if self.activeCascadeId == cascadeId {
                        self.isLoadingSteps = false
                    }

                    let withinOptimisticWindow = (self.optimisticActiveUntilByCascadeId[cascadeId].map { $0 > Date() } ?? false)
                    if !remoteSteps.isEmpty {
                        self.stepsByCascadeId[cascadeId] = remoteSteps
                        await storeRef.saveProjectedSteps(remoteSteps, for: cascadeId)
                        if !self.syncedConfigCascadeIds.contains(cascadeId),
                           let latestCfgStep = remoteSteps.last(where: {
                               $0.type == .userInput && ($0.recordedExecutionMode != nil || $0.recordedModelId != nil)
                           }) {
                            self.syncedConfigCascadeIds.insert(cascadeId)
                            if self.activeCascadeId == cascadeId {
                                self.applyRecordedConversationConfig(from: latestCfgStep)
                            }
                        }
                        if let sumIdx = self.summaries.firstIndex(where: { $0.cascadeId == cascadeId }) {
                            self.summaries[sumIdx].stepCount = max(self.summaries[sumIdx].stepCount, remoteSteps.count)
                            if self.summaries[sumIdx].title == "New Conversation",
                               let firstPrompt = remoteSteps.first(where: { $0.type == .userInput })?.userInput?
                                   .trimmingCharacters(in: .whitespacesAndNewlines),
                               !firstPrompt.isEmpty {
                                self.summaries[sumIdx].title = String(firstPrompt.prefix(56))
                            }
                            let reconciled = Self.reconcileSummaryStreamingStatus(
                                currentStatus: self.summaries[sumIdx].status,
                                remoteSteps: remoteSteps,
                                withinOptimisticSendWindow: withinOptimisticWindow
                            )
                            self.summaries[sumIdx].status = reconciled.status
                            stillActive = reconciled.stillActive
                            if !reconciled.stillActive {
                                self.optimisticActiveUntilByCascadeId.removeValue(forKey: cascadeId)
                            }
                            self.summaries[sumIdx].statusSubtitle = AntigravityRPCClient.buildLiveStatusSubtitle(
                                status: self.summaries[sumIdx].status,
                                stepCount: self.summaries[sumIdx].stepCount,
                                isUnread: self.summaries[sumIdx].isUnread
                            )
                        } else {
                            stillActive = remoteSteps.contains { $0.status == .inProgress || $0.status == .pending }
                                || withinOptimisticWindow
                        }
                    } else {
                        stillActive = withinOptimisticWindow
                            || summaryMeta?.status == .inProgress
                            || summaryMeta?.status == .pending
                    }
                } catch {
                    if let self, !Task.isCancelled {
                        if Self.isBackendOfflineError(error) && self.activeHost.channel != .cloudRelay {
                            self.markBackendOffline(error: error)
                        }
                        if self.activeCascadeId == cascadeId {
                            self.isLoadingSteps = false
                            if (self.stepsByCascadeId[cascadeId] ?? []).isEmpty && !isEmptyNewSessionNow {
                                self.stepLoadErrorText = error.localizedDescription
                            }
                        }
                    }
                    if !pollUntilIdle { break }
                }

                guard let self, !Task.isCancelled else { break }
                if !pollUntilIdle {
                    break
                }
                let isViewingThisChat = (self.activeRoute == .cascadeChat(cascadeId) && self.activeCascadeId == cascadeId)
                if !stillActive && !isViewingThisChat {
                    break
                }
                let isHostOffline = !self.isLiveBackendConnected || !self.activeHost.isOnline
                let sleepNs: UInt64 = stillActive ? 350_000_000 : (isHostOffline ? 2_500_000_000 : 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepNs)
            }
        }
    }

    // MARK: - Navigation & Display Options Actions (`UE01`, `UE02`)

    public func selectHost(_ host: RemoteHostInstance) {
        activeHost = host
        if (hasPairedBackend || isLiveBackendConnected), host.channel == .cloudRelay {
            let authIdx = activeAuthUser
            Task { [weak self] in
                guard let self, let cached = await self.loadSavedSessionCookie() else { return }
                _ = await self.connectCloudRelay(
                    relayURLString: host.endpointURL.absoluteString,
                    sessionCookie: cached.cookie,
                    authUser: cached.authUser ?? authIdx,
                    resolvedInstanceUuid: host.instanceId,
                    hostName: host.hostname
                )
            }
            return
        }
        rpcClient = AntigravityRPCClient(
            host: host,
            csrfToken: "csrf-antigravity-ios-session-token"
        )
    }

    public func selectProject(_ projectSlug: String) {
        selectedProjectId = projectSlug
        if let project = projects.first(where: { $0.id == projectSlug }) {
            selectedWorkspaceUri = project.workspaceUri
        }
        activeRoute = .projectDetail(projectSlug)
    }

    public func toggleProjectExpandedInHome(_ projectSlug: String) {
        guard let idx = projects.firstIndex(where: { $0.id == projectSlug }) else { return }
        projects[idx].isExpandedInHome.toggle()
    }

    public func selectWorkspace(_ workspaceUri: String) {
        selectedWorkspaceUri = workspaceUri
        selectedWorktreeFilter = nil
        if let firstCascade = summaries.first(where: { $0.workspaceUri == workspaceUri && !$0.isArchived }) {
            selectCascade(firstCascade.cascadeId)
        }
    }

    public func selectCascade(_ cascadeId: String) {
        activeCascadeId = cascadeId
        locallyViewedAtByCascadeId[cascadeId] = Date()
        if let idx = summaries.firstIndex(where: { $0.cascadeId == cascadeId }) {
            summaries[idx].isUnread = false
            selectedWorkspaceUri = summaries[idx].workspaceUri
            selectedProjectId = summaries[idx].projectSlug
            if hasPairedBackend || isLiveBackendConnected {
                summaries[idx].statusSubtitle = AntigravityRPCClient.buildLiveStatusSubtitle(
                    status: summaries[idx].status,
                    stepCount: summaries[idx].stepCount,
                    isUnread: false
                )
            }
        }
        if let cachedSteps = stepsByCascadeId[cascadeId],
           let latestCfgStep = cachedSteps.last(where: {
               $0.type == .userInput && ($0.recordedExecutionMode != nil || $0.recordedModelId != nil)
           }) {
            applyRecordedConversationConfig(from: latestCfgStep)
        }
        activeRoute = .cascadeChat(cascadeId)
        unreadStreamingStepCount = 0
        isAutoScrollPinnedToBottom = true
        if hasPairedBackend || isLiveBackendConnected {
            syncStepsForCascade(cascadeId, pollUntilIdle: true)
        }
    }

    public func resetDisplayOptions() {
        displayOptions = AgentDisplayOptions()
        let opts = displayOptions
        let storeRef = projectionStore
        Task {
            await storeRef.saveDisplayOptions(opts)
        }
    }

    public func markAllConversationsAsRead() {
        let now = Date()
        for idx in summaries.indices {
            summaries[idx].isUnread = false
            locallyViewedAtByCascadeId[summaries[idx].cascadeId] = now
        }
        let snapshot = summaries
        let storeRef = projectionStore
        Task {
            await storeRef.saveProjectedSummaries(snapshot)
        }
    }

    // MARK: - Conversation Context Menu & Swipe Actions (`UE03`)

    public func togglePinCascade(_ cascadeId: String) {
        guard let idx = summaries.firstIndex(where: { $0.cascadeId == cascadeId }) else { return }
        summaries[idx].isPinned.toggle()
        let isPinned = summaries[idx].isPinned
        let originUuid = summaries[idx].originInstanceUuid
        let snapshot = summaries
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.saveProjectedSummaries(snapshot)
            try? await clientRef?.pinCascade(cascadeId: cascadeId, isPinned: isPinned, instanceUuidOverride: originUuid)
        }
    }

    public func toggleUnreadCascade(_ cascadeId: String) {
        guard let idx = summaries.firstIndex(where: { $0.cascadeId == cascadeId }) else { return }
        summaries[idx].isUnread.toggle()
        if summaries[idx].isUnread {
            locallyViewedAtByCascadeId.removeValue(forKey: cascadeId)
        } else {
            locallyViewedAtByCascadeId[cascadeId] = Date()
        }
        let snapshot = summaries
        let storeRef = projectionStore
        Task {
            await storeRef.saveProjectedSummaries(snapshot)
        }
    }

    public func renameCascade(_ cascadeId: String, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = summaries.firstIndex(where: { $0.cascadeId == cascadeId }) else { return }
        summaries[idx].title = trimmed
        let originUuid = summaries[idx].originInstanceUuid
        let snapshot = summaries
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.saveProjectedSummaries(snapshot)
            try? await clientRef?.renameCascade(cascadeId: cascadeId, newTitle: trimmed, instanceUuidOverride: originUuid)
        }
    }

    public func moveCascade(_ cascadeId: String, toProject projectSlug: String) {
        guard let idx = summaries.firstIndex(where: { $0.cascadeId == cascadeId }) else { return }
        summaries[idx].projectSlug = projectSlug
        let targetUri = projects.first(where: { $0.id == projectSlug })?.workspaceUri ?? summaries[idx].workspaceUri
        summaries[idx].workspaceUri = targetUri
        let originUuid = summaries[idx].originInstanceUuid
        let snapshot = summaries
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.saveProjectedSummaries(snapshot)
            try? await clientRef?.moveCascadeToWorkspace(cascadeId: cascadeId, workspaceUri: targetUri, instanceUuidOverride: originUuid)
        }
    }

    public func archiveCascade(_ cascadeId: String) {
        guard let idx = summaries.firstIndex(where: { $0.cascadeId == cascadeId }) else { return }
        summaries[idx].isArchived = true
        let originUuid = summaries[idx].originInstanceUuid
        if activeCascadeId == cascadeId, let next = filteredSummaries.first {
            activeCascadeId = next.cascadeId
        }
        let snapshot = summaries
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.saveProjectedSummaries(snapshot)
            try? await clientRef?.archiveCascade(cascadeId: cascadeId, isArchived: true, instanceUuidOverride: originUuid)
        }
    }

    public func deleteCascade(_ cascadeId: String) {
        let originUuid = summaries.first(where: { $0.cascadeId == cascadeId })?.originInstanceUuid
        summaries.removeAll { $0.cascadeId == cascadeId }
        stepsByCascadeId.removeValue(forKey: cascadeId)
        if activeCascadeId == cascadeId, let next = filteredSummaries.first {
            activeCascadeId = next.cascadeId
        }
        let snapshot = summaries
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.saveProjectedSummaries(snapshot)
            try? await clientRef?.deleteCascade(cascadeId: cascadeId, instanceUuidOverride: originUuid)
        }
    }

    // MARK: - Project Creation & Scoped Conversation Actions (`UE04`, `UE05`)

    @discardableResult
    public func createNewProject(
        name: String? = nil,
        runtime: ProjectRuntimeTarget? = nil,
        source: ProjectSourceKind? = nil,
        selectedRepo: GitHubRepoItem? = nil,
        branchWorktree: String? = nil
    ) -> ProjectWorkspace {
        var draft = newProjectDraft
        if let runtime { draft.runsOn = runtime }
        if let source { draft.source = source }
        if let selectedRepo { draft.selectedRepo = selectedRepo }
        if let branchWorktree { draft.branchWorktree = branchWorktree }
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.projectName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let slug = draft.projectName.isEmpty ? "new-project" : draft.projectName
        let repoPath = draft.selectedRepo?.fullName ?? "acme/\(slug)"
        let pathDisplay = draft.runsOn == .cloud ? "cloud://\(repoPath)" : "~/code/\(slug)"
        let workspaceUri = draft.runsOn == .cloud ? "cloud://\(repoPath)" : "file:///Users/wl/code/\(slug)"
        let branch = draft.selectedRepo?.defaultBranch ?? "main"

        let created = ProjectWorkspace(
            id: slug,
            name: slug,
            pathDisplay: pathDisplay,
            workspaceUri: workspaceUri,
            runtime: draft.runsOn,
            hostName: draft.runsOn == .cloud ? "Cloud" : draft.runsOn.rawValue,
            activeBranch: branch,
            worktrees: [branch, "worktree/\(slug)"],
            isExpandedInHome: true,
            rulesAndSkillsCount: 4
        )
        if let existingIdx = projects.firstIndex(where: { $0.id == slug }) {
            projects[existingIdx] = created
        } else {
            projects.append(created)
        }
        selectedProjectId = created.id
        selectedWorkspaceUri = created.workspaceUri
        presentedSheet = nil
        activeRoute = .projectDetail(created.id)

        let projectsSnapshot = projects
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task { [weak self] in
            await storeRef.saveProjects(projectsSnapshot)
            if let remoteCreated = try? await clientRef?.createProjectWorkspace(draft: draft),
               let self,
               let idx = self.projects.firstIndex(where: { $0.id == slug }) {
                self.projects[idx].cloudProjectId = remoteCreated.cloudProjectId ?? self.projects[idx].cloudProjectId
                self.projects[idx].originInstanceUuid = remoteCreated.originInstanceUuid ?? self.projects[idx].originInstanceUuid
                await storeRef.saveProjects(self.projects)
            }
        }
        return created
    }

    @discardableResult
    public func createConversationInProject(
        _ projectSlug: String,
        title: String = "New Conversation",
        initialPrompt: String? = nil
    ) -> String {
        let optimisticId = "cas-\(UUID().uuidString.prefix(8).lowercased())"
        let trimmedSlug = projectSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = projects.first(where: { $0.id == trimmedSlug })
            ?? projects.first(where: { $0.name == trimmedSlug })
        let isUnassigned = (project?.isNoProject == true) || AntigravityCloudDetector.isNoProjectSlug(trimmedSlug)
        let isCloudProj = (project?.runtime == .cloud) || trimmedSlug.lowercased().hasPrefix("cloud:")
        let effectiveSlug: String = {
            if let project { return project.id }
            if isUnassigned {
                let hasLocalNoProj = projects.contains(where: { $0.isNoProject && $0.runtime != .cloud })
                if isCloudProj && hasLocalNoProj {
                    return "cloud:\(AntigravityCloudDetector.noProjectDisplayName)"
                }
                return AntigravityCloudDetector.noProjectDisplayName
            }
            return trimmedSlug
        }()
        let cloudProjId = isUnassigned ? nil : project?.cloudProjectId
        let originUuid = project?.originInstanceUuid
        let workspaceUri: String = {
            if isUnassigned { return "" }
            if let existingUri = project?.workspaceUri, !existingUri.isEmpty {
                return existingUri
            }
            if hasPairedBackend || isLiveBackendConnected {
                return ""
            }
            return isCloudProj ? "cloud://\(trimmedSlug)" : "file:///Users/wl/code/\(trimmedSlug)"
        }()
        let branch = isUnassigned ? "" : (project?.activeBranch ?? "main")

        let newSummary = CascadeSummary(
            cascadeId: optimisticId,
            title: title,
            projectSlug: effectiveSlug,
            workspaceUri: workspaceUri,
            branchName: branch,
            status: initialPrompt != nil ? .inProgress : .done,
            stepCount: initialPrompt != nil ? 1 : 0,
            currentStepIndex: 1,
            totalSteps: 1,
            updatedAt: Date(),
            relativeTimeLabel: "now",
            statusSubtitle: initialPrompt != nil ? "Running · Step 1 of 1" : "Ready for instructions",
            isPinned: displayOptions.autoPinOnMessage,
            isArchived: false,
            isUnread: false,
            modelLabel: selectedModelConfig.displayName,
            lastMessagePreview: initialPrompt ?? "Ready for instructions...",
            isCloud: isCloudProj,
            cloudProjectId: cloudProjId,
            originInstanceUuid: originUuid,
            originHostName: isCloudProj ? "Antigravity" : activeHost.hostname
        )
        summaries.insert(newSummary, at: 0)
        if hasPairedBackend || isLiveBackendConnected {
            let existingCloudProjects = projects.filter { $0.runtime == .cloud && $0.cloudProjectId != nil }
            var nextSummaries = summaries
            projects = Self.reconcileLiveProjects(
                workspaces: workspaces,
                summaries: &nextSummaries,
                existingProjects: projects,
                hostName: activeHost.hostname,
                cloudProjects: existingCloudProjects
            )
            summaries = nextSummaries
        }
        stepsByCascadeId[optimisticId] = []
        activeCascadeId = optimisticId
        selectedProjectId = summaries.first(where: { $0.cascadeId == optimisticId })?.projectSlug ?? effectiveSlug
        selectedWorkspaceUri = workspaceUri
        activeRoute = .cascadeChat(optimisticId)

        let clientRef = rpcClient
        let modelId = selectedModelConfig.modelId
        let shouldCallLiveBackend = (hasPairedBackend || isLiveBackendConnected)

        Task { [weak self] in
            if shouldCallLiveBackend,
               let clientRef,
               let realCascadeId = try? await clientRef.startCascade(
                   workspaceUri: workspaceUri,
                   initialPrompt: initialPrompt ?? "",
                   modelId: modelId,
                   cloudProjectId: cloudProjId,
                   isCloud: isCloudProj,
                   instanceUuidOverride: originUuid
               ),
               !realCascadeId.isEmpty {
                guard let self else { return }
                if self.hasPairedBackend && (!self.isLiveBackendConnected || !self.activeHost.isOnline) {
                    self.markBackendReconnected()
                }
                let existingSteps = self.stepsByCascadeId.removeValue(forKey: optimisticId) ?? []
                self.stepsByCascadeId[realCascadeId] = existingSteps.map { step in
                    var copy = step
                    copy.cascadeId = realCascadeId
                    return copy
                }
                if let idx = self.summaries.firstIndex(where: { $0.cascadeId == optimisticId }) {
                    self.summaries[idx].cascadeId = realCascadeId
                }
                if self.activeCascadeId == optimisticId {
                    self.activeCascadeId = realCascadeId
                    self.activeRoute = .cascadeChat(realCascadeId)
                }
                if let prompt = initialPrompt, !prompt.isEmpty {
                    self.composerDraftText = prompt
                    self.sendCurrentDraft()
                } else {
                    self.syncStepsForCascade(realCascadeId, pollUntilIdle: false)
                }
                return
            }

            if let prompt = initialPrompt, !prompt.isEmpty {
                self?.composerDraftText = prompt
                self?.sendCurrentDraft()
            }
        }
        return optimisticId
    }

    public func createNewCascade(
        title: String = "New Agentic Session",
        branchName: String? = nil,
        initialPrompt: String? = nil
    ) {
        let slug: String = {
            if let selected = selectedProject?.id, !selected.isEmpty {
                return selected
            }
            if hasPairedBackend || isLiveBackendConnected {
                return projects.first?.id ?? AntigravityCloudDetector.noProjectDisplayName
            }
            return "ledger-svc"
        }()
        let newId = createConversationInProject(slug, title: title, initialPrompt: nil)
        if let branchName, let idx = summaries.firstIndex(where: { $0.cascadeId == newId }) {
            summaries[idx].branchName = branchName
        }
        if let initialPrompt, !initialPrompt.isEmpty {
            composerDraftText = initialPrompt
            sendCurrentDraft()
        }
    }

    public func revealProjectInFinder(_ projectSlug: String) {
        guard let project = projects.first(where: { $0.id == projectSlug }),
              !project.workspaceUri.isEmpty else { return }
        let uri = project.workspaceUri
        let clientRef = rpcClient
        Task {
            try? await clientRef?.openWorkspaceInFinder(workspaceUri: uri)
        }
    }

    public func refreshWorkspacesAndSummaries() async {
        isRefreshingSummaries = true
        defer { isRefreshingSummaries = false }
        guard let client = rpcClient else { return }

        backgroundPollCounter += 1
        let isRelay = (activeHost.channel == .cloudRelay)
        let syncTimeout: TimeInterval = isRelay ? 14.0 : 3.5
        let useLightweight = isRelay && (backgroundPollCounter % 4 != 1) && summaryStreamTask != nil
        do {
            let federated = try await client.fetchFederatedWorkspacesAndSummaries(
                timeoutInterval: syncTimeout,
                lightweightPoll: useLightweight
            )
            consecutiveSyncFailures = 0
            cloudAgentWarmingUp = federated.cloudWarmingUp

            let remoteSummaries = federated.summaries
            if !federated.workspaces.isEmpty {
                workspaces = federated.workspaces
            }

            if hasPairedBackend && (!isLiveBackendConnected || !activeHost.isOnline) {
                markBackendReconnected()
            }

            let existingById = Dictionary(uniqueKeysWithValues: summaries.map { ($0.cascadeId, $0) })
            let remoteIds = Set(remoteSummaries.map(\.cascadeId))
            var shouldResyncActiveCascade = false
            let now = Date()

            var mergedList: [CascadeSummary] = remoteSummaries.map { remote in
                var copy = remote
                if let existing = existingById[remote.cascadeId] {
                    let hasNewActivity = remote.stepCount > existing.stepCount
                        || remote.updatedAt.timeIntervalSince(existing.updatedAt) > 0.5
                    if existing.title != "New Conversation" && copy.title == "New Conversation" {
                        copy.title = existing.title
                    }
                    if existing.isCloud && !copy.isCloud {
                        copy.isCloud = true
                        copy.originHostName = "Antigravity"
                    }
                    copy.isPinned = existing.isPinned || remote.isPinned
                    copy.isArchived = existing.isArchived || remote.isArchived
                    copy.stepCount = max(existing.stepCount, remote.stepCount)
                    copy.cloudProjectId = remote.cloudProjectId ?? existing.cloudProjectId
                    if copy.originInstanceUuid == nil {
                        copy.originInstanceUuid = existing.originInstanceUuid
                        copy.originHostName = copy.originHostName ?? existing.originHostName
                    }
                    if let optimisticExpiry = optimisticActiveUntilByCascadeId[remote.cascadeId],
                       optimisticExpiry > now,
                       copy.status != .waiting && copy.status != .blocked && copy.status != .error {
                        copy.status = .inProgress
                    }
                    if hasNewActivity {
                        if activeRoute != .cascadeChat(remote.cascadeId) {
                            copy.isUnread = true
                            locallyViewedAtByCascadeId.removeValue(forKey: remote.cascadeId)
                        } else {
                            copy.isUnread = false
                            locallyViewedAtByCascadeId[remote.cascadeId] = now
                        }
                    }
                    if remote.cascadeId == activeCascadeId && (
                        hasNewActivity
                            || remote.status != existing.status
                            || copy.status == .inProgress
                            || copy.status == .pending
                    ) {
                        shouldResyncActiveCascade = true
                    }
                } else if remote.cascadeId == activeCascadeId {
                    shouldResyncActiveCascade = true
                }
                if let viewedAt = locallyViewedAtByCascadeId[remote.cascadeId],
                   remote.updatedAt <= viewedAt {
                    copy.isUnread = false
                    copy.statusSubtitle = AntigravityRPCClient.buildLiveStatusSubtitle(
                        status: copy.status,
                        stepCount: copy.stepCount,
                        isUnread: false
                    )
                }
                return copy
            }

            // Preserve any in-flight optimistic iOS sessions (`cas-*`) not yet returned by `GetAllCascadeTrajectories`
            for local in summaries where !remoteIds.contains(local.cascadeId)
                && local.cascadeId.hasPrefix("cas-")
                && !Self.esddFixtureCascadeIds.contains(local.cascadeId)
                && (hasPairedBackend || isLiveBackendConnected) {
                mergedList.insert(local, at: 0)
            }

            mergedList.sort { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.cascadeId < rhs.cascadeId
            }

            if hasPairedBackend || isLiveBackendConnected {
                projects = Self.reconcileLiveProjects(
                    workspaces: workspaces,
                    summaries: &mergedList,
                    existingProjects: projects,
                    hostName: activeHost.hostname,
                    cloudProjects: federated.cloudProjects
                )
                summaries = mergedList
                if selectedProjectId.isEmpty || !projects.contains(where: { $0.id == selectedProjectId }) {
                    let defaultProj = projects.first(where: { !$0.isNoProject }) ?? projects.first
                    selectedProjectId = defaultProj?.id ?? ""
                }
                if shouldResyncActiveCascade && !activeCascadeId.isEmpty {
                    syncStepsForCascade(
                        activeCascadeId,
                        pollUntilIdle: activeRoute == .cascadeChat(activeCascadeId)
                    )
                }
                await projectionStore.saveProjects(projects)
            } else {
                var knownIds = Set(projects.map(\.id))
                for ws in workspaces where !knownIds.contains(ws.displayName) {
                    knownIds.insert(ws.displayName)
                    let isCloud = ws.isCloud || AntigravityCloudDetector.isCloudWorkspaceURI(ws.workspaceUri)
                    projects.insert(
                        ProjectWorkspace(
                            id: ws.displayName,
                            name: ws.displayName,
                            pathDisplay: ws.workspaceUri.replacingOccurrences(of: "file://", with: ""),
                            workspaceUri: ws.workspaceUri,
                            runtime: isCloud ? .cloud : .macBookPro,
                            hostName: isCloud ? "Cloud" : activeHost.hostname,
                            activeBranch: ws.activeBranch,
                            worktrees: ws.worktrees.isEmpty ? [ws.activeBranch] : ws.worktrees,
                            isExpandedInHome: true
                        ),
                        at: 0
                    )
                }
                for remote in mergedList {
                    if let idx = summaries.firstIndex(where: { $0.cascadeId == remote.cascadeId }) {
                        summaries[idx] = remote
                    } else {
                        summaries.append(remote)
                    }
                }
            }
            await projectionStore.saveProjectedSummaries(summaries)
        } catch {
            if Self.isBackendOfflineError(error) {
                consecutiveSyncFailures += 1
                let failureThreshold = isRelay ? 3 : 1
                if consecutiveSyncFailures >= failureThreshold {
                    markBackendOffline(error: error)
                }
            }
            return
        }

        if isLiveBackendConnected, let remoteAutos = try? await client.listAutomations() {
            automations = remoteAutos
            await projectionStore.saveAutomations(remoteAutos)
        }
    }

    // MARK: - Automations Actions (`UE06`)

    @discardableResult
    public func createAutomationFromPrompt(_ prompt: String = "") -> AutomationItem? {
        let raw = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? automationPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            : prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let slug = selectedProject?.id ?? "ledger-svc"
        let item = AutomationItem(
            id: "auto-\(UUID().uuidString.prefix(8).lowercased())",
            title: raw,
            projectSlug: slug,
            scheduleSummary: "\(slug) · Weekdays at 09:00 · Flash",
            section: .scheduled,
            nextRunText: "Tomorrow, 09:00",
            lastRunText: "Created just now",
            needsReview: false,
            isRunningNow: false
        )
        automations.insert(item, at: 0)
        automationPromptDraft = ""

        let snapshot = automations
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.saveAutomations(snapshot)
            _ = try? await clientRef?.createAutomation(prompt: raw, projectSlug: slug)
        }
        return item
    }

    public func triggerAutomationNow(_ automationId: String) {
        guard let idx = automations.firstIndex(where: { $0.id == automationId }) else { return }
        automations[idx].isRunningNow = true
        automations[idx].needsReview = false
        automations[idx].lastRunText = "Running now..."

        let snapshot = automations
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.enqueueOutbox(
                OutboxEntry(cascadeId: automationId, kind: .automationTrigger, messageText: "TriggerAutomationNow")
            )
            await storeRef.saveAutomations(snapshot)
            try? await clientRef?.triggerAutomationNow(automationId: automationId)
        }
    }

    public func resumeAutomation(_ automationId: String) {
        guard let idx = automations.firstIndex(where: { $0.id == automationId }) else { return }
        automations[idx].section = .scheduled
        automations[idx].nextRunText = "Tomorrow, 08:00"
        automations[idx].lastRunText = "Resumed · just now"

        let snapshot = automations
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.saveAutomations(snapshot)
            try? await clientRef?.setAutomationPaused(automationId: automationId, isPaused: false)
        }
    }

    // MARK: - Add Context & Composer Actions (`UE07`, `UE08`, `UE09`)

    public func toggleContextCandidate(_ candidateId: String) {
        guard let idx = contextCandidates.firstIndex(where: { $0.id == candidateId }) else { return }
        contextCandidates[idx].isSelected.toggle()
    }

    public func applySelectedContextToComposer() {
        for candidate in contextCandidates where candidate.isSelected {
            if candidate.isActionTrigger {
                if !composerDraftText.hasPrefix(candidate.chipLabel) {
                    composerDraftText = "\(candidate.chipLabel) \(composerDraftText)".trimmingCharacters(in: .whitespaces)
                }
            } else if !composerAttachments.contains(where: { $0.label == candidate.chipLabel }) {
                composerAttachments.append(
                    ComposerAttachmentChip(
                        id: "chip-\(candidate.id)",
                        kind: candidate.attachmentKind,
                        label: candidate.chipLabel,
                        targetUri: "antigravity://context/\(candidate.id)"
                    )
                )
            }
        }
        presentedSheet = nil
    }

    public func applySlashCommand(_ item: SlashCommandItem) {
        composerDraftText = "\(item.command) "
        isSlashPopupDismissedManually = true
    }

    public func attachFileMention(_ filePath: String) {
        let fileName = (filePath as NSString).lastPathComponent
        let basePrefix: String = {
            if !isVerificationMode && selectedWorkspaceUri.hasPrefix("file://") {
                return selectedWorkspaceUri.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
            return "file:///Users/wl/code/ledger-svc"
        }()
        let chip = ComposerAttachmentChip(
            kind: .fileMention,
            label: "@\(fileName)",
            targetUri: "\(basePrefix)/\(filePath)"
        )
        if !composerAttachments.contains(where: { $0.targetUri == chip.targetUri || $0.label == chip.label }) {
            composerAttachments.append(chip)
        }
        if let lastRange = composerDraftText.range(of: "@[^\\s]*$", options: .regularExpression) {
            composerDraftText.removeSubrange(lastRange)
        }
    }

    public func removeAttachment(_ chipId: String) {
        composerAttachments.removeAll { $0.id == chipId }
    }

    public func sendCurrentDraft() {
        let trimmed = composerDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !composerAttachments.isEmpty else { return }

        let messageBody = trimmed.isEmpty
            ? "Inspect attached context: \(composerAttachments.map(\.label).joined(separator: ", "))"
            : trimmed
        let mentionLabels = composerAttachments.map(\.label)

        var currentSteps = stepsByCascadeId[activeCascadeId] ?? []
        let nextIndex = (currentSteps.map(\.stepIndex).max() ?? 0) + 1
        stepLoadErrorText = nil

        let userStep = CascadeStep(
            cascadeId: activeCascadeId,
            stepIndex: nextIndex,
            type: .userInput,
            status: .done,
            createdAt: Date(),
            userInput: messageBody,
            attachedMentions: mentionLabels,
            isQueuedInOutbox: false,
            recordedExecutionMode: selectedModelConfig.mode,
            recordedModelId: selectedModelConfig.modelId
        )
        currentSteps.append(userStep)
        if !activeCascadeId.isEmpty {
            syncedConfigCascadeIds.insert(activeCascadeId)
        }

        // Only synthesize ESDD offline mock response when NO backend is paired (`!hasPairedBackend && !isLiveBackendConnected`)
        if !hasPairedBackend && !isLiveBackendConnected {
            let assistantStep = CascadeStep(
                cascadeId: activeCascadeId,
                stepIndex: nextIndex + 1,
                type: .plannerResponse,
                status: .inProgress,
                createdAt: Date(),
                plannerResponse: PlannerResponsePayload(
                    response: "Running in `\(selectedModelConfig.mode.rawValue)` mode with `\(selectedModelConfig.displayName)` (`\(selectedModelConfig.agentPersona)` agent)...",
                    thinking: "Evaluating prompt with \(mentionLabels.count) context chips on branch \(activeSummary?.branchName ?? "main").",
                    thinkingDurationSeconds: 2.0,
                    referencedFiles: composerAttachments.map(\.targetUri)
                )
            )
            currentSteps.append(assistantStep)
        }
        stepsByCascadeId[activeCascadeId] = currentSteps

        let currentSummary = summaries.first(where: { $0.cascadeId == activeCascadeId })
        let currentProj = projects.first(where: { $0.id == (currentSummary?.projectSlug ?? selectedProjectId) })
        let summaryIsCloud = currentSummary?.isCloud ?? (currentProj?.runtime == .cloud)
        let summaryCloudProjId = currentSummary?.cloudProjectId ?? currentProj?.cloudProjectId
        let summaryOriginUuid = currentSummary?.originInstanceUuid ?? currentProj?.originInstanceUuid

        if let sumIdx = summaries.firstIndex(where: { $0.cascadeId == activeCascadeId }) {
            summaries[sumIdx].stepCount = currentSteps.count
            summaries[sumIdx].status = .inProgress
            summaries[sumIdx].lastMessagePreview = messageBody
            summaries[sumIdx].relativeTimeLabel = "now"
            summaries[sumIdx].updatedAt = Date()
            if summaries[sumIdx].title == "New Conversation" {
                summaries[sumIdx].title = String(messageBody.prefix(48))
            }
            if displayOptions.autoPinOnMessage {
                summaries[sumIdx].isPinned = true
            }
        }

        let attachmentsSnapshot = composerAttachments
        composerDraftText = ""
        composerAttachments.removeAll()
        isSlashPopupDismissedManually = false
        isAutoScrollPinnedToBottom = true

        let cid = activeCascadeId
        let cfg = selectedModelConfig
        let storeRef = projectionStore
        let clientRef = rpcClient
        let shouldSendLive = (hasPairedBackend || isLiveBackendConnected)
        let isUnassignedSession = (currentProj?.isNoProject == true)
            || (currentSummary.map {
                AntigravityCloudDetector.isNoProjectSlug($0.projectSlug) && ($0.cloudProjectId ?? "").isEmpty
            } ?? false)
        let workspaceUri: String = {
            if isUnassignedSession {
                if let scratch = currentSummary?.workspaceUri, AntigravityCloudDetector.isPlaygroundScratchURI(scratch) {
                    return scratch
                }
                return ""
            }
            if let sumUri = currentSummary?.workspaceUri, !sumUri.isEmpty {
                return sumUri
            }
            if let projUri = currentProj?.workspaceUri, !projUri.isEmpty {
                return projUri
            }
            if !selectedWorkspaceUri.isEmpty {
                return selectedWorkspaceUri
            }
            return isVerificationMode ? "file:///Users/wl/code/ledger-svc" : ""
        }()

        Task { [weak self] in
            await storeRef.enqueueOutbox(
                OutboxEntry(cascadeId: cid, kind: .userMessage, messageText: messageBody)
            )
            await storeRef.saveProjectedSteps(currentSteps, for: cid)

            guard shouldSendLive, let clientRef else {
                _ = await storeRef.drainOutbox()
                return
            }

            var targetCascadeId = cid
            if targetCascadeId.hasPrefix("cas-") {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if let upgraded = self?.activeCascadeId, !upgraded.isEmpty, !upgraded.hasPrefix("cas-") {
                    targetCascadeId = upgraded
                }
            }

            do {
                if targetCascadeId.isEmpty || targetCascadeId.hasPrefix("cas-") {
                    let createdId = try await clientRef.startCascade(
                        workspaceUri: workspaceUri,
                        initialPrompt: "",
                        modelId: cfg.modelId,
                        cloudProjectId: summaryCloudProjId,
                        isCloud: summaryIsCloud,
                        instanceUuidOverride: summaryOriginUuid
                    )
                    if let self, !createdId.isEmpty {
                        let existing = self.stepsByCascadeId.removeValue(forKey: targetCascadeId) ?? currentSteps
                        self.stepsByCascadeId[createdId] = existing.map { step in
                            var copy = step
                            copy.cascadeId = createdId
                            return copy
                        }
                        self.syncedConfigCascadeIds.insert(createdId)
                        if let idx = self.summaries.firstIndex(where: { $0.cascadeId == targetCascadeId }) {
                            self.summaries[idx].cascadeId = createdId
                        }
                        if self.activeCascadeId == targetCascadeId || self.activeCascadeId.isEmpty {
                            self.activeCascadeId = createdId
                            self.activeRoute = .cascadeChat(createdId)
                        }
                        targetCascadeId = createdId
                    }
                }

                if let self, !targetCascadeId.isEmpty {
                    self.optimisticActiveUntilByCascadeId[targetCascadeId] = Date().addingTimeInterval(45)
                    self.syncStepsForCascade(targetCascadeId, pollUntilIdle: true)
                }

                try await clientRef.sendUserCascadeMessage(
                    cascadeId: targetCascadeId,
                    message: messageBody,
                    attachments: attachmentsSnapshot,
                    modelId: cfg.modelId,
                    effort: cfg.effort,
                    mode: cfg.mode,
                    agentPersona: cfg.agentPersona,
                    isModelAlias: cfg.isModelAlias,
                    isCloud: summaryIsCloud,
                    instanceUuidOverride: summaryOriginUuid
                )
                _ = await storeRef.drainOutbox()

                if let self {
                    if self.hasPairedBackend && (!self.isLiveBackendConnected || !self.activeHost.isOnline) {
                        self.markBackendReconnected()
                    }
                    if !targetCascadeId.isEmpty {
                        self.syncStepsForCascade(targetCascadeId, pollUntilIdle: true)
                    }
                }
            } catch {
                if let self {
                    let stepsAdvanced = (self.stepsByCascadeId[targetCascadeId]?.count ?? 0) > currentSteps.count
                    if stepsAdvanced && !targetCascadeId.isEmpty {
                        // Turn already started streaming on backend despite unary HTTP timeout; keep polling steps
                        self.syncStepsForCascade(targetCascadeId, pollUntilIdle: true)
                    } else {
                        self.optimisticActiveUntilByCascadeId.removeValue(forKey: targetCascadeId)
                        self.stepLoadErrorText = "Failed to send message: \(error.localizedDescription)"
                        if let sumIdx = self.summaries.firstIndex(where: { $0.cascadeId == targetCascadeId }) {
                            self.summaries[sumIdx].status = .done
                            self.summaries[sumIdx].statusSubtitle = "Send failed · Tap to retry"
                        }
                    }
                }
            }
        }
    }

    public func stopActiveCascadeStreaming() {
        optimisticActiveUntilByCascadeId.removeValue(forKey: activeCascadeId)
        guard var currentSteps = stepsByCascadeId[activeCascadeId] else { return }
        for i in currentSteps.indices where currentSteps[i].status == .inProgress || currentSteps[i].status == .pending || currentSteps[i].status == .waiting {
            currentSteps[i].status = .cancelled
        }
        stepsByCascadeId[activeCascadeId] = currentSteps
        let originUuid = summaries.first(where: { $0.cascadeId == activeCascadeId })?.originInstanceUuid
        if let sumIdx = summaries.firstIndex(where: { $0.cascadeId == activeCascadeId }) {
            summaries[sumIdx].status = .cancelled
            summaries[sumIdx].statusSubtitle = "Stopped"
        }
        let cid = activeCascadeId
        let clientRef = rpcClient
        Task {
            try? await clientRef?.cancelCascadeInvocation(cascadeId: cid, instanceUuidOverride: originUuid)
        }
    }

    // MARK: - Step Expansion & Face ID Command Approval Actions (`UE07`, `UE13`)

    public func toggleThinkingExpanded(stepId: String) {
        if expandedThinkingStepIds.contains(stepId) {
            expandedThinkingStepIds.remove(stepId)
        } else {
            expandedThinkingStepIds.insert(stepId)
        }
    }

    public func toggleEvidenceGroupExpanded(groupId: String) {
        if expandedEvidenceGroupIds.contains(groupId) {
            expandedEvidenceGroupIds.remove(groupId)
        } else {
            expandedEvidenceGroupIds.insert(groupId)
        }
    }

    public func toggleTerminalOutputExpanded(stepId: String) {
        if expandedTerminalStepIds.contains(stepId) {
            expandedTerminalStepIds.remove(stepId)
        } else {
            expandedTerminalStepIds.insert(stepId)
        }
    }

    public func approveWaitingCommandWithFaceID(stepIndex: Int? = nil) {
        let targetIdx = stepIndex ?? pendingWaitingStep?.stepIndex
        guard let resolvedStepIndex = targetIdx else { return }
        resolveWaitingStep(stepIndex: resolvedStepIndex, decision: .allowWithFaceID)
    }

    public func denyWaitingCommand(stepIndex: Int? = nil) {
        let targetIdx = stepIndex ?? pendingWaitingStep?.stepIndex
        guard let resolvedStepIndex = targetIdx else { return }
        resolveWaitingStep(stepIndex: resolvedStepIndex, decision: .reject)
    }

    public func resolveWaitingStep(
        stepIndex: Int,
        decision: InteractionDecision
    ) {
        guard var steps = stepsByCascadeId[activeCascadeId],
              let idx = steps.firstIndex(where: { $0.stepIndex == stepIndex }) else {
            return
        }
        let targetStep = steps[idx]
        let payload = InteractionBuilder.buildPayload(
            step: targetStep,
            decision: decision,
            workspaceUri: selectedWorkspaceUri
        )
        lastDispatchedInteraction = payload

        switch decision {
        case .reject:
            steps[idx].status = .cancelled
            if let sumIdx = summaries.firstIndex(where: { $0.cascadeId == activeCascadeId }) {
                summaries[sumIdx].status = .cancelled
                summaries[sumIdx].statusSubtitle = "Denied · Awaiting instructions"
                summaries[sumIdx].pendingInteractionTitle = nil
            }
        case .allowOnce, .allowWithFaceID, .alwaysAllowInTurn, .allowWithModifiedCommand, .answerQuestion:
            if case .alwaysAllowInTurn = decision,
               let pattern = targetStep.requestedInteraction?.permission?.suggestedPersistPattern {
                activeTurnGrants.insert(pattern)
            }
            steps[idx].status = .done

            // Advance 7-segment task checklist if present
            if let tbIdx = steps.lastIndex(where: { $0.type == .taskBoundary }),
               var boundary = steps[tbIdx].taskBoundary {
                boundary.completedCount = min(boundary.totalCount, boundary.completedCount + 1)
                boundary.taskName = "Task · \(boundary.completedCount) of \(boundary.totalCount) done"
                for cIdx in boundary.checklist.indices where boundary.checklist[cIdx].status == .waiting {
                    boundary.checklist[cIdx].status = .done
                    boundary.checklist[cIdx].trailingBadge = "p99 4.2ms"
                }
                steps[tbIdx].taskBoundary = boundary
            }

            if !hasPairedBackend && !isLiveBackendConnected {
                let nextStepIndex = (steps.map(\.stepIndex).max() ?? stepIndex) + 1
                let followUp = CascadeStep(
                    cascadeId: activeCascadeId,
                    stepIndex: nextStepIndex,
                    type: .plannerResponse,
                    status: .done,
                    plannerResponse: PlannerResponsePayload(
                        response: "Face ID verified — executed `\(targetStep.runCommand?.commandLine ?? "approved action")`. Load test sustained 2,000 req/s with 0 drops.",
                        thinking: "Received signed HandleCascadeUserInteraction approval on step \(stepIndex).",
                        thinkingDurationSeconds: 1.4
                    )
                )
                steps.append(followUp)

                if let sumIdx = summaries.firstIndex(where: { $0.cascadeId == activeCascadeId }) {
                    summaries[sumIdx].status = .done
                    summaries[sumIdx].stepCount = steps.count
                    summaries[sumIdx].currentStepIndex = min(summaries[sumIdx].totalSteps, summaries[sumIdx].currentStepIndex + 1)
                    summaries[sumIdx].statusSubtitle = "Done · Load test passed"
                    summaries[sumIdx].pendingInteractionTitle = nil
                    summaries[sumIdx].updatedAt = Date()
                }
            } else if let sumIdx = summaries.firstIndex(where: { $0.cascadeId == activeCascadeId }) {
                summaries[sumIdx].status = .inProgress
                summaries[sumIdx].statusSubtitle = "Running · Approved action"
                summaries[sumIdx].pendingInteractionTitle = nil
                summaries[sumIdx].updatedAt = Date()
            }
        }

        stepsByCascadeId[activeCascadeId] = steps
        presentedSheet = nil

        if let payload, let clientRef = rpcClient {
            let storeRef = projectionStore
            let cid = activeCascadeId
            let originUuid = summaries.first(where: { $0.cascadeId == cid })?.originInstanceUuid
            let shouldSyncLive = (hasPairedBackend || isLiveBackendConnected)
            Task { [weak self] in
                await storeRef.enqueueOutbox(
                    OutboxEntry(cascadeId: cid, kind: .interactionApproval, messageText: "\(payload.stepIndex)")
                )
                try? await clientRef.handleCascadeUserInteraction(payload, instanceUuidOverride: originUuid)
                _ = await storeRef.drainOutbox()
                if shouldSyncLive && !cid.isEmpty {
                    self?.syncStepsForCascade(cid, pollUntilIdle: true)
                }
            }
        }
    }

    // MARK: - Structured Multi-Step Question Actions (`UE10`)

    public func toggleQuestionOption(_ option: String, stepIndex: Int? = nil) {
        let idx = stepIndex ?? activeQuestionStepIndex
        guard questionSteps.indices.contains(idx) else { return }
        if questionSteps[idx].selectedOptions.contains(option) {
            questionSteps[idx].selectedOptions.remove(option)
        } else {
            if !questionSteps[idx].isMultiSelect {
                questionSteps[idx].selectedOptions.removeAll()
            }
            questionSteps[idx].selectedOptions.insert(option)
        }
    }

    public func advanceQuestionStep() {
        guard questionSteps.indices.contains(activeQuestionStepIndex) else { return }
        questionSteps[activeQuestionStepIndex].isCompleted = true
        if activeQuestionStepIndex + 1 < questionSteps.count {
            activeQuestionStepIndex += 1
        } else if let waiting = pendingWaitingStep {
            let combinedOptions = questionSteps.flatMap { Array($0.selectedOptions).sorted() }
            let custom = questionSteps
                .map(\.customWriteIn)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "; ")
            resolveWaitingStep(
                stepIndex: waiting.stepIndex,
                decision: .answerQuestion(
                    selectedOptions: combinedOptions,
                    customWriteIn: custom.isEmpty ? nil : custom
                )
            )
        }
    }

    public func previousQuestionStep() {
        guard activeQuestionStepIndex > 0 else { return }
        activeQuestionStepIndex -= 1
    }

    public func submitFreeformQuestionReply(_ text: String? = nil) {
        let body = (text ?? questionFreeformReplyDraft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        questionFreeformReplyDraft = ""
        if let waiting = pendingWaitingStep {
            resolveWaitingStep(
                stepIndex: waiting.stepIndex,
                decision: .answerQuestion(selectedOptions: [], customWriteIn: body)
            )
        } else {
            composerDraftText = body
            sendCurrentDraft()
        }
    }

    // MARK: - Implementation Plan Review Actions (`UE11`)

    @discardableResult
    public func addPlanComment(
        targetFilePath: String = "settlement/settlement_test.go",
        quotedSpan: String = "remove the package-level clk variable",
        body: String
    ) -> PlanInlineComment? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let comment = PlanInlineComment(
            authorInitials: "WL",
            authorName: "You",
            statusLabel: "Pending",
            targetFilePath: targetFilePath,
            quotedSpan: quotedSpan,
            body: trimmed
        )
        planComments.append(comment)
        return comment
    }

    public func sendPlanCommentsToAgent() {
        guard !planComments.isEmpty else { return }
        for idx in planComments.indices {
            planComments[idx].statusLabel = "Sent"
        }
        let commentsSnapshot = planComments
        let cid = activeCascadeId
        if let idx = summaries.firstIndex(where: { $0.cascadeId == "cas-flaky-settlement" }) {
            summaries[idx].status = .inProgress
            summaries[idx].statusSubtitle = "Running · Addressing \(commentsSnapshot.count) plan comments"
            summaries[idx].isUnread = false
        }
        activeRoute = .cascadeChat(cid)

        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.enqueueOutbox(
                OutboxEntry(
                    cascadeId: cid,
                    kind: .planComments,
                    messageText: "Sent \(commentsSnapshot.count) plan review comments"
                )
            )
            try? await clientRef?.sendPlanReviewComments(cascadeId: cid, comments: commentsSnapshot)
            _ = await storeRef.drainOutbox()
        }
    }

    public func approveArtifactPlan(artifactPath: String = "/brain/implementation_plan.md") {
        if let idx = activeArtifacts.firstIndex(where: { $0.artifactPath == artifactPath }) {
            activeArtifacts[idx].requestFeedback = false
            activeArtifacts[idx].summary = "Approved · \(planComments.count) comments addressed"
        }
        if let waiting = pendingWaitingStep {
            resolveWaitingStep(stepIndex: waiting.stepIndex, decision: .allowOnce)
        }
        activeRoute = .cascadeChat(activeCascadeId)
    }

    // MARK: - Turn Diff Line-Level Review Actions (`UE12`)

    public func selectNextDiffFile() {
        guard !activeTurnDiffs.isEmpty else { return }
        selectedDiffFileIndex = (selectedDiffFileIndex + 1) % activeTurnDiffs.count
    }

    public func selectPreviousDiffFile() {
        guard !activeTurnDiffs.isEmpty else { return }
        selectedDiffFileIndex = (selectedDiffFileIndex - 1 + activeTurnDiffs.count) % activeTurnDiffs.count
    }

    public func addDiffComment(filePath: String, lineNumber: Int, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        diffComments.append(
            DiffLineComment(filePath: filePath, lineNumber: lineNumber, body: trimmed, sentToAgent: false)
        )
    }

    public func submitDiffLineComment(sendImmediately: Bool) {
        let trimmed = activeLineCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let path = currentDiffFile?.filePath ?? "middleware/ratelimit.go"
        let line = selectedDiffLineNumber ?? 29
        let comment = DiffLineComment(
            filePath: path,
            lineNumber: line,
            body: trimmed,
            sentToAgent: sendImmediately
        )
        diffComments.append(comment)
        activeLineCommentDraft = ""

        if sendImmediately {
            let cid = activeCascadeId
            let clientRef = rpcClient
            let storeRef = projectionStore
            Task {
                await storeRef.enqueueOutbox(
                    OutboxEntry(cascadeId: cid, kind: .diffComments, messageText: comment.body)
                )
                try? await clientRef?.sendDiffReviewComments(cascadeId: cid, comments: [comment])
                _ = await storeRef.drainOutbox()
            }
        }
    }

    public func toggleDiffFileViewed() {
        guard activeTurnDiffs.indices.contains(selectedDiffFileIndex) else { return }
        activeTurnDiffs[selectedDiffFileIndex].isReviewed.toggle()
    }

    public func acceptCurrentDiffFile() {
        guard activeTurnDiffs.indices.contains(selectedDiffFileIndex) else { return }
        activeTurnDiffs.remove(at: selectedDiffFileIndex)
        if activeTurnDiffs.isEmpty {
            selectedDiffFileIndex = 0
            activeRoute = .cascadeChat(activeCascadeId)
        } else {
            selectedDiffFileIndex = min(selectedDiffFileIndex, activeTurnDiffs.count - 1)
        }
    }

    public func acceptPatchFile(_ filePath: String) {
        if let idx = activeTurnDiffs.firstIndex(where: { $0.filePath == filePath }) {
            selectedDiffFileIndex = idx
            acceptCurrentDiffFile()
        }
    }

    public func revertCurrentDiffHunk() {
        guard let current = currentDiffFile else { return }
        let cid = activeCascadeId
        let clientRef = rpcClient
        Task {
            try? await clientRef?.revertDiffHunk(
                cascadeId: cid,
                filePath: current.filePath,
                hunkHeader: current.hunkHeader
            )
        }
    }

    public func revertCurrentDiffFile() {
        guard activeTurnDiffs.indices.contains(selectedDiffFileIndex) else { return }
        let removed = activeTurnDiffs.remove(at: selectedDiffFileIndex)
        if let sumIdx = summaries.firstIndex(where: { $0.cascadeId == activeCascadeId }) {
            summaries[sumIdx].totalAdditions = max(0, summaries[sumIdx].totalAdditions - removed.additions)
            summaries[sumIdx].totalDeletions = max(0, summaries[sumIdx].totalDeletions - removed.deletions)
        }
        if activeTurnDiffs.isEmpty {
            selectedDiffFileIndex = 0
            activeRoute = .cascadeChat(activeCascadeId)
        } else {
            selectedDiffFileIndex = min(selectedDiffFileIndex, activeTurnDiffs.count - 1)
        }
        let cid = activeCascadeId
        let clientRef = rpcClient
        Task {
            try? await clientRef?.revertDiffHunk(cascadeId: cid, filePath: removed.filePath, hunkHeader: nil)
        }
    }

    public func acceptAllTurnDiffs() {
        activeTurnDiffs.removeAll()
        selectedDiffFileIndex = 0
        activeRoute = .cascadeChat(activeCascadeId)
    }

    // MARK: - Deterministic Scene Routing Helper (`UE01` .. `UE13`)

    public func configureForVerifyScene(_ scene: ESDDVerifySceneCase) {
        isVerificationMode = true
        isInitialSessionCheckComplete = true
        presentedSheet = nil
        switch scene {
        case .agentsHome:
            selectedTab = .agents
            activeRoute = .tabRoot
        case .displayOptions:
            selectedTab = .agents
            activeRoute = .tabRoot
            presentedSheet = .displayOptions
            isSortPopoverPresented = true
        case .contextMenuPin:
            selectedTab = .agents
            activeRoute = .tabRoot
            contextMenuTargetCascadeId = "cas-flaky-settlement"
            swipePreviewCascadeId = "cas-upgrade-go"
            presentedSheet = .contextMenuPreview(cascadeId: "cas-flaky-settlement")
        case .projectDetail:
            selectedTab = .agents
            selectedProjectId = "ledger-svc"
            selectedProjectTab = .active
            // Align ledger-svc to Active 3 / Archived 2 (5 conversations) as depicted in UE04
            if let idx = summaries.firstIndex(where: { $0.cascadeId == "cas-idempotency-payouts" }) {
                summaries[idx].isArchived = true
            }
            summaries.removeAll { $0.cascadeId == "cas-pgx-v5-migration" }
            activeRoute = .projectDetail("ledger-svc")
        case .createProject:
            selectedTab = .agents
            activeRoute = .tabRoot
            presentedSheet = .createProject
        case .automations:
            selectedTab = .automations
            activeRoute = .tabRoot
        case .chatAndComposer:
            selectedTab = .agents
            activeCascadeId = "cas-rate-limiter"
            activeRoute = .cascadeChat("cas-rate-limiter")
        case .addContext:
            selectedTab = .agents
            activeCascadeId = "cas-rate-limiter"
            activeRoute = .cascadeChat("cas-rate-limiter")
            presentedSheet = .addContext
        case .modelAndMode:
            selectedTab = .agents
            activeCascadeId = "cas-rate-limiter"
            activeRoute = .cascadeChat("cas-rate-limiter")
            presentedSheet = .modelAndMode
        case .structuredQuestion:
            selectedTab = .agents
            activeCascadeId = "cas-audit-log-admin"
            activeQuestionStepIndex = 1
            activeRoute = .cascadeChat("cas-audit-log-admin")
        case .planReview:
            selectedTab = .agents
            activeCascadeId = "cas-flaky-settlement"
            selectedArtifactPath = "/brain/implementation_plan.md"
            activeRoute = .planReview
        case .turnDiffReview:
            selectedTab = .agents
            activeCascadeId = "cas-rate-limiter"
            selectedDiffTurn = 3
            selectedDiffFileIndex = 0
            selectedDiffLineNumber = 29
            activeRoute = .turnDiffReview
        case .liveActivitySpec:
            selectedTab = .agents
            activeCascadeId = "cas-rate-limiter"
            activeRoute = .cascadeChat("cas-rate-limiter")
        }
    }

    // MARK: - Deterministic 1:1 UE Fixture Factory (`UE01` .. `UE13`)

    public static func makeESDDVerificationStore() -> AntigravitySessionStore {
        let macHost = RemoteHostInstance(
            instanceId: "macbook-pro-local",
            hostname: "MacBook Pro",
            version: "v2.32.0",
            channel: .directHost,
            endpointURL: URL(string: "https://127.0.0.1:42100")!,
            isOnline: true,
            latencyMs: 6
        )
        let cloudHost = RemoteHostInstance(
            instanceId: "cloud-vm-us-central1",
            hostname: "Cloud",
            version: "v2.32.0",
            channel: .cloudRelay,
            endpointURL: URL(string: "https://antigravity.google.com/r/cloud-vm-us-central1")!,
            isOnline: true,
            latencyMs: 24
        )

        let projects: [ProjectWorkspace] = [
            ProjectWorkspace(
                id: "ledger-svc",
                name: "ledger-svc",
                pathDisplay: "~/code/ledger-svc",
                workspaceUri: "file:///Users/wl/code/ledger-svc",
                runtime: .macBookPro,
                hostName: "MacBook Pro",
                activeBranch: "main",
                worktrees: ["main", "feat/ratelimit", "fix/settlement-clock"],
                isExpandedInHome: true,
                rulesAndSkillsCount: 4
            ),
            ProjectWorkspace(
                id: "web-console",
                name: "web-console",
                pathDisplay: "cloud://acme/web-console",
                workspaceUri: "cloud://acme/web-console",
                runtime: .cloud,
                hostName: "Cloud",
                activeBranch: "main",
                worktrees: ["main", "feat/dark-mode"],
                isExpandedInHome: true,
                rulesAndSkillsCount: 3
            )
        ]

        let workspaces: [WorkspaceInfo] = [
            WorkspaceInfo(
                workspaceUri: "file:///Users/wl/code/ledger-svc",
                displayName: "ledger-svc",
                activeBranch: "main",
                worktrees: ["main", "feat/ratelimit", "fix/settlement-clock"],
                activeCascadeCount: 3,
                indexedFiles: [
                    "internal/middleware/ratelimit.go",
                    "internal/router/transfers.go",
                    "internal/settlement/batch.go",
                    "internal/settlement/settlement_test.go",
                    "load/transfers.txt"
                ]
            ),
            WorkspaceInfo(
                workspaceUri: "cloud://acme/web-console",
                displayName: "web-console",
                activeBranch: "main",
                worktrees: ["main", "feat/dark-mode"],
                activeCascadeCount: 2,
                indexedFiles: [
                    "src/pages/settings/DarkModeToggle.tsx",
                    "src/theme/tokens.ts"
                ]
            )
        ]

        let baseNow = Date(timeIntervalSince1970: 1_762_793_357)
        let summaries: [CascadeSummary] = [
            CascadeSummary(
                cascadeId: "cas-rate-limiter",
                title: "Add rate limiter to /transfers",
                projectSlug: "ledger-svc",
                workspaceUri: "file:///Users/wl/code/ledger-svc",
                branchName: "main",
                status: .inProgress,
                stepCount: 28,
                currentStepIndex: 4,
                totalSteps: 7,
                updatedAt: baseNow,
                relativeTimeLabel: "now",
                statusSubtitle: "Running · Step 4 of 7 · go test ./internal/...",
                isPinned: true,
                isArchived: false,
                isUnread: false,
                modelLabel: "Gemini 3.1 Pro",
                pendingInteractionTitle: "Approve: vegeta attack...",
                lastMessagePreview: "Plan approved with your 2 comments. Tests pass — next is a load test, which needs your OK.",
                totalAdditions: 128,
                totalDeletions: 14
            ),
            CascadeSummary(
                cascadeId: "cas-flaky-settlement",
                title: "Fix flaky TestSettlementBatch",
                projectSlug: "ledger-svc",
                workspaceUri: "file:///Users/wl/code/ledger-svc",
                branchName: "main",
                status: .waiting,
                stepCount: 12,
                currentStepIndex: 2,
                totalSteps: 5,
                updatedAt: baseNow.addingTimeInterval(-480),
                relativeTimeLabel: "8m",
                statusSubtitle: "Needs review · Implementation plan ready",
                isPinned: false,
                isArchived: false,
                isUnread: true,
                modelLabel: "Gemini 3.1 Pro",
                pendingInteractionTitle: "Awaiting review · Implementation Plan",
                lastMessagePreview: "The flake comes from a shared fake clock across parallel subtests in settlement_test.go. I wrote a plan to isolate it per test — review it before I change anything?",
                totalAdditions: 0,
                totalDeletions: 0
            ),
            CascadeSummary(
                cascadeId: "cas-release-checklist",
                title: "Release checklist v2.3",
                projectSlug: "web-console",
                workspaceUri: "cloud://acme/web-console",
                branchName: "main",
                status: .done,
                stepCount: 19,
                currentStepIndex: 5,
                totalSteps: 5,
                updatedAt: baseNow.addingTimeInterval(-3500),
                relativeTimeLabel: "1h",
                statusSubtitle: "Done · Walkthrough ready",
                isPinned: true,
                isArchived: false,
                isUnread: false,
                modelLabel: "Gemini 3.8 Flash",
                lastMessagePreview: "All v2.3 release checks succeeded and walkthrough artifact is ready.",
                totalAdditions: 34,
                totalDeletions: 8
            ),
            CascadeSummary(
                cascadeId: "cas-upgrade-go",
                title: "Upgrade to Go 1.25",
                projectSlug: "ledger-svc",
                workspaceUri: "file:///Users/wl/code/ledger-svc",
                branchName: "main",
                status: .done,
                stepCount: 31,
                currentStepIndex: 6,
                totalSteps: 6,
                updatedAt: baseNow.addingTimeInterval(-3600),
                relativeTimeLabel: "1h",
                statusSubtitle: "Done · 6 files changed",
                isPinned: false,
                isArchived: false,
                isUnread: true,
                modelLabel: "Gemini 3.1 Pro",
                lastMessagePreview: "Updated go.mod toolchain to Go 1.25 across 6 packages.",
                totalAdditions: 42,
                totalDeletions: 31
            ),
            CascadeSummary(
                cascadeId: "cas-dark-mode-cloud",
                title: "Dark mode for settings page",
                projectSlug: "web-console",
                workspaceUri: "cloud://acme/web-console",
                branchName: "feat/dark-mode",
                status: .inProgress,
                stepCount: 9,
                currentStepIndex: 2,
                totalSteps: 5,
                updatedAt: baseNow.addingTimeInterval(-7200),
                relativeTimeLabel: "12:04",
                statusSubtitle: "Running in cloud · Step 2 of 5",
                isPinned: false,
                isArchived: false,
                isUnread: true,
                modelLabel: "Gemini 3.8 Flash",
                lastMessagePreview: "Applying semantic obsidian tokens to SettingsView...",
                totalAdditions: 64,
                totalDeletions: 21
            ),
            CascadeSummary(
                cascadeId: "cas-idempotency-payouts",
                title: "Idempotency keys for payouts",
                projectSlug: "ledger-svc",
                workspaceUri: "file:///Users/wl/code/ledger-svc",
                branchName: "main",
                status: .done,
                stepCount: 45,
                currentStepIndex: 8,
                totalSteps: 8,
                updatedAt: baseNow.addingTimeInterval(-86400),
                relativeTimeLabel: "Yesterday",
                statusSubtitle: "Done · Merged into main",
                isPinned: false,
                isArchived: false,
                isUnread: false,
                modelLabel: "Gemini 3.1 Pro",
                lastMessagePreview: "Merged payout idempotency key store into main.",
                totalAdditions: 210,
                totalDeletions: 19
            ),
            CascadeSummary(
                cascadeId: "cas-audit-log-admin",
                title: "Audit log for admin actions",
                projectSlug: "ledger-svc",
                workspaceUri: "file:///Users/wl/code/ledger-svc",
                branchName: "main",
                status: .waiting,
                stepCount: 3,
                currentStepIndex: 2,
                totalSteps: 3,
                updatedAt: baseNow.addingTimeInterval(-172_800),
                relativeTimeLabel: "2d",
                statusSubtitle: "Archived · Planning",
                isPinned: false,
                isArchived: true,
                isUnread: false,
                modelLabel: "Gemini 3.1 Pro",
                lastMessagePreview: "Before I draft the plan I need three decisions. Tap to answer — you can also reply in your own words."
            ),
            CascadeSummary(
                cascadeId: "cas-pgx-v5-migration",
                title: "Migrate settlement store to pgx v5",
                projectSlug: "ledger-svc",
                workspaceUri: "file:///Users/wl/code/ledger-svc",
                branchName: "main",
                status: .done,
                stepCount: 37,
                currentStepIndex: 6,
                totalSteps: 6,
                updatedAt: baseNow.addingTimeInterval(-345_600),
                relativeTimeLabel: "4d",
                statusSubtitle: "Archived · Merged",
                isPinned: false,
                isArchived: true,
                isUnread: false,
                modelLabel: "Gemini 3.1 Pro",
                lastMessagePreview: "Completed pgxpool v5 batch migration."
            )
        ]

        let automations: [AutomationItem] = [
            AutomationItem(
                id: "auto-nightly-audit",
                title: "Nightly dependency audit",
                projectSlug: "ledger-svc",
                scheduleSummary: "ledger-svc · Daily at 02:00 · Flash",
                section: .scheduled,
                nextRunText: "Tonight, 02:00",
                lastRunText: "Succeeded · 22h ago",
                needsReview: false,
                isRunningNow: false
            ),
            AutomationItem(
                id: "auto-weekly-flaky",
                title: "Weekly flaky-test report",
                projectSlug: "ledger-svc",
                scheduleSummary: "ledger-svc · Mondays at 09:00 · Pro",
                section: .scheduled,
                nextRunText: "Mon, 09:00",
                lastRunText: "Needs review · 2d",
                needsReview: true,
                isRunningNow: false
            ),
            AutomationItem(
                id: "auto-pr-triage",
                title: "Triage new pull requests",
                projectSlug: "web-console",
                scheduleSummary: "web-console · On PR opened · Flash Lite",
                section: .alwaysOn,
                nextRunText: "On PR opened",
                lastRunText: "Last run 14m ago",
                needsReview: false,
                isRunningNow: false
            ),
            AutomationItem(
                id: "auto-bundle-size",
                title: "Bundle size watch",
                projectSlug: "web-console",
                scheduleSummary: "web-console · Daily at 08:00 · Flash",
                section: .paused,
                nextRunText: "Paused",
                lastRunText: "Paused · 5d ago",
                needsReview: false,
                isRunningNow: false
            )
        ]

        let contextCandidates: [ContextCandidateItem] = [
            ContextCandidateItem(
                id: "ctx-ratelimit",
                category: .files,
                title: "ratelimit.go",
                subtitle: "internal/middleware · changed this turn",
                chipLabel: "@ratelimit.go",
                isActionTrigger: false,
                isSelected: true
            ),
            ContextCandidateItem(
                id: "ctx-load-folder",
                category: .folder,
                title: "load/",
                subtitle: "Folder · 3 files",
                chipLabel: "@load/",
                isActionTrigger: false,
                isSelected: false
            ),
            ContextCandidateItem(
                id: "ctx-idempotency-conv",
                category: .mentions,
                title: "Idempotency keys for payouts",
                subtitle: "Conversation · ledger-svc",
                chipLabel: "@Idempotency keys for payouts",
                isActionTrigger: false,
                isSelected: true
            ),
            ContextCandidateItem(
                id: "ctx-terminal-last-test",
                category: .mentions,
                title: "Terminal · last test run",
                subtitle: "Output · 214 lines",
                chipLabel: "@terminal:last-test",
                isActionTrigger: false,
                isSelected: false
            ),
            ContextCandidateItem(
                id: "ctx-action-boost",
                category: .actions,
                title: "/boost",
                subtitle: "Action · extra multi-agent reasoning pass",
                chipLabel: "/boost",
                isActionTrigger: true,
                isSelected: false
            ),
            ContextCandidateItem(
                id: "ctx-skill-go-testing",
                category: .skills,
                title: "go-testing",
                subtitle: "Skill · table-driven tests, -race, golden files",
                chipLabel: "Skill · go-testing",
                isActionTrigger: false,
                isSelected: true
            )
        ]

        let questionSteps: [StructuredQuestionStepItem] = [
            StructuredQuestionStepItem(
                id: "q-step-1-storage",
                stepNumber: 1,
                shortTabTitle: "Storage",
                questionTitle: "Where should admin audit events be persisted?",
                options: [
                    "Dedicated audit_events Postgres table",
                    "Append-only Kafka audit topic",
                    "Daily S3 Parquet archive"
                ],
                selectedOptions: ["Dedicated audit_events Postgres table"],
                customWriteIn: "",
                isCompleted: true,
                isMultiSelect: false
            ),
            StructuredQuestionStepItem(
                id: "q-step-2-actions",
                stepNumber: 2,
                shortTabTitle: "Actions",
                questionTitle: "Which admin actions should be audited?",
                options: [
                    "Account freeze / unfreeze",
                    "Limit changes",
                    "Manual ledger adjustments",
                    "Role & permission changes"
                ],
                selectedOptions: [
                    "Account freeze / unfreeze",
                    "Limit changes",
                    "Manual ledger adjustments"
                ],
                customWriteIn: "",
                isCompleted: false,
                isMultiSelect: true
            ),
            StructuredQuestionStepItem(
                id: "q-step-3-retention",
                stepNumber: 3,
                shortTabTitle: "Retention",
                questionTitle: "How long should audit entries be retained?",
                options: [
                    "90 days hot + 7 years cold compliance archive",
                    "1 year hot Postgres",
                    "Indefinite immutable retention"
                ],
                selectedOptions: ["90 days hot + 7 years cold compliance archive"],
                customWriteIn: "",
                isCompleted: false,
                isMultiSelect: false
            )
        ]

        let planChanges: [PlanProposedFileChange] = [
            PlanProposedFileChange(
                id: "plan-change-batch",
                changeKind: "MODIFY",
                filePath: "settlement/batch.go",
                summaryText: "Accept a clock.Clock through BatchOptions instead of calling time.Now() directly.",
                highlightedSpan: "instead of calling time.Now() directly",
                isSelectedForCallout: false
            ),
            PlanProposedFileChange(
                id: "plan-change-test",
                changeKind: "MODIFY",
                filePath: "settlement/settlement_test.go",
                summaryText: "Create one clock per subtest; remove the package-level clk variable.",
                highlightedSpan: "remove the package-level clk variable",
                isSelectedForCallout: true
            ),
            PlanProposedFileChange(
                id: "plan-change-clock",
                changeKind: "NEW",
                filePath: "testutil/clock.go",
                summaryText: "NewTestClock(t) helper, released with t.Cleanup.",
                highlightedSpan: nil,
                isSelectedForCallout: false
            )
        ]

        let planComments: [PlanInlineComment] = [
            PlanInlineComment(
                id: "plan-comment-1",
                authorInitials: "WL",
                authorName: "You",
                statusLabel: "Pending",
                targetFilePath: "settlement/batch.go",
                quotedSpan: "instead of calling time.Now() directly",
                body: "Default to the real clock when Clock is nil, so existing callers don't break."
            ),
            PlanInlineComment(
                id: "plan-comment-2",
                authorInitials: "WL",
                authorName: "You",
                statusLabel: "Pending",
                targetFilePath: "Verification",
                quotedSpan: "go test -race -count=100 ./internal/settlement/...",
                body: "Run with -count=100 and -race to confirm the 3% flake is gone."
            )
        ]

        let vegetaCmd = "vegeta attack -rate=2000/s -duration=30s \\\n  -targets=load/transfers.txt | vegeta report"
        let rateLimiterSteps: [CascadeStep] = [
            CascadeStep(
                cascadeId: "cas-rate-limiter",
                stepIndex: 0,
                type: .userInput,
                status: .done,
                createdAt: baseNow.addingTimeInterval(-161),
                userInput: "Add a per-tenant token-bucket rate limiter to POST /transfers and run load tests.",
                attachedMentions: ["@transfers.go", "Skill · go-testing"]
            ),
            CascadeStep(
                cascadeId: "cas-rate-limiter",
                stepIndex: 1,
                type: .viewFile,
                status: .done,
                createdAt: baseNow.addingTimeInterval(-140),
                viewFile: ViewFilePayload(
                    fileUri: "file:///Users/wl/code/ledger-svc/internal/router/transfers.go",
                    startLine: 1,
                    endLine: 96,
                    totalLines: 148
                )
            ),
            CascadeStep(
                cascadeId: "cas-rate-limiter",
                stepIndex: 2,
                type: .codeAction,
                status: .done,
                createdAt: baseNow.addingTimeInterval(-95),
                codeAction: CodeActionPayload(
                    targetFileUri: "file:///Users/wl/code/ledger-svc/internal/middleware/ratelimit.go",
                    description: "Add per-tenant sync.Mutex and configurable BucketTTL to Limiter.Allow",
                    additions: 96,
                    deletions: 4,
                    startLine: 18,
                    endLine: 44,
                    diffPreviewLines: [
                        "+    mu     sync.Mutex",
                        "+ const ttl = cfg.BucketTTL",
                        "+    b.mu.Lock(); defer b.mu.Unlock()"
                    ]
                )
            ),
            CascadeStep(
                cascadeId: "cas-rate-limiter",
                stepIndex: 3,
                type: .plannerResponse,
                status: .done,
                createdAt: baseNow.addingTimeInterval(-35),
                plannerResponse: PlannerResponsePayload(
                    response: "Plan approved with your 2 comments. Tests pass — next is a load test, which needs your OK.",
                    thinking: "Addressed both review comments on Implementation Plan v2 (configurable BucketTTL and per-tenant mutex lock). Ran go test ./internal/... with 42/42 passing. Preparing vegeta load test against load/transfers.txt.",
                    thinkingDurationSeconds: 14.0,
                    referencedFiles: ["/brain/rate_limiter_plan.md", "middleware/ratelimit.go"]
                )
            ),
            CascadeStep(
                cascadeId: "cas-rate-limiter",
                stepIndex: 4,
                type: .taskBoundary,
                status: .inProgress,
                createdAt: baseNow.addingTimeInterval(-12),
                taskBoundary: TaskBoundaryPayload(
                    taskName: "Task · 4 of 7 done",
                    taskStatus: "Waiting for your approval · Step 5 of 7",
                    taskSummary: "42 unit tests passed; awaiting Face ID confirmation for vegeta load test.",
                    completedCount: 4,
                    totalCount: 7,
                    elapsedLabel: "2m 41s",
                    checklist: [
                        TaskChecklistItem(
                            id: "chk-wire-router",
                            title: "Wire limiter into router",
                            status: .done,
                            trailingBadge: nil
                        ),
                        TaskChecklistItem(
                            id: "chk-go-test",
                            title: "go test ./internal/...",
                            status: .done,
                            trailingBadge: "42 passed"
                        ),
                        TaskChecklistItem(
                            id: "chk-vegeta-load",
                            title: "Load test with vegeta",
                            status: .waiting,
                            trailingBadge: nil
                        )
                    ]
                )
            ),
            CascadeStep(
                cascadeId: "cas-rate-limiter",
                stepIndex: 5,
                type: .runCommand,
                status: .waiting,
                createdAt: baseNow,
                runCommand: RunCommandPayload(
                    commandId: "cmd-vegeta-01",
                    commandLine: vegetaCmd,
                    proposedCommandLine: vegetaCmd,
                    cwd: "~/code/ledger-svc"
                ),
                requestedInteraction: RequestedInteraction(
                    kind: .runCommand,
                    runCommand: RunCommandInteractionSpec(
                        proposedCommandLine: vegetaCmd,
                        cwd: "~/code/ledger-svc",
                        isDaemon: false
                    )
                )
            )
        ]

        let auditQuestionSteps: [CascadeStep] = [
            CascadeStep(
                cascadeId: "cas-audit-log-admin",
                stepIndex: 0,
                type: .userInput,
                status: .done,
                createdAt: baseNow.addingTimeInterval(-600),
                userInput: "Design an immutable audit log for privileged admin actions in ledger-svc."
            ),
            CascadeStep(
                cascadeId: "cas-audit-log-admin",
                stepIndex: 1,
                type: .plannerResponse,
                status: .done,
                createdAt: baseNow.addingTimeInterval(-580),
                plannerResponse: PlannerResponsePayload(
                    response: "Before I draft the plan I need three decisions. Tap to answer — you can also reply in your own words.",
                    thinking: "Identifying storage sink, auditable admin mutations, and compliance retention window.",
                    thinkingDurationSeconds: 6.0
                )
            ),
            CascadeStep(
                cascadeId: "cas-audit-log-admin",
                stepIndex: 2,
                type: .ephemeralMessage,
                status: .waiting,
                createdAt: baseNow.addingTimeInterval(-575),
                requestedInteraction: RequestedInteraction(
                    kind: .askQuestion,
                    askQuestion: AskQuestionInteractionSpec(
                        question: "Which admin actions should be audited?",
                        options: [
                            "Account freeze / unfreeze",
                            "Limit changes",
                            "Manual ledger adjustments",
                            "Role & permission changes"
                        ],
                        isMultiSelect: true
                    )
                )
            )
        ]

        let flakySettlementSteps: [CascadeStep] = [
            CascadeStep(
                cascadeId: "cas-flaky-settlement",
                stepIndex: 0,
                type: .userInput,
                status: .done,
                createdAt: baseNow.addingTimeInterval(-520),
                userInput: "Fix flaky TestSettlementBatch in CI without disabling t.Parallel()."
            ),
            CascadeStep(
                cascadeId: "cas-flaky-settlement",
                stepIndex: 1,
                type: .plannerResponse,
                status: .waiting,
                createdAt: baseNow.addingTimeInterval(-480),
                plannerResponse: PlannerResponsePayload(
                    response: "The flake comes from a shared fake clock across parallel subtests in settlement_test.go. I wrote a plan to isolate it per test — review it before I change anything?",
                    thinking: "Traced ~3% failure in TestSettlementBatch to concurrent Advance() calls on package-level clk.",
                    thinkingDurationSeconds: 9.0,
                    referencedFiles: ["/brain/implementation_plan.md"]
                ),
                requestedInteraction: RequestedInteraction(
                    kind: .filePermission,
                    filePermission: FilePermissionInteractionSpec(
                        absolutePathUri: "file:///brain/implementation_plan.md",
                        isDirectory: false
                    )
                )
            )
        ]

        let artifacts: [ArtifactSnapshot] = [
            ArtifactSnapshot(
                artifactPath: "/brain/implementation_plan.md",
                title: "Implementation Plan",
                summary: "Isolate the fake clock in settlement tests",
                kind: .implementationPlan,
                content: """
                # Isolate the fake clock in settlement tests

                TestSettlementBatch fails in ~3% of CI runs. Parallel subtests share one fake clock, so `Advance()` in one subtest moves time for the others.

                ## Proposed changes
                - **MODIFY** `settlement/batch.go` — Accept a `clock.Clock` through BatchOptions instead of calling time.Now() directly.
                - **MODIFY** `settlement/settlement_test.go` — Create one clock per subtest; remove the package-level clk variable.
                - **NEW** `testutil/clock.go` — NewTestClock(t) helper, released with t.Cleanup.

                ## Verification
                - `go test -race -count=100 ./internal/settlement/...`
                """,
                requestFeedback: true,
                userFacing: true,
                version: 2,
                updatedAt: baseNow.addingTimeInterval(-480)
            ),
            ArtifactSnapshot(
                artifactPath: "/brain/rate_limiter_plan.md",
                title: "Implementation Plan",
                summary: "Approved · 2 comments addressed",
                kind: .implementationPlan,
                content: "# Per-Tenant Rate Limiter Plan\n\nApproved · 2 comments addressed.",
                requestFeedback: false,
                userFacing: true,
                version: 2,
                updatedAt: baseNow.addingTimeInterval(-120)
            ),
            ArtifactSnapshot(
                artifactPath: "/brain/release_walkthrough_v2_3.md",
                title: "Walkthrough · v2.3",
                summary: "Walkthrough ready",
                kind: .walkthrough,
                content: "# Release v2.3 Walkthrough\n\nAll staging verification checks passed.",
                requestFeedback: false,
                userFacing: true,
                version: 1,
                updatedAt: baseNow.addingTimeInterval(-3500)
            )
        ]

        let diffs: [FilePatchDiff] = [
            FilePatchDiff(
                turnNumber: 3,
                filePath: "middleware/ratelimit.go",
                additions: 96,
                deletions: 4,
                hunkHeader: "@@ -18,9 +18,27 @@ Allow",
                isReviewed: false,
                lines: [
                    DiffLine(id: 1, kind: .hunkHeader, text: "@@ -18,9 +18,27 @@ Allow"),
                    DiffLine(id: 18, kind: .context, oldLineNumber: 18, newLineNumber: 18, text: "type bucket struct {"),
                    DiffLine(id: 19, kind: .context, oldLineNumber: 19, newLineNumber: 19, text: "    tokens float64"),
                    DiffLine(id: 20, kind: .context, oldLineNumber: 20, newLineNumber: 20, text: "    last   time.Time"),
                    DiffLine(id: 21, kind: .addition, oldLineNumber: nil, newLineNumber: 21, text: "    mu     sync.Mutex", wordHighlightRange: "sync.Mutex"),
                    DiffLine(id: 22, kind: .context, oldLineNumber: 21, newLineNumber: 22, text: "}"),
                    DiffLine(id: 23, kind: .context, oldLineNumber: 22, newLineNumber: 23, text: ""),
                    DiffLine(id: 240, kind: .deletion, oldLineNumber: 24, newLineNumber: nil, text: "const ttl = 5 * time.Minute", wordHighlightRange: "5 * time.Minute"),
                    DiffLine(id: 241, kind: .addition, oldLineNumber: nil, newLineNumber: 24, text: "const ttl = cfg.BucketTTL", wordHighlightRange: "cfg.BucketTTL"),
                    DiffLine(id: 25, kind: .context, oldLineNumber: 25, newLineNumber: 25, text: ""),
                    DiffLine(id: 26, kind: .context, oldLineNumber: 26, newLineNumber: 26, text: "func (l *Limiter) Allow(tenant string) bool {"),
                    DiffLine(id: 27, kind: .addition, oldLineNumber: nil, newLineNumber: 27, text: "    b := l.bucketFor(tenant)"),
                    DiffLine(id: 28, kind: .addition, oldLineNumber: nil, newLineNumber: 28, text: "    b.mu.Lock(); defer b.mu.Unlock()"),
                    DiffLine(id: 29, kind: .addition, oldLineNumber: nil, newLineNumber: 29, text: "    now := time.Now()"),
                    DiffLine(id: 30, kind: .addition, oldLineNumber: nil, newLineNumber: 30, text: "    elapsed := now.Sub(b.last).Seconds()"),
                    DiffLine(id: 31, kind: .addition, oldLineNumber: nil, newLineNumber: 31, text: "    b.tokens = min(l.burst, b.tokens+elapsed*l.rate)")
                ]
            ),
            FilePatchDiff(
                turnNumber: 3,
                filePath: "router/transfers.go",
                additions: 18,
                deletions: 6,
                hunkHeader: "@@ -42,8 +42,20 @@ RegisterTransferRoutes",
                isReviewed: true,
                lines: [
                    DiffLine(id: 101, kind: .hunkHeader, text: "@@ -42,8 +42,20 @@ RegisterTransferRoutes"),
                    DiffLine(id: 102, kind: .addition, oldLineNumber: nil, newLineNumber: 45, text: "    r.Use(middleware.RateLimit(limiter))")
                ]
            ),
            FilePatchDiff(
                turnNumber: 2,
                filePath: "middleware/ratelimit_test.go",
                additions: 10,
                deletions: 2,
                hunkHeader: "@@ -1,6 +1,14 @@ TestLimiterAllow",
                isReviewed: true,
                lines: [
                    DiffLine(id: 201, kind: .hunkHeader, text: "@@ -1,6 +1,14 @@ TestLimiterAllow"),
                    DiffLine(id: 202, kind: .addition, oldLineNumber: nil, newLineNumber: 12, text: "    require.True(t, lim.Allow(\"tenant-acme\"))")
                ]
            ),
            FilePatchDiff(
                turnNumber: 1,
                filePath: "config/limits.yaml",
                additions: 4,
                deletions: 2,
                hunkHeader: "@@ -8,4 +8,6 @@ transfers:",
                isReviewed: false,
                lines: [
                    DiffLine(id: 301, kind: .hunkHeader, text: "@@ -8,4 +8,6 @@ transfers:"),
                    DiffLine(id: 302, kind: .addition, oldLineNumber: nil, newLineNumber: 10, text: "  bucket_ttl: 10m")
                ]
            )
        ]

        let store = AntigravitySessionStore(
            hosts: [macHost, cloudHost],
            activeHost: macHost,
            projects: projects,
            workspaces: workspaces,
            selectedWorkspaceUri: workspaces[0].workspaceUri,
            summaries: summaries,
            automations: automations,
            contextCandidates: contextCandidates,
            questionSteps: questionSteps,
            activeQuestionStepIndex: 1,
            planChanges: planChanges,
            planComments: planComments,
            activeCascadeId: "cas-rate-limiter",
            stepsByCascadeId: [
                "cas-rate-limiter": rateLimiterSteps,
                "cas-audit-log-admin": auditQuestionSteps,
                "cas-flaky-settlement": flakySettlementSteps
            ],
            activeArtifacts: artifacts,
            activeTurnDiffs: diffs,
            selectedDiffTurn: 3,
            selectedDiffFileIndex: 0,
            activeLineCommentDraft: "Use l.clock.Now() — the plan says to inject the clock so tests can control time.",
            selectedModelConfig: CascadeModelConfig.catalog[0]
        )
        store.isVerificationMode = true
        store.isInitialSessionCheckComplete = true
        store.connectionStatusText = "Demo Sandbox · Offline ESDD Fixtures"
        store.composerAttachments = [
            ComposerAttachmentChip(
                id: "chip-ratelimit",
                kind: .fileMention,
                label: "@ratelimit.go",
                targetUri: "file:///Users/wl/code/ledger-svc/internal/middleware/ratelimit.go"
            )
        ]
        store.composerDraftText = "Use 1000/s instead — staging is smaller than prod."
        return store
    }

    /// Clean, empty production store used on real devices (`launchVerifyCase() == nil`).
    /// Contains zero mock/demo conversations, projects, automations, or context chips.
    public static func makeLiveStore() -> AntigravitySessionStore {
        let placeholderHost = RemoteHostInstance(
            instanceId: "unpaired",
            hostname: "Antigravity Desktop",
            version: "",
            channel: .cloudRelay,
            endpointURL: URL(string: SAPISIDHashGenerator.defaultOrigin)!,
            isOnline: false,
            latencyMs: 0
        )
        let store = AntigravitySessionStore(
            hosts: [],
            activeHost: placeholderHost,
            projects: [],
            workspaces: [],
            selectedWorkspaceUri: "",
            summaries: [],
            automations: [],
            contextCandidates: [],
            questionSteps: [],
            activeQuestionStepIndex: 1,
            planChanges: [],
            planComments: [],
            activeCascadeId: "",
            stepsByCascadeId: [:],
            activeArtifacts: [],
            activeTurnDiffs: [],
            selectedDiffTurn: 1,
            selectedDiffFileIndex: 0,
            activeLineCommentDraft: "",
            selectedModelConfig: CascadeModelConfig.liveDefaultCatalog[0],
            availableModels: CascadeModelConfig.liveDefaultCatalog,
            availableAgents: ["Default"]
        )
        store.isVerificationMode = false
        store.isInitialSessionCheckComplete = false
        store.selectedProjectId = ""
        store.contextMenuTargetCascadeId = ""
        store.swipePreviewCascadeId = ""
        store.selectedArtifactPath = ""
        store.selectedDiffLineNumber = nil
        store.availableGitHubRepos = []
        store.composerAttachments = []
        store.composerDraftText = ""
        store.connectionStatusText = "Not Connected"
        return store
    }
}
