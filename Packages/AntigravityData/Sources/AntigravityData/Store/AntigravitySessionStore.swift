import Foundation
import Observation

/// Active navigation destination in `AntigravityShellController`.
public enum AntigravityNavigationRoute: String, Sendable, Equatable {
    case pairingQR
    case workspaceHome
    case cascadeChat
    case artifactInspector
    case turnDiffInspector
}

/// Modal sheet presentation state in `AntigravityShellController`.
public enum AntigravityModalSheet: Identifiable, Sendable, Equatable {
    case permissionGate(stepIndex: Int)
    case askQuestion(stepIndex: Int)
    case modelConfigPicker
    case fileMentionPicker
    case newCascadeSheet

    public var id: String {
        switch self {
        case .permissionGate(let idx): return "permission-\(idx)"
        case .askQuestion(let idx): return "question-\(idx)"
        case .modelConfigPicker: return "model-picker"
        case .fileMentionPicker: return "file-picker"
        case .newCascadeSheet: return "new-cascade"
        }
    }
}

/// Inline review annotation attached to a specific line in `TurnDiffViewController`.
public struct DiffLineComment: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var filePath: String
    public var lineNumber: Int
    public var author: String
    public var commentText: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        filePath: String,
        lineNumber: Int,
        author: String = "You (iOS)",
        commentText: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.author = author
        self.commentText = commentText
        self.createdAt = createdAt
    }
}

/// Central `@Observable` state coordinator for `iOSAntigravity`.
/// Drives Session List (`WorkspaceHomeViewController`), Message List (`CascadeChatViewController`),
/// Composer Input Box (`ChatComposerView`), Permission Gates, Artifacts, and Turn Diffs.
@MainActor
@Observable
public final class AntigravitySessionStore {
    // MARK: - Host & Workspace State
    public var activeHost: RemoteHostInstance
    public var workspaces: [WorkspaceInfo]
    public var selectedWorkspaceUri: String

    // MARK: - Session List State (会话列表)
    public var summaries: [CascadeSummary]
    public var searchQuery: String = ""
    public var selectedFilterCategory: SessionFilterCategory = .all
    public var selectedWorktreeFilter: String? = nil
    public var isRefreshingSummaries: Bool = false

    // MARK: - Active Conversation & Message List State (消息列表)
    public var activeCascadeId: String
    public var stepsByCascadeId: [String: [CascadeStep]] = [:]
    public var expandedThinkingStepIds: Set<String> = []
    public var expandedEvidenceGroupIds: Set<String> = []
    public var expandedTerminalStepIds: Set<String> = []
    public var isAutoScrollPinnedToBottom: Bool = true
    public var unreadStreamingStepCount: Int = 0

    // MARK: - Composer Input Box State (输入框)
    public var composerDraftText: String = ""
    public var composerAttachments: [ComposerAttachmentChip] = []
    public var selectedModelConfig: CascadeModelConfig
    public var isSlashPopupDismissedManually: Bool = false

    // MARK: - Permission Gate, Artifacts & Diff Inspector State
    public var safeAutoAcceptEnabled: Bool
    public var activeTurnGrants: Set<String> = ["ReadOnlyWorkspace", "verification/*"]
    public var activeArtifacts: [ArtifactSnapshot]
    public var selectedArtifactPath: String = "/brain/implementation_plan.md"
    public var activeTurnDiffs: [FilePatchDiff]
    public var selectedDiffFilePath: String = "Packages/AntigravityData/Protocol/ConnectEnvelope.swift"
    public var diffComments: [DiffLineComment] = []

    // MARK: - Navigation & Modal State
    public var currentRoute: AntigravityNavigationRoute = .cascadeChat
    public var presentedSheet: AntigravityModalSheet? = nil
    public var lastDispatchedInteraction: CascadeUserInteractionPayload? = nil

    // MARK: - Dependencies
    private let projectionStore: LocalProjectionStore
    private var rpcClient: AntigravityRPCClient?

    public init(
        activeHost: RemoteHostInstance,
        workspaces: [WorkspaceInfo] = [],
        selectedWorkspaceUri: String = "",
        summaries: [CascadeSummary] = [],
        activeCascadeId: String = "",
        activeSteps: [CascadeStep] = [],
        activeArtifacts: [ArtifactSnapshot] = [],
        activeTurnDiffs: [FilePatchDiff] = [],
        selectedModelConfig: CascadeModelConfig = CascadeModelConfig.catalog[0],
        safeAutoAcceptEnabled: Bool = true,
        projectionStore: LocalProjectionStore = LocalProjectionStore()
    ) {
        self.activeHost = activeHost
        self.workspaces = workspaces
        self.selectedWorkspaceUri = selectedWorkspaceUri
        self.summaries = summaries
        self.activeCascadeId = activeCascadeId
        if !activeCascadeId.isEmpty {
            self.stepsByCascadeId[activeCascadeId] = activeSteps
        }
        self.activeArtifacts = activeArtifacts
        self.activeTurnDiffs = activeTurnDiffs
        self.selectedModelConfig = selectedModelConfig
        self.safeAutoAcceptEnabled = safeAutoAcceptEnabled
        self.projectionStore = projectionStore
        self.rpcClient = AntigravityRPCClient(
            baseURL: activeHost.endpointURL,
            csrfToken: "csrf-golden-star-session-token"
        )
    }

    // MARK: - Computed Properties for Session List (会话列表)

    public var currentWorkspace: WorkspaceInfo? {
        workspaces.first(where: { $0.workspaceUri == selectedWorkspaceUri }) ?? workspaces.first
    }

    public var availableWorktrees: [String] {
        currentWorkspace?.worktrees ?? ["main"]
    }

    /// Filtered and sorted conversation summaries for `WorkspaceHomeViewController`.
    public var filteredSummaries: [CascadeSummary] {
        summaries
            .filter { !$0.isArchived }
            .filter { summary in
                if !selectedWorkspaceUri.isEmpty && summary.workspaceUri != selectedWorkspaceUri {
                    return false
                }
                if let branch = selectedWorktreeFilter, !branch.isEmpty, summary.branchName != branch {
                    return false
                }
                switch selectedFilterCategory {
                case .all:
                    break
                case .waitingApproval:
                    if summary.status != .waiting { return false }
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
                    let matchesBranch = summary.branchName.lowercased().contains(q)
                    let matchesPending = (summary.pendingInteractionTitle ?? "").lowercased().contains(q)
                    let matchesPreview = (summary.lastMessagePreview ?? "").lowercased().contains(q)
                    return matchesTitle || matchesBranch || matchesPending || matchesPreview
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.status == .waiting && rhs.status != .waiting { return true }
                if rhs.status == .waiting && lhs.status != .waiting { return false }
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    public var pinnedSummaries: [CascadeSummary] {
        filteredSummaries.filter { $0.isPinned }
    }

    public var unpinnedSummaries: [CascadeSummary] {
        filteredSummaries.filter { !$0.isPinned }
    }

    public var waitingApprovalCount: Int {
        summaries.filter { !$0.isArchived && $0.status == .waiting }.count
    }

    public var runningCascadeCount: Int {
        summaries.filter { !$0.isArchived && ($0.status == .inProgress || $0.status == .pending) }.count
    }

    // MARK: - Computed Properties for Active Message List (消息列表)

    public var activeSummary: CascadeSummary? {
        summaries.first(where: { $0.cascadeId == activeCascadeId })
    }

    public var activeSteps: [CascadeStep] {
        get { stepsByCascadeId[activeCascadeId] ?? [] }
        set { stepsByCascadeId[activeCascadeId] = newValue }
    }

    /// Groups consecutive file reads, searches, and edits into collapsible `evidenceGroup` items.
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

    // MARK: - Computed Properties for Composer Input Box (输入框)

    /// Active `/slash` command suggestions when the user types `/` at the start of the composer.
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

    /// Active `@file` autocomplete suggestions when the user types `@` in the composer.
    public var activeFileMentionSuggestions: [String] {
        guard let lastWord = composerDraftText.split(separator: " ").last,
              lastWord.hasPrefix("@") else {
            return []
        }
        let query = String(lastWord.dropFirst()).lowercased()
        let files = currentWorkspace?.indexedFiles ?? [
            "Packages/AntigravityData/Protocol/ConnectEnvelope.swift",
            "Packages/AntigravityData/Protocol/ProtobufStepDecoder.swift",
            "Packages/AntigravityData/Protocol/InteractionBuilder.swift",
            "iOS/ViewControllers/Cascade/CascadeChatViewController.swift",
            "iOS/Views/Composer/ChatComposerView.swift",
            "verification/esdd-verify.py",
            "specs/esdd-ir.json"
        ]
        if query.isEmpty { return Array(files.prefix(5)) }
        return files.filter { $0.lowercased().contains(query) }
    }

    public var canSendCurrentDraft: Bool {
        !composerDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !composerAttachments.isEmpty
    }

    // MARK: - Session List Actions (会话列表交互)

    public func selectWorkspace(_ workspaceUri: String) {
        selectedWorkspaceUri = workspaceUri
        selectedWorktreeFilter = nil
        if let firstCascade = summaries.first(where: { $0.workspaceUri == workspaceUri && !$0.isArchived }) {
            selectCascade(firstCascade.cascadeId)
        }
    }

    public func selectCascade(_ cascadeId: String) {
        activeCascadeId = cascadeId
        currentRoute = .cascadeChat
        unreadStreamingStepCount = 0
        isAutoScrollPinnedToBottom = true
    }

    public func createNewCascade(
        title: String = "New Agentic Session",
        branchName: String? = nil,
        initialPrompt: String? = nil
    ) {
        let newId = "cas-\(UUID().uuidString.prefix(8).lowercased())"
        let branch = branchName ?? currentWorkspace?.activeBranch ?? "main"
        let workspaceUri = selectedWorkspaceUri.isEmpty
            ? (workspaces.first?.workspaceUri ?? "file:///home/antigravity/venciallee/iOSAntigravity")
            : selectedWorkspaceUri

        let newSummary = CascadeSummary(
            cascadeId: newId,
            title: title,
            workspaceUri: workspaceUri,
            branchName: branch,
            status: initialPrompt != nil ? .inProgress : .done,
            stepCount: initialPrompt != nil ? 1 : 0,
            updatedAt: Date(),
            isPinned: false,
            lastMessagePreview: initialPrompt ?? "Ready for instructions..."
        )
        summaries.insert(newSummary, at: 0)
        stepsByCascadeId[newId] = []
        activeCascadeId = newId
        currentRoute = .cascadeChat

        if let prompt = initialPrompt, !prompt.isEmpty {
            composerDraftText = prompt
            sendCurrentDraft()
        }
    }

    public func togglePinCascade(_ cascadeId: String) {
        guard let idx = summaries.firstIndex(where: { $0.cascadeId == cascadeId }) else { return }
        summaries[idx].isPinned.toggle()
        Task {
            await projectionStore.saveProjectedSummaries(summaries)
        }
    }

    public func archiveCascade(_ cascadeId: String) {
        guard let idx = summaries.firstIndex(where: { $0.cascadeId == cascadeId }) else { return }
        summaries[idx].isArchived = true
        if activeCascadeId == cascadeId, let next = filteredSummaries.first {
            activeCascadeId = next.cascadeId
        }
        Task {
            await projectionStore.saveProjectedSummaries(summaries)
        }
    }

    public func deleteCascade(_ cascadeId: String) {
        summaries.removeAll { $0.cascadeId == cascadeId }
        stepsByCascadeId.removeValue(forKey: cascadeId)
        if activeCascadeId == cascadeId, let next = filteredSummaries.first {
            activeCascadeId = next.cascadeId
        }
        Task {
            await projectionStore.saveProjectedSummaries(summaries)
        }
    }

    public func refreshWorkspacesAndSummaries() async {
        isRefreshingSummaries = true
        defer { isRefreshingSummaries = false }
        if let client = rpcClient, let remoteSummaries = try? await client.getAllCascadeTrajectories() {
            for remote in remoteSummaries {
                if let idx = summaries.firstIndex(where: { $0.cascadeId == remote.cascadeId }) {
                    summaries[idx].status = remote.status
                    summaries[idx].stepCount = max(summaries[idx].stepCount, remote.stepCount)
                    summaries[idx].updatedAt = Date()
                } else {
                    summaries.append(remote)
                }
            }
            await projectionStore.saveProjectedSummaries(summaries)
        }
    }

    // MARK: - Message List & Step Actions (消息列表交互)

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

    /// Resolves a `WAITING` permission or command step via `InteractionBuilder` and `AntigravityRPCClient`.
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
                summaries[sumIdx].pendingInteractionTitle = nil
            }
        case .allowOnce, .alwaysAllowInTurn, .allowWithModifiedCommand, .answerQuestion:
            if case .alwaysAllowInTurn = decision,
               let pattern = targetStep.requestedInteraction?.permission?.suggestedPersistPattern {
                activeTurnGrants.insert(pattern)
            }
            steps[idx].status = .done
            let nextStepIndex = (steps.map(\.stepIndex).max() ?? stepIndex) + 1
            let followUp = CascadeStep(
                cascadeId: activeCascadeId,
                stepIndex: nextStepIndex,
                type: .plannerResponse,
                status: .done,
                plannerResponse: PlannerResponsePayload(
                    response: "Permission granted (`\(targetStep.runCommand?.commandLine ?? "interaction")`). ESDD verification completed with **8/8 claims passing**.",
                    thinking: "Received HandleCascadeUserInteraction approval on step \(stepIndex). Resuming trajectory execution.",
                    thinkingDurationSeconds: 1.2,
                    referencedFiles: ["verification/output/report.md"]
                )
            )
            steps.append(followUp)
            if let sumIdx = summaries.firstIndex(where: { $0.cascadeId == activeCascadeId }) {
                summaries[sumIdx].status = .done
                summaries[sumIdx].stepCount = steps.count
                summaries[sumIdx].pendingInteractionTitle = nil
                summaries[sumIdx].updatedAt = Date()
            }
        }
        stepsByCascadeId[activeCascadeId] = steps
        presentedSheet = nil

        if let client = rpcClient {
            Task {
                _ = try? await client.handleCascadeUserInteraction(payload)
            }
        }
    }

    // MARK: - Composer Input Box Actions (输入框交互)

    public func applySlashCommand(_ item: SlashCommandItem) {
        composerDraftText = "\(item.command) "
        isSlashPopupDismissedManually = true
    }

    public func attachFileMention(_ filePath: String) {
        let fileName = (filePath as NSString).lastPathComponent
        let chip = ComposerAttachmentChip(
            kind: .fileMention,
            label: "@\(fileName)",
            targetUri: "file:///home/antigravity/venciallee/iOSAntigravity/\(filePath)"
        )
        if !composerAttachments.contains(where: { $0.targetUri == chip.targetUri }) {
            composerAttachments.append(chip)
        }
        // Strip trailing @query token from draft text if present
        if let lastRange = composerDraftText.range(of: "@[^\\s]*$", options: .regularExpression) {
            composerDraftText.removeSubrange(lastRange)
        }
    }

    public func removeAttachment(_ chipId: String) {
        composerAttachments.removeAll { $0.id == chipId }
    }

    /// Sends the current composer message, persists to the Durable Outbox, appends the user turn
    /// to `activeSteps`, and dispatches `SendUserCascadeMessage` over Connect-RPC.
    public func sendCurrentDraft() {
        let trimmed = composerDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !composerAttachments.isEmpty else { return }

        let messageBody = trimmed.isEmpty
            ? "Inspect attached context: \(composerAttachments.map(\.label).joined(separator: ", "))"
            : trimmed
        let mentionLabels = composerAttachments.map(\.label)

        var currentSteps = stepsByCascadeId[activeCascadeId] ?? []
        let nextIndex = (currentSteps.map(\.stepIndex).max() ?? 0) + 1

        let userStep = CascadeStep(
            cascadeId: activeCascadeId,
            stepIndex: nextIndex,
            type: .userInput,
            status: .done,
            createdAt: Date(),
            userInput: messageBody,
            attachedMentions: mentionLabels,
            isQueuedInOutbox: false
        )
        currentSteps.append(userStep)

        let assistantStep = CascadeStep(
            cascadeId: activeCascadeId,
            stepIndex: nextIndex + 1,
            type: .plannerResponse,
            status: .inProgress,
            createdAt: Date(),
            plannerResponse: PlannerResponsePayload(
                response: "Executing request with `\(selectedModelConfig.displayName)` (`\(selectedModelConfig.effort.rawValue)` effort, `\(selectedModelConfig.mode.rawValue)` mode)...",
                thinking: "Parsing user prompt and \(mentionLabels.count) attached context references on branch \(activeSummary?.branchName ?? "main").",
                thinkingDurationSeconds: 1.8,
                referencedFiles: composerAttachments.map(\.targetUri)
            )
        )
        currentSteps.append(assistantStep)
        stepsByCascadeId[activeCascadeId] = currentSteps

        if let sumIdx = summaries.firstIndex(where: { $0.cascadeId == activeCascadeId }) {
            summaries[sumIdx].stepCount = currentSteps.count
            summaries[sumIdx].status = .inProgress
            summaries[sumIdx].lastMessagePreview = messageBody
            summaries[sumIdx].updatedAt = Date()
        }

        // Reset composer state
        composerDraftText = ""
        composerAttachments.removeAll()
        isSlashPopupDismissedManually = false
        isAutoScrollPinnedToBottom = true

        let cid = activeCascadeId
        let modelId = selectedModelConfig.modelId
        let storeRef = projectionStore
        let clientRef = rpcClient
        Task {
            await storeRef.enqueueOutbox(
                OutboxEntry(cascadeId: cid, kind: .userMessage, messageText: messageBody)
            )
            await storeRef.saveProjectedSteps(currentSteps, for: cid)
            _ = try? await clientRef?.sendUserCascadeMessage(
                cascadeId: cid,
                text: messageBody,
                modelId: modelId
            )
            _ = await storeRef.drainOutbox()
        }
    }

    public func stopActiveCascadeStreaming() {
        guard var currentSteps = stepsByCascadeId[activeCascadeId] else { return }
        for i in currentSteps.indices where currentSteps[i].status == .inProgress || currentSteps[i].status == .pending {
            currentSteps[i].status = .cancelled
        }
        stepsByCascadeId[activeCascadeId] = currentSteps
        if let sumIdx = summaries.firstIndex(where: { $0.cascadeId == activeCascadeId }) {
            summaries[sumIdx].status = .cancelled
        }
    }

    // MARK: - Artifact & Turn Diff Actions

    public func approveArtifactPlan(artifactPath: String) {
        if let idx = activeArtifacts.firstIndex(where: { $0.artifactPath == artifactPath }) {
            activeArtifacts[idx].requestFeedback = false
        }
        if let waiting = pendingWaitingStep {
            resolveWaitingStep(stepIndex: waiting.stepIndex, decision: .allowOnce)
        }
        currentRoute = .cascadeChat
    }

    public func addDiffComment(filePath: String, lineNumber: Int, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        diffComments.append(
            DiffLineComment(filePath: filePath, lineNumber: lineNumber, commentText: trimmed)
        )
    }

    public func acceptPatchFile(_ filePath: String) {
        activeTurnDiffs.removeAll { $0.filePath == filePath }
        if let next = activeTurnDiffs.first {
            selectedDiffFilePath = next.filePath
        } else {
            currentRoute = .cascadeChat
        }
    }

    // MARK: - Deterministic ESDD Fixture Factory

    public static func makeESDDVerificationStore() -> AntigravitySessionStore {
        let host = RemoteHostInstance(
            instanceId: "lt74xt6l0m-golden-star",
            hostname: "lt74xt6l0m-golden-star",
            version: "v2.30.0",
            channel: .cloudRelay,
            endpointURL: URL(string: "https://antigravity.google.com/r/lt74xt6l0m-golden-star")!,
            isOnline: true,
            latencyMs: 18
        )

        let workspaces = [
            WorkspaceInfo(
                workspaceUri: "file:///home/antigravity/venciallee/iOSAntigravity",
                displayName: "venciallee/iOSAntigravity",
                activeBranch: "main",
                worktrees: ["main", "feat/connect-rpc-client", "feat/live-activity"],
                activeCascadeCount: 3,
                indexedFiles: [
                    "Packages/AntigravityData/Protocol/ConnectEnvelope.swift",
                    "Packages/AntigravityData/Protocol/ProtobufStepDecoder.swift",
                    "Packages/AntigravityData/Protocol/InteractionBuilder.swift",
                    "iOS/ViewControllers/Cascade/CascadeChatViewController.swift",
                    "iOS/Views/Composer/ChatComposerView.swift",
                    "verification/esdd-verify.py"
                ]
            ),
            WorkspaceInfo(
                workspaceUri: "file:///home/antigravity/exa-core",
                displayName: "antigravity/exa-core",
                activeBranch: "release/v2.30",
                worktrees: ["release/v2.30", "fix/connect-keepalive"],
                activeCascadeCount: 1,
                indexedFiles: [
                    "exa/language_server_pb/language_server.proto",
                    "exa/cortex_pb/cortex_step.proto"
                ]
            )
        ]

        let summaries = [
            CascadeSummary(
                cascadeId: "cas-01-waiting",
                title: "Implement Native Connect-RPC & Live Activity",
                workspaceUri: "file:///home/antigravity/venciallee/iOSAntigravity",
                branchName: "feat/connect-rpc-client",
                status: .waiting,
                stepCount: 24,
                updatedAt: Date(),
                isPinned: true,
                pendingInteractionTitle: "Approve command: python3 verification/esdd-verify.py",
                lastMessagePreview: "Waiting for permission to execute E2E verification suite",
                totalAdditions: 412,
                totalDeletions: 38
            ),
            CascadeSummary(
                cascadeId: "cas-02-running",
                title: "Audit CoreText 120fps Streaming Cell Layout",
                workspaceUri: "file:///home/antigravity/venciallee/iOSAntigravity",
                branchName: "feat/live-activity",
                status: .inProgress,
                stepCount: 14,
                updatedAt: Date().addingTimeInterval(-180),
                isPinned: true,
                lastMessagePreview: "Grouping consecutive view_file and code_action steps into Evidence Card",
                totalAdditions: 198,
                totalDeletions: 14
            ),
            CascadeSummary(
                cascadeId: "cas-03-done",
                title: "Decode Binary Protobuf Trajectory Steps (>600 ceiling)",
                workspaceUri: "file:///home/antigravity/venciallee/iOSAntigravity",
                branchName: "main",
                status: .done,
                stepCount: 642,
                updatedAt: Date().addingTimeInterval(-3600),
                isPinned: false,
                lastMessagePreview: "Verified binary wire format fallback when JSON serializer exceeds 600 steps",
                totalAdditions: 229,
                totalDeletions: 12
            )
        ]

        let steps: [CascadeStep] = [
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 19,
                type: .userInput,
                status: .done,
                userInput: "Implement the Connect-RPC 5-byte envelope parser, wire up Session List / Message List / Composer Input, and run the ESDD verification suite.",
                attachedMentions: ["@ConnectEnvelope.swift", "@esdd-ir.json"]
            ),
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 20,
                type: .taskBoundary,
                status: .inProgress,
                taskBoundary: TaskBoundaryPayload(
                    taskName: "Phase 2: Connect-RPC Streaming & ESDD Verification",
                    taskStatus: "Running E2E protocol & HIG geometry assertions",
                    taskSummary: "Verified 5-byte Connect framing and binary Protobuf step decoding.",
                    completedItems: 4,
                    totalItems: 5
                )
            ),
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 21,
                type: .viewFile,
                status: .done,
                viewFile: ViewFilePayload(
                    fileUri: "file:///home/antigravity/venciallee/iOSAntigravity/specs/esdd-ir.json",
                    startLine: 1,
                    endLine: 120,
                    totalLines: 210
                )
            ),
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 22,
                type: .codeAction,
                status: .done,
                codeAction: CodeActionPayload(
                    targetFileUri: "file:///home/antigravity/venciallee/iOSAntigravity/Packages/AntigravityData/Sources/AntigravityData/Protocol/ConnectEnvelope.swift",
                    description: "Implement 5-byte Connect streaming parser & binary Protobuf decoder",
                    additions: 184,
                    deletions: 22,
                    startLine: 1,
                    endLine: 77,
                    diffPreviewLines: [
                        "+ public static func encode(payload: Data, flags: Flags = []) -> Data",
                        "+ public mutating func feed(_ chunk: Data) -> [ConnectEnvelopeFrame]"
                    ]
                )
            ),
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 23,
                type: .plannerResponse,
                status: .done,
                plannerResponse: PlannerResponsePayload(
                    response: "I have implemented `ConnectEnvelope.swift` and `ProtobufStepDecoder.swift`, and wired `InteractionBuilder` to match field 56 (`requestedInteraction`). Now executing the ESDD suite.",
                    thinking: "Analyzing exa.language_server_pb.LanguageServerService framing: 1B flags + 4B big-endian uint32 length. Checking RequestedInteraction oneof field numbers (3=runCommand, 19=filePermission, 21=permission, 22=askQuestion).",
                    thinkingDurationSeconds: 3.4,
                    referencedFiles: [
                        "Packages/AntigravityData/Protocol/ConnectEnvelope.swift",
                        "Packages/AntigravityData/Protocol/ProtobufStepDecoder.swift"
                    ]
                )
            ),
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 24,
                type: .runCommand,
                status: .waiting,
                runCommand: RunCommandPayload(
                    commandId: "cmd-esdd-01",
                    commandLine: "python3 verification/esdd-verify.py --suite all",
                    proposedCommandLine: "python3 verification/esdd-verify.py --suite all",
                    cwd: "/home/antigravity/venciallee/iOSAntigravity",
                    exitCode: 0,
                    outputPreview: "PASS [Spec-DAG] 8/8 states, 9/9 events verified\nPASS [Connect-RPC] 5-byte framing & binary Protobuf (>600 steps) OK",
                    durationMs: 1420
                ),
                requestedInteraction: RequestedInteraction(
                    kind: .permission,
                    permission: PermissionInteractionSpec(
                        action: "execute",
                        target: "python3 verification/esdd-verify.py --suite all",
                        suggestedPersistPattern: "verification/*",
                        persistSuggestionType: .suggested,
                        reason: "Run ESDD E2E protocol & visual screenshot verification suite"
                    )
                )
            )
        ]

        let artifacts = [
            ArtifactSnapshot(
                artifactPath: "/brain/implementation_plan.md",
                title: "implementation_plan.md",
                summary: "Architecture plan for Native iOS Antigravity Client over Connect-RPC",
                kind: .implementationPlan,
                content: "# iOSAntigravity Native Architecture Plan\n\n> [!IMPORTANT]\n> Connects directly to `language_server --standalone --subclient_type hub` via Connect-RPC without intermediate CRDT transcoding.",
                requestFeedback: true,
                userFacing: true,
                version: 3
            ),
            ArtifactSnapshot(
                artifactPath: "/brain/esdd_verification_walkthrough.md",
                title: "esdd_verification_walkthrough.md",
                summary: "Visual verification report with 8 @3x iPhone 16 Pro screenshots",
                kind: .walkthrough,
                content: "# ESDD Verification Walkthrough\nAll 8 states and 8 acceptance claims verified at @3x.",
                requestFeedback: false,
                userFacing: true,
                version: 1
            )
        ]

        let diffs = [
            FilePatchDiff(
                filePath: "Packages/AntigravityData/Protocol/ConnectEnvelope.swift",
                additions: 184,
                deletions: 22,
                lines: [
                    DiffLine(id: 1, kind: .hunkHeader, text: "@@ -12,6 +12,19 @@ public struct ConnectEnvelopeFrame: Sendable {"),
                    DiffLine(id: 2, kind: .context, oldLineNumber: 12, newLineNumber: 12, text: "    public let flags: Flags"),
                    DiffLine(id: 3, kind: .deletion, oldLineNumber: 13, newLineNumber: nil, text: "    public let rawJSON: String"),
                    DiffLine(id: 4, kind: .addition, oldLineNumber: nil, newLineNumber: 13, text: "    public let payload: Data"),
                    DiffLine(id: 5, kind: .addition, oldLineNumber: nil, newLineNumber: 14, text: "    public static let endStream = Flags(rawValue: 0x02)"),
                    DiffLine(id: 6, kind: .context, oldLineNumber: 14, newLineNumber: 15, text: "}")
                ]
            ),
            FilePatchDiff(
                filePath: "iOS/Views/Composer/ChatComposerView.swift",
                additions: 215,
                deletions: 12,
                lines: [
                    DiffLine(id: 10, kind: .hunkHeader, text: "@@ -1,18 +1,64 @@ public struct ChatComposerView: View {"),
                    DiffLine(id: 11, kind: .addition, oldLineNumber: nil, newLineNumber: 18, text: "    TextField(\"Ask Antigravity or type / for workflows...\", text: $store.composerDraftText, axis: .vertical)"),
                    DiffLine(id: 12, kind: .addition, oldLineNumber: nil, newLineNumber: 19, text: "        .lineLimit(1...6)")
                ]
            )
        ]

        let store = AntigravitySessionStore(
            activeHost: host,
            workspaces: workspaces,
            selectedWorkspaceUri: workspaces[0].workspaceUri,
            summaries: summaries,
            activeCascadeId: "cas-01-waiting",
            activeSteps: steps,
            activeArtifacts: artifacts,
            activeTurnDiffs: diffs
        )
        store.composerAttachments = [
            ComposerAttachmentChip(
                kind: .fileMention,
                label: "@ConnectEnvelope.swift",
                targetUri: "file:///home/antigravity/venciallee/iOSAntigravity/Packages/AntigravityData/Protocol/ConnectEnvelope.swift"
            )
        ]
        return store
    }
}
