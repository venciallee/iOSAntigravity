import Foundation

/// Maps to `exa.cortex_pb.CortexStepStatus` (binary field 4 on `gemini_coder.Step`).
public enum CortexStepStatus: Int, Codable, Sendable, CaseIterable {
    case unspecified = 0
    case pending = 1
    case inProgress = 2
    case done = 3
    case error = 4
    case cancelled = 5
    case blocked = 7
    case waiting = 9

    public var jsonName: String {
        switch self {
        case .unspecified: return "CORTEX_STEP_STATUS_UNSPECIFIED"
        case .pending: return "CORTEX_STEP_STATUS_PENDING"
        case .inProgress: return "CORTEX_STEP_STATUS_IN_PROGRESS"
        case .done: return "CORTEX_STEP_STATUS_DONE"
        case .error: return "CORTEX_STEP_STATUS_ERROR"
        case .cancelled: return "CORTEX_STEP_STATUS_CANCELLED"
        case .blocked: return "CORTEX_STEP_STATUS_BLOCKED"
        case .waiting: return "CORTEX_STEP_STATUS_WAITING"
        }
    }

    public var displayBadgeText: String {
        switch self {
        case .unspecified: return "IDLE"
        case .pending: return "QUEUED"
        case .inProgress: return "RUNNING"
        case .done: return "DONE"
        case .error: return "ERROR"
        case .cancelled: return "STOPPED"
        case .blocked: return "BLOCKED"
        case .waiting: return "WAITING"
        }
    }

    public static func from(jsonName: String) -> CortexStepStatus {
        for status in Self.allCases where status.jsonName == jsonName {
            return status
        }
        let upper = jsonName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if upper.contains("WAITING") || upper.contains("NEEDS_USER") || upper.contains("APPROVAL") || upper.contains("PAUSED") {
            return .waiting
        }
        if upper.contains("BLOCKED") {
            return .blocked
        }
        if upper.contains("RUNNING") || upper.contains("IN_PROGRESS") || upper.contains("BUSY") || upper.contains("STREAMING") || upper.contains("EXECUTING") {
            return .inProgress
        }
        if upper.contains("PENDING") || upper.contains("QUEUED") {
            return .pending
        }
        if upper.contains("ERROR") || upper.contains("FAIL") {
            return .error
        }
        if upper.contains("CANCEL") || upper.contains("ABORT") || upper.contains("STOP") {
            return .cancelled
        }
        if upper.contains("DONE") || upper.contains("COMPLETE") || upper.contains("FINISH") {
            return .done
        }
        // Maps `CASCADE_RUN_STATUS_IDLE` and `UNSPECIFIED` cleanly to `.unspecified` (`IDLE`)
        return .unspecified
    }
}

/// Maps to `exa.cortex_pb.CortexStepType` (binary field 1 on `gemini_coder.Step`).
public enum CortexStepType: Int, Codable, Sendable, CaseIterable {
    case unspecified = 0
    case codeAction = 5
    case viewFile = 8
    case listDirectory = 9
    case userInput = 14
    case plannerResponse = 15
    case generateImage = 17
    case runCommand = 21
    case checkpoint = 23
    case commandStatus = 28
    case readUrlContent = 31
    case viewContentChunk = 32
    case search = 33
    case workspaceApi = 47
    case taskBoundary = 81
    case notifyUser = 82
    case codeAcknowledgement = 83
    case browserSubagent = 85
    case ephemeralMessage = 90
    case conversationHistory = 98
    case knowledgeArtifacts = 99
    case sendCommandInput = 100

    public var jsonName: String {
        switch self {
        case .unspecified: return "CORTEX_STEP_TYPE_UNSPECIFIED"
        case .codeAction: return "CORTEX_STEP_TYPE_CODE_ACTION"
        case .viewFile: return "CORTEX_STEP_TYPE_VIEW_FILE"
        case .listDirectory: return "CORTEX_STEP_TYPE_LIST_DIRECTORY"
        case .userInput: return "CORTEX_STEP_TYPE_USER_INPUT"
        case .plannerResponse: return "CORTEX_STEP_TYPE_PLANNER_RESPONSE"
        case .generateImage: return "CORTEX_STEP_TYPE_GENERATE_IMAGE"
        case .runCommand: return "CORTEX_STEP_TYPE_RUN_COMMAND"
        case .checkpoint: return "CORTEX_STEP_TYPE_CHECKPOINT"
        case .commandStatus: return "CORTEX_STEP_TYPE_COMMAND_STATUS"
        case .readUrlContent: return "CORTEX_STEP_TYPE_READ_URL_CONTENT"
        case .viewContentChunk: return "CORTEX_STEP_TYPE_VIEW_CONTENT_CHUNK"
        case .search: return "CORTEX_STEP_TYPE_SEARCH"
        case .workspaceApi: return "CORTEX_STEP_TYPE_WORKSPACE_API"
        case .taskBoundary: return "CORTEX_STEP_TYPE_TASK_BOUNDARY"
        case .notifyUser: return "CORTEX_STEP_TYPE_NOTIFY_USER"
        case .codeAcknowledgement: return "CORTEX_STEP_TYPE_CODE_ACKNOWLEDGEMENT"
        case .browserSubagent: return "CORTEX_STEP_TYPE_BROWSER_SUBAGENT"
        case .ephemeralMessage: return "CORTEX_STEP_TYPE_EPHEMERAL_MESSAGE"
        case .conversationHistory: return "CORTEX_STEP_TYPE_CONVERSATION_HISTORY"
        case .knowledgeArtifacts: return "CORTEX_STEP_TYPE_KNOWLEDGE_ARTIFACTS"
        case .sendCommandInput: return "CORTEX_STEP_TYPE_SEND_COMMAND_INPUT"
        }
    }

    /// True if this step represents a file read, directory scan, search, or file edit that can be
    /// grouped into a collapsible File Evidence card when consecutive.
    public var isGroupableEvidenceStep: Bool {
        switch self {
        case .codeAction, .viewFile, .listDirectory, .search, .viewContentChunk:
            return true
        default:
            return false
        }
    }
}

// MARK: - 7-Segment Task Progress & Checklist (UE07, UE13)

/// Status of an individual checklist item inside a `TaskBoundaryPayload` (`UE07`).
public enum TaskChecklistStatus: String, Codable, Sendable, CaseIterable {
    case done
    case inProgress
    case waiting
    case pending
}

/// Checklist row rendered beneath the segmented progress bar in `CascadeChatViewController` (`UE07`).
public struct TaskChecklistItem: Codable, Sendable, Equatable, Identifiable {
    public typealias Status = TaskChecklistStatus

    public var id: String
    public var title: String
    public var status: TaskChecklistStatus
    public var trailingBadge: String?

    public init(
        id: String,
        title: String,
        status: TaskChecklistStatus,
        trailingBadge: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.trailingBadge = trailingBadge
    }
}

/// Segmented task progress card payload (`Task · 4 of 7 done · 2m 41s` in `UE07`).
public struct TaskBoundaryPayload: Codable, Sendable, Equatable {
    public var taskName: String
    public var taskStatus: String
    public var taskSummary: String
    public var completedCount: Int
    public var totalCount: Int
    public var elapsedLabel: String
    public var checklist: [TaskChecklistItem]

    public init(
        taskName: String,
        taskStatus: String,
        taskSummary: String,
        completedCount: Int = 4,
        totalCount: Int = 7,
        elapsedLabel: String = "2m 41s",
        checklist: [TaskChecklistItem] = []
    ) {
        self.taskName = taskName
        self.taskStatus = taskStatus
        self.taskSummary = taskSummary
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.elapsedLabel = elapsedLabel
        self.checklist = checklist
    }

    public var completedItems: Int {
        get { completedCount }
        set { completedCount = newValue }
    }

    public var totalItems: Int {
        get { totalCount }
        set { totalCount = newValue }
    }

    public var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return min(1.0, max(0.0, Double(completedCount) / Double(totalCount)))
    }
}

// MARK: - Step Payloads

public struct PlannerResponsePayload: Codable, Sendable, Equatable {
    public var response: String
    public var thinking: String?
    public var thinkingDurationSeconds: Double?
    public var messageId: String?
    public var referencedFiles: [String]

    public init(
        response: String,
        thinking: String? = nil,
        thinkingDurationSeconds: Double? = nil,
        messageId: String? = nil,
        referencedFiles: [String] = []
    ) {
        self.response = response
        self.thinking = thinking
        self.thinkingDurationSeconds = thinkingDurationSeconds
        self.messageId = messageId
        self.referencedFiles = referencedFiles
    }
}

public struct RunCommandPayload: Codable, Sendable, Equatable {
    public var commandId: String
    public var commandLine: String
    public var proposedCommandLine: String?
    public var cwd: String
    public var exitCode: Int?
    public var outputPreview: String?
    public var durationMs: Int?

    public init(
        commandId: String,
        commandLine: String,
        proposedCommandLine: String? = nil,
        cwd: String,
        exitCode: Int? = nil,
        outputPreview: String? = nil,
        durationMs: Int? = nil
    ) {
        self.commandId = commandId
        self.commandLine = commandLine
        self.proposedCommandLine = proposedCommandLine
        self.cwd = cwd
        self.exitCode = exitCode
        self.outputPreview = outputPreview
        self.durationMs = durationMs
    }
}

public struct CodeActionPayload: Codable, Sendable, Equatable {
    public var targetFileUri: String
    public var description: String
    public var additions: Int
    public var deletions: Int
    public var isArtifactFile: Bool
    public var startLine: Int?
    public var endLine: Int?
    public var diffPreviewLines: [String]

    public init(
        targetFileUri: String,
        description: String,
        additions: Int,
        deletions: Int,
        isArtifactFile: Bool = false,
        startLine: Int? = nil,
        endLine: Int? = nil,
        diffPreviewLines: [String] = []
    ) {
        self.targetFileUri = targetFileUri
        self.description = description
        self.additions = additions
        self.deletions = deletions
        self.isArtifactFile = isArtifactFile
        self.startLine = startLine
        self.endLine = endLine
        self.diffPreviewLines = diffPreviewLines
    }

    public var fileName: String {
        URL(string: targetFileUri)?.lastPathComponent ?? (targetFileUri as NSString).lastPathComponent
    }
}

public struct ViewFilePayload: Codable, Sendable, Equatable {
    public var fileUri: String
    public var startLine: Int
    public var endLine: Int
    public var totalLines: Int

    public init(fileUri: String, startLine: Int = 1, endLine: Int = 120, totalLines: Int = 240) {
        self.fileUri = fileUri
        self.startLine = startLine
        self.endLine = endLine
        self.totalLines = totalLines
    }

    public var fileName: String {
        URL(string: fileUri)?.lastPathComponent ?? (fileUri as NSString).lastPathComponent
    }
}

public struct SearchPayload: Codable, Sendable, Equatable {
    public var query: String
    public var scopeDirectory: String
    public var matchCount: Int

    public init(query: String, scopeDirectory: String, matchCount: Int) {
        self.query = query
        self.scopeDirectory = scopeDirectory
        self.matchCount = matchCount
    }
}

/// Represents a single step in a Cascade trajectory (`gemini_coder.Step`).
public struct CascadeStep: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(cascadeId)-\(stepIndex)" }
    public var cascadeId: String
    public var stepIndex: Int
    public var type: CortexStepType
    public var status: CortexStepStatus
    public var createdAt: Date
    public var userInput: String?
    public var attachedMentions: [String]
    public var isQueuedInOutbox: Bool
    public var plannerResponse: PlannerResponsePayload?
    public var taskBoundary: TaskBoundaryPayload?
    public var runCommand: RunCommandPayload?
    public var codeAction: CodeActionPayload?
    public var viewFile: ViewFilePayload?
    public var search: SearchPayload?
    public var requestedInteraction: RequestedInteraction?

    public init(
        cascadeId: String,
        stepIndex: Int,
        type: CortexStepType,
        status: CortexStepStatus,
        createdAt: Date = Date(),
        userInput: String? = nil,
        attachedMentions: [String] = [],
        isQueuedInOutbox: Bool = false,
        plannerResponse: PlannerResponsePayload? = nil,
        taskBoundary: TaskBoundaryPayload? = nil,
        runCommand: RunCommandPayload? = nil,
        codeAction: CodeActionPayload? = nil,
        viewFile: ViewFilePayload? = nil,
        search: SearchPayload? = nil,
        requestedInteraction: RequestedInteraction? = nil
    ) {
        self.cascadeId = cascadeId
        self.stepIndex = stepIndex
        self.type = type
        self.status = status
        self.createdAt = createdAt
        self.userInput = userInput
        self.attachedMentions = attachedMentions
        self.isQueuedInOutbox = isQueuedInOutbox
        self.plannerResponse = plannerResponse
        self.taskBoundary = taskBoundary
        self.runCommand = runCommand
        self.codeAction = codeAction
        self.viewFile = viewFile
        self.search = search
        self.requestedInteraction = requestedInteraction
    }

    /// Returns true if this step carries user-visible chat, tool evidence, task progress, or approval UI.
    /// Filters out internal Desktop housekeeping steps (`CHECKPOINT`, `EPHEMERAL_MESSAGE`, empty tool-call wrappers).
    public var hasRenderableChatContent: Bool {
        if status == .waiting || requestedInteraction != nil {
            return true
        }
        switch type {
        case .userInput:
            let hasText = !(userInput ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasText || !attachedMentions.isEmpty
        case .plannerResponse, .notifyUser:
            let hasResponse = !(plannerResponse?.response ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasThinking = !(plannerResponse?.thinking ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasResponse || hasThinking
        case .taskBoundary:
            return taskBoundary != nil
        case .runCommand:
            return runCommand != nil
        case .codeAction:
            return codeAction != nil
        case .viewFile, .viewContentChunk:
            return viewFile != nil
        case .search, .listDirectory:
            return search != nil || viewFile != nil
        default:
            let hasResponse = !(plannerResponse?.response ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasResponse
        }
    }
}

/// Groups consecutive file reads, searches, and edits into a single collapsible evidence card
/// while keeping user inputs, planner responses, terminal commands, and waiting gates standalone.
public enum CascadeDisplayItem: Identifiable, Sendable, Equatable {
    case single(CascadeStep)
    case evidenceGroup(id: String, steps: [CascadeStep])

    public var id: String {
        switch self {
        case .single(let step):
            return step.id
        case .evidenceGroup(let groupId, _):
            return groupId
        }
    }

    public static func buildDisplayItems(from steps: [CascadeStep]) -> [CascadeDisplayItem] {
        var result: [CascadeDisplayItem] = []
        var buffer: [CascadeStep] = []

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            if buffer.count == 1, let only = buffer.first, only.type == .codeAction {
                result.append(.single(only))
            } else {
                let firstIdx = buffer.first?.stepIndex ?? 0
                let lastIdx = buffer.last?.stepIndex ?? 0
                let cid = buffer.first?.cascadeId ?? "cas"
                result.append(.evidenceGroup(id: "\(cid)-group-\(firstIdx)-\(lastIdx)", steps: buffer))
            }
            buffer.removeAll()
        }

        for step in steps where step.hasRenderableChatContent {
            if step.type == .taskBoundary {
                flushBuffer()
                result.append(.single(step))
            } else if step.type.isGroupableEvidenceStep && step.status != .waiting {
                buffer.append(step)
            } else {
                flushBuffer()
                result.append(.single(step))
            }
        }
        flushBuffer()
        return result
    }
}

/// Summary item emitted by `JetboxSubscribeToSummaries` and `GetAllCascadeTrajectories` (`UE01`, `UE03`, `UE04`, `UE13`).
public struct CascadeSummary: Codable, Sendable, Equatable, Identifiable {
    public var id: String { cascadeId }
    public var cascadeId: String
    public var title: String
    public var projectSlug: String
    public var workspaceUri: String
    public var branchName: String
    public var status: CortexStepStatus
    public var stepCount: Int
    public var currentStepIndex: Int
    public var totalSteps: Int
    public var updatedAt: Date
    public var relativeTimeLabel: String
    public var statusSubtitle: String
    public var isPinned: Bool
    public var isArchived: Bool
    public var isUnread: Bool
    public var modelLabel: String
    public var pendingInteractionTitle: String?
    public var lastMessagePreview: String?
    public var totalAdditions: Int
    public var totalDeletions: Int
    public var isCloud: Bool

    public init(
        cascadeId: String,
        title: String,
        projectSlug: String = "ledger-svc",
        workspaceUri: String,
        branchName: String = "main",
        status: CortexStepStatus,
        stepCount: Int,
        currentStepIndex: Int = 1,
        totalSteps: Int = 7,
        updatedAt: Date = Date(),
        relativeTimeLabel: String = "now",
        statusSubtitle: String = "",
        isPinned: Bool = false,
        isArchived: Bool = false,
        isUnread: Bool = false,
        modelLabel: String = "Gemini 3.1 Pro",
        pendingInteractionTitle: String? = nil,
        lastMessagePreview: String? = nil,
        totalAdditions: Int = 0,
        totalDeletions: Int = 0,
        isCloud: Bool? = nil
    ) {
        self.cascadeId = cascadeId
        self.title = title
        self.projectSlug = projectSlug
        self.workspaceUri = workspaceUri
        self.branchName = branchName
        self.status = status
        self.stepCount = stepCount
        self.currentStepIndex = currentStepIndex
        self.totalSteps = totalSteps
        self.updatedAt = updatedAt
        self.relativeTimeLabel = relativeTimeLabel
        self.statusSubtitle = statusSubtitle.isEmpty ? status.displayBadgeText : statusSubtitle
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.isUnread = isUnread
        self.modelLabel = modelLabel
        self.pendingInteractionTitle = pendingInteractionTitle
        self.lastMessagePreview = lastMessagePreview
        self.totalAdditions = totalAdditions
        self.totalDeletions = totalDeletions
        self.isCloud = isCloud ?? AntigravityCloudDetector.isCloudWorkspaceURI(workspaceUri, cascadeId: cascadeId)
    }

    private enum CodingKeys: String, CodingKey {
        case cascadeId
        case title
        case projectSlug
        case workspaceUri
        case branchName
        case status
        case stepCount
        case currentStepIndex
        case totalSteps
        case updatedAt
        case relativeTimeLabel
        case statusSubtitle
        case isPinned
        case isArchived
        case isUnread
        case modelLabel
        case pendingInteractionTitle
        case lastMessagePreview
        case totalAdditions
        case totalDeletions
        case isCloud
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cid = try container.decode(String.self, forKey: .cascadeId)
        let wsUri = try container.decode(String.self, forKey: .workspaceUri)
        let decodedStatus = try container.decode(CortexStepStatus.self, forKey: .status)
        let rawSub = try container.decodeIfPresent(String.self, forKey: .statusSubtitle) ?? ""

        self.cascadeId = cid
        self.title = try container.decode(String.self, forKey: .title)
        self.projectSlug = try container.decodeIfPresent(String.self, forKey: .projectSlug) ?? "ledger-svc"
        self.workspaceUri = wsUri
        self.branchName = try container.decodeIfPresent(String.self, forKey: .branchName) ?? "main"
        self.status = decodedStatus
        self.stepCount = try container.decodeIfPresent(Int.self, forKey: .stepCount) ?? 0
        self.currentStepIndex = try container.decodeIfPresent(Int.self, forKey: .currentStepIndex) ?? 1
        self.totalSteps = try container.decodeIfPresent(Int.self, forKey: .totalSteps) ?? 7
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.relativeTimeLabel = try container.decodeIfPresent(String.self, forKey: .relativeTimeLabel) ?? "now"
        self.statusSubtitle = rawSub.isEmpty ? decodedStatus.displayBadgeText : rawSub
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        self.isUnread = try container.decodeIfPresent(Bool.self, forKey: .isUnread) ?? false
        self.modelLabel = try container.decodeIfPresent(String.self, forKey: .modelLabel) ?? "Gemini 3.1 Pro"
        self.pendingInteractionTitle = try container.decodeIfPresent(String.self, forKey: .pendingInteractionTitle)
        self.lastMessagePreview = try container.decodeIfPresent(String.self, forKey: .lastMessagePreview)
        self.totalAdditions = try container.decodeIfPresent(Int.self, forKey: .totalAdditions) ?? 0
        self.totalDeletions = try container.decodeIfPresent(Int.self, forKey: .totalDeletions) ?? 0
        self.isCloud = try container.decodeIfPresent(Bool.self, forKey: .isCloud)
            ?? AntigravityCloudDetector.isCloudWorkspaceURI(wsUri, cascadeId: cid)
    }
}
