import Foundation

/// Maps to `exa.cortex_pb.RequestedInteraction` (field 56 on `gemini_coder.Step`).
/// Authoritative specification of what interaction member the LanguageServer expects
/// in `HandleCascadeUserInteraction`.
public struct RequestedInteraction: Codable, Sendable, Equatable {
    public enum MemberKind: String, Codable, Sendable {
        case deploy
        case runCommand
        case openBrowserUrl
        case runExtensionCode
        case executeBrowserJavascript
        case captureBrowserScreenshot
        case clickBrowserPixel
        case browserAction
        case openBrowserSetup
        case confirmBrowserSetup
        case sendCommandInput
        case readUrlContent
        case mcp
        case filePermission
        case elicitation
        case permission
        case askQuestion
        case approvalInteraction
    }

    public var kind: MemberKind
    public var permission: PermissionInteractionSpec?
    public var filePermission: FilePermissionInteractionSpec?
    public var runCommand: RunCommandInteractionSpec?
    public var askQuestion: AskQuestionInteractionSpec?
    public var mcpServerName: String?
    public var mcpToolName: String?

    public init(
        kind: MemberKind,
        permission: PermissionInteractionSpec? = nil,
        filePermission: FilePermissionInteractionSpec? = nil,
        runCommand: RunCommandInteractionSpec? = nil,
        askQuestion: AskQuestionInteractionSpec? = nil,
        mcpServerName: String? = nil,
        mcpToolName: String? = nil
    ) {
        self.kind = kind
        self.permission = permission
        self.filePermission = filePermission
        self.runCommand = runCommand
        self.askQuestion = askQuestion
        self.mcpServerName = mcpServerName
        self.mcpToolName = mcpToolName
    }
}

public enum PersistSuggestionType: Int, Codable, Sendable {
    case unspecified = 0
    case suggested = 1
    case blocked = 2
}

/// Outside-of-project or tool permission gate (`PermissionInteractionSpec` field 21).
public struct PermissionInteractionSpec: Codable, Sendable, Equatable {
    public var action: String
    public var target: String
    public var suggestedPersistPattern: String?
    public var persistSuggestionType: PersistSuggestionType
    public var reason: String?

    public init(
        action: String,
        target: String,
        suggestedPersistPattern: String? = nil,
        persistSuggestionType: PersistSuggestionType = .suggested,
        reason: String? = nil
    ) {
        self.action = action
        self.target = target
        self.suggestedPersistPattern = suggestedPersistPattern
        self.persistSuggestionType = persistSuggestionType
        self.reason = reason
    }
}

/// File access gate (`FilePermissionInteractionSpec` field 19).
public struct FilePermissionInteractionSpec: Codable, Sendable, Equatable {
    public var absolutePathUri: String
    public var isDirectory: Bool
    public var blockReason: String?

    public init(absolutePathUri: String, isDirectory: Bool = false, blockReason: String? = nil) {
        self.absolutePathUri = absolutePathUri
        self.isDirectory = isDirectory
        self.blockReason = blockReason
    }
}

/// Command approval gate (`RunCommandInteractionSpec` field 3).
public struct RunCommandInteractionSpec: Codable, Sendable, Equatable {
    public var proposedCommandLine: String
    public var cwd: String
    public var isDaemon: Bool

    public init(proposedCommandLine: String, cwd: String, isDaemon: Bool = false) {
        self.proposedCommandLine = proposedCommandLine
        self.cwd = cwd
        self.isDaemon = isDaemon
    }
}

/// Interactive multiple-choice question (`AskQuestionInteractionSpec` field 22).
public struct AskQuestionInteractionSpec: Codable, Sendable, Equatable {
    public var question: String
    public var options: [String]
    public var isMultiSelect: Bool

    public init(question: String, options: [String], isMultiSelect: Bool = false) {
        self.question = question
        self.options = options
        self.isMultiSelect = isMultiSelect
    }
}

/// User decision mode when answering a permission gate.
public enum InteractionDecision: Sendable, Equatable {
    case allowOnce
    case alwaysAllowInTurn
    case allowWithModifiedCommand(String)
    case answerQuestion(selectedOptions: [String], customWriteIn: String?)
    case reject
}
