import Foundation

/// Policy helper for mobile Safe Auto-Accept of read-only workspace operations.
public enum SafeAutoAcceptPolicy: Sendable {
    private static let safeGitSubcommands: Set<String> = [
        "status", "diff", "log", "branch", "show", "rev-parse"
    ]

    private static let safeExecutables: Set<String> = [
        "ls", "pwd", "cat", "head", "tail", "wc", "which", "rg", "grep", "find"
    ]

    private static let shellChainTokens: [String] = [
        "&&", "||", ";", "|", ">", "<", "$(", "`"
    ]

    /// Returns `true` only for deterministic read-only commands without shell chaining or redirection.
    public static func isSafeReadOnlyCommand(_ commandLine: String) -> Bool {
        let trimmed = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        for token in shellChainTokens where trimmed.contains(token) {
            return false
        }
        let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let binary = parts.first else { return false }
        if binary == "git" {
            guard parts.count >= 2 else { return false }
            return safeGitSubcommands.contains(parts[1])
        }
        if binary == "find" && (parts.contains("-delete") || parts.contains("-exec")) {
            return false
        }
        return safeExecutables.contains(binary)
    }

    public static func canAutoAccept(step: CascadeStep, allowedWorkspaceRoots: [String]) -> Bool {
        InteractionBuilder.canSafeAutoAccept(step: step, allowedWorkspaceRoots: allowedWorkspaceRoots)
    }
}

/// Builds authoritative `HandleCascadeUserInteraction` request payloads matching
/// the exact oneof member declared in `step.requestedInteraction`.
///
/// As verified against Antigravity's LanguageServer (`exa.cortex_pb.CascadeUserInteraction`),
/// answering with any member other than the one declared in `requestedInteraction` is
/// silently dropped by the server.
public enum InteractionBuilder: Sendable {

    private static let readOnlyVerbs: Set<String> = [
        "read", "list", "view", "search", "stat", "glob", "grep", "find", "fetch", "get"
    ]

    public static func buildPayload(
        step: CascadeStep,
        decision: InteractionDecision,
        workspaceUri: String? = nil
    ) -> CascadeUserInteractionPayload? {
        guard let requested = step.requestedInteraction else {
            return nil
        }

        if decision == .reject {
            switch requested.kind {
            case .permission:
                return CascadeUserInteractionPayload(
                    cascadeId: step.cascadeId,
                    stepIndex: step.stepIndex,
                    kind: .permission,
                    workspaceUri: workspaceUri,
                    permission: .init(allow: false)
                )
            case .filePermission:
                return CascadeUserInteractionPayload(
                    cascadeId: step.cascadeId,
                    stepIndex: step.stepIndex,
                    kind: .filePermission,
                    workspaceUri: workspaceUri,
                    filePermission: .init(allow: false, absolutePathUri: requested.filePermission?.absolutePathUri)
                )
            case .runCommand:
                let proposed = requested.runCommand?.proposedCommandLine
                    ?? step.runCommand?.proposedCommandLine
                    ?? step.runCommand?.commandLine
                    ?? ""
                return CascadeUserInteractionPayload(
                    cascadeId: step.cascadeId,
                    stepIndex: step.stepIndex,
                    kind: .runCommand,
                    workspaceUri: workspaceUri,
                    runCommand: .init(
                        confirm: false,
                        proposedCommandLine: proposed,
                        submittedCommandLine: proposed,
                        faceIdVerified: false
                    )
                )
            default:
                return CascadeUserInteractionPayload(
                    cascadeId: step.cascadeId,
                    stepIndex: step.stepIndex,
                    kind: requested.kind,
                    workspaceUri: workspaceUri,
                    genericConfirm: false
                )
            }
        }

        switch requested.kind {
        case .permission:
            guard let spec = requested.permission else { return nil }
            var grants: [String] = []
            if decision == .alwaysAllowInTurn && spec.persistSuggestionType != .blocked {
                let patternTarget = spec.suggestedPersistPattern ?? spec.target
                grants = ["\(spec.action)(\(patternTarget))"]
            }
            return CascadeUserInteractionPayload(
                cascadeId: step.cascadeId,
                stepIndex: step.stepIndex,
                kind: .permission,
                workspaceUri: workspaceUri,
                permission: .init(allow: true, grantPatterns: grants)
            )

        case .filePermission:
            let uri = requested.filePermission?.absolutePathUri
            let scope = decision == .alwaysAllowInTurn ? "PERMISSION_SCOPE_TURN" : "PERMISSION_SCOPE_ONCE"
            return CascadeUserInteractionPayload(
                cascadeId: step.cascadeId,
                stepIndex: step.stepIndex,
                kind: .filePermission,
                workspaceUri: workspaceUri,
                filePermission: .init(allow: true, scope: scope, absolutePathUri: uri)
            )

        case .runCommand:
            let proposed = requested.runCommand?.proposedCommandLine
                ?? step.runCommand?.proposedCommandLine
                ?? step.runCommand?.commandLine
                ?? ""
            let submitted: String
            if case .allowWithModifiedCommand(let custom) = decision {
                submitted = custom
            } else {
                submitted = proposed
            }
            let faceId = (decision == .allowWithFaceID)
            return CascadeUserInteractionPayload(
                cascadeId: step.cascadeId,
                stepIndex: step.stepIndex,
                kind: .runCommand,
                workspaceUri: workspaceUri,
                runCommand: .init(
                    confirm: true,
                    proposedCommandLine: proposed,
                    submittedCommandLine: submitted,
                    faceIdVerified: faceId
                )
            )

        case .askQuestion, .elicitation:
            guard case .answerQuestion(let selectedOptions, let customWriteIn) = decision else {
                return nil
            }
            return CascadeUserInteractionPayload(
                cascadeId: step.cascadeId,
                stepIndex: step.stepIndex,
                kind: requested.kind,
                workspaceUri: workspaceUri,
                askQuestion: .init(
                    selectedOptions: selectedOptions,
                    customResponse: (customWriteIn?.isEmpty == false) ? customWriteIn : nil
                )
            )

        default:
            return CascadeUserInteractionPayload(
                cascadeId: step.cascadeId,
                stepIndex: step.stepIndex,
                kind: requested.kind,
                workspaceUri: workspaceUri,
                genericConfirm: true
            )
        }
    }

    /// Evaluates whether a `WAITING` step is eligible for Safe Auto-Accept on mobile.
    /// Read-only permissions and workspace-scoped file reads auto-resolve; commands and
    /// `ask_question` always require explicit user action.
    public static func canSafeAutoAccept(step: CascadeStep, allowedWorkspaceRoots: [String]) -> Bool {
        guard step.status == .waiting, let requested = step.requestedInteraction else {
            return false
        }
        switch requested.kind {
        case .permission:
            guard let action = requested.permission?.action.lowercased() else { return false }
            return readOnlyVerbs.contains(action)
        case .filePermission:
            guard let uri = requested.filePermission?.absolutePathUri else { return false }
            return allowedWorkspaceRoots.contains { uri.hasPrefix($0) }
        case .askQuestion, .elicitation, .runCommand, .sendCommandInput:
            return false
        default:
            return false
        }
    }
}
