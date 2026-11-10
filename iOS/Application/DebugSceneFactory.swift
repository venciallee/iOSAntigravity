import Foundation
import SwiftUI
import AntigravityData

/// Extends `AntigravityData.ESDDVerifySceneCase` with ESDD state & claim metadata.
public extension ESDDVerifySceneCase {
    var stateId: String {
        rawValue
    }

    var claimId: String {
        switch self {
        case .agentsHome:         return "CLAIM-01"
        case .displayOptions:     return "CLAIM-02"
        case .contextMenuPin:     return "CLAIM-03"
        case .projectDetail:      return "CLAIM-04"
        case .createProject:      return "CLAIM-05"
        case .automations:        return "CLAIM-06"
        case .chatAndComposer:    return "CLAIM-07"
        case .addContext:         return "CLAIM-08"
        case .modelAndMode:       return "CLAIM-09"
        case .structuredQuestion: return "CLAIM-10"
        case .planReview:         return "CLAIM-11"
        case .turnDiffReview:     return "CLAIM-12"
        case .liveActivitySpec:   return "CLAIM-13"
        }
    }
}

/// Resolves `antigravity://verify/<case>` deep links and `--ui-verify` CLI arguments
/// into deterministic offline scenes without requiring external network credentials.
public enum DebugSceneFactory {
    public static func resolveDeepLink(_ url: URL) -> ESDDVerifySceneCase? {
        guard url.scheme == "antigravity", url.host == "verify" else {
            return nil
        }
        let slug = url.lastPathComponent
        return resolveIdentifier(slug)
    }

    public static func launchVerifyCase(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ESDDVerifySceneCase? {
        for (index, arg) in arguments.enumerated() {
            if arg == "--ui-verify", index + 1 < arguments.count {
                if let resolved = resolveIdentifier(arguments[index + 1]) {
                    return resolved
                }
            } else if arg.hasPrefix("--ui-verify=") {
                let value = String(arg.dropFirst("--ui-verify=".count))
                if let resolved = resolveIdentifier(value) {
                    return resolved
                }
            }
        }
        return nil
    }

    public static func resolveIdentifier(_ rawSlug: String) -> ESDDVerifySceneCase? {
        let trimmed = rawSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = ESDDVerifySceneCase(rawValue: trimmed) {
            return exact
        }
        if let upper = ESDDVerifySceneCase(rawValue: trimmed.uppercased()) {
            return upper
        }

        switch trimmed.lowercased() {
        case "ue01", "agents-home", "workspace-home":
            return .agentsHome
        case "ue02", "display-options":
            return .displayOptions
        case "ue03", "context-menu-pin", "context-menu":
            return .contextMenuPin
        case "ue04", "project-detail":
            return .projectDetail
        case "ue05", "create-project", "new-project":
            return .createProject
        case "ue06", "automations":
            return .automations
        case "ue07", "chat-and-composer", "cascade-streaming":
            return .chatAndComposer
        case "ue08", "add-context":
            return .addContext
        case "ue09", "model-and-mode":
            return .modelAndMode
        case "ue10", "structured-question", "ask-question":
            return .structuredQuestion
        case "ue11", "plan-review", "artifact-plan":
            return .planReview
        case "ue12", "turn-diff-review", "turn-diff":
            return .turnDiffReview
        case "ue13", "live-activity-spec", "live-activity":
            return .liveActivitySpec
        default:
            return nil
        }
    }
}
