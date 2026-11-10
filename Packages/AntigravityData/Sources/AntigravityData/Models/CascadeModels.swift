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

    public static func from(jsonName: String) -> CortexStepStatus {
        for status in Self.allCases where status.jsonName == jsonName {
            return status
        }
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
}

public struct TaskBoundaryPayload: Codable, Sendable, Equatable {
    public var taskName: String
    public var taskStatus: String
    public var taskSummary: String

    public init(taskName: String, taskStatus: String, taskSummary: String) {
        self.taskName = taskName
        self.taskStatus = taskStatus
        self.taskSummary = taskSummary
    }
}

public struct PlannerResponsePayload: Codable, Sendable, Equatable {
    public var response: String
    public var thinking: String?
    public var thinkingDurationSeconds: Double?
    public var messageId: String?

    public init(
        response: String,
        thinking: String? = nil,
        thinkingDurationSeconds: Double? = nil,
        messageId: String? = nil
    ) {
        self.response = response
        self.thinking = thinking
        self.thinkingDurationSeconds = thinkingDurationSeconds
        self.messageId = messageId
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

    public init(
        targetFileUri: String,
        description: String,
        additions: Int,
        deletions: Int,
        isArtifactFile: Bool = false
    ) {
        self.targetFileUri = targetFileUri
        self.description = description
        self.additions = additions
        self.deletions = deletions
        self.isArtifactFile = isArtifactFile
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
    public var plannerResponse: PlannerResponsePayload?
    public var taskBoundary: TaskBoundaryPayload?
    public var runCommand: RunCommandPayload?
    public var codeAction: CodeActionPayload?
    public var requestedInteraction: RequestedInteraction?

    public init(
        cascadeId: String,
        stepIndex: Int,
        type: CortexStepType,
        status: CortexStepStatus,
        createdAt: Date = Date(),
        userInput: String? = nil,
        plannerResponse: PlannerResponsePayload? = nil,
        taskBoundary: TaskBoundaryPayload? = nil,
        runCommand: RunCommandPayload? = nil,
        codeAction: CodeActionPayload? = nil,
        requestedInteraction: RequestedInteraction? = nil
    ) {
        self.cascadeId = cascadeId
        self.stepIndex = stepIndex
        self.type = type
        self.status = status
        self.createdAt = createdAt
        self.userInput = userInput
        self.plannerResponse = plannerResponse
        self.taskBoundary = taskBoundary
        self.runCommand = runCommand
        self.codeAction = codeAction
        self.requestedInteraction = requestedInteraction
    }
}

/// Summary item emitted by `JetboxSubscribeToSummaries`.
public struct CascadeSummary: Codable, Sendable, Equatable, Identifiable {
    public var id: String { cascadeId }
    public var cascadeId: String
    public var title: String
    public var workspaceUri: String
    public var branchName: String
    public var status: CortexStepStatus
    public var stepCount: Int
    public var updatedAt: Date
    public var isPinned: Bool
    public var isArchived: Bool
    public var pendingInteractionTitle: String?

    public init(
        cascadeId: String,
        title: String,
        workspaceUri: String,
        branchName: String,
        status: CortexStepStatus,
        stepCount: Int,
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        isArchived: Bool = false,
        pendingInteractionTitle: String? = nil
    ) {
        self.cascadeId = cascadeId
        self.title = title
        self.workspaceUri = workspaceUri
        self.branchName = branchName
        self.status = status
        self.stepCount = stepCount
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.pendingInteractionTitle = pendingInteractionTitle
    }
}
