import Foundation

/// Builds authoritative `HandleCascadeUserInteraction` request payloads matching
/// the exact oneof member declared in `step.requestedInteraction`.
///
/// As verified against Antigravity's LanguageServer (`exa.cortex_pb.CascadeUserInteraction`),
/// answering with any member other than the one declared in `requestedInteraction` is
/// silently dropped by the server.
public enum InteractionBuilder {

    private static let readOnlyVerbs: Set<String> = [
        "read", "list", "view", "search", "stat", "glob", "grep", "find", "fetch", "get"
    ]

    public static func buildPayload(
        step: CascadeStep,
        decision: InteractionDecision
    ) -> [String: Any]? {
        guard let requested = step.requestedInteraction else {
            return nil
        }

        var payload: [String: Any] = [
            "trajectoryId": step.cascadeId,
            "stepIndex": step.stepIndex
        ]

        if decision == .reject {
            switch requested.kind {
            case .permission:
                payload["permission"] = ["allow": false]
            case .filePermission:
                payload["filePermission"] = ["allow": false]
            case .runCommand:
                payload["runCommand"] = ["confirm": false]
            case .deploy:
                payload["deploy"] = ["cancel": true]
            default:
                payload[requested.kind.rawValue] = ["confirm": false]
            }
            return payload
        }

        switch requested.kind {
        case .permission:
            guard let spec = requested.permission else { return nil }
            if decision == .alwaysAllowInTurn && spec.persistSuggestionType != .blocked {
                let patternTarget = spec.suggestedPersistPattern ?? spec.target
                let grantPattern = "\(spec.action)(\(patternTarget))"
                payload["permission"] = [
                    "allow": true,
                    "turnGrants": [
                        "allow": [grantPattern],
                        "deny": [String]()
                    ]
                ]
            } else {
                payload["permission"] = ["allow": true]
            }

        case .filePermission:
            let uri = requested.filePermission?.absolutePathUri ?? ""
            var fp: [String: Any] = [
                "allow": true,
                "scope": decision == .alwaysAllowInTurn ? "PERMISSION_SCOPE_TURN" : "PERMISSION_SCOPE_ONCE"
            ]
            if !uri.isEmpty {
                fp["absolutePathUri"] = uri
            }
            payload["filePermission"] = fp

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
            payload["runCommand"] = [
                "confirm": true,
                "proposedCommandLine": proposed,
                "submittedCommandLine": submitted
            ]

        case .askQuestion, .elicitation:
            guard case .answerQuestion(let selectedOptions, let customWriteIn) = decision else {
                return nil
            }
            var qa: [String: Any] = ["selectedOptions": selectedOptions]
            if let custom = customWriteIn, !custom.isEmpty {
                qa["customResponse"] = custom
            }
            payload["askQuestion"] = qa

        case .deploy:
            payload["deploy"] = ["cancel": false]

        default:
            payload[requested.kind.rawValue] = ["confirm": true]
        }

        return payload
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
