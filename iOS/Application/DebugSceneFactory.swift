import Foundation
import SwiftUI
import AntigravityData

/// Enumerates all 8 deterministic ESDD verification scenes declared in `specs/esdd-ir.json`.
public enum ESDDVerifySceneCase: String, CaseIterable, Sendable {
    case pairingQR = "pairing-qr"
    case workspaceHome = "workspace-home"
    case cascadeStreaming = "cascade-streaming"
    case permissionGate = "permission-gate"
    case askQuestion = "ask-question"
    case artifactPlan = "artifact-plan"
    case turnDiff = "turn-diff"
    case liveActivity = "live-activity"

    public var stateId: String {
        switch self {
        case .pairingQR:        return "S01_PAIRING_QR"
        case .workspaceHome:    return "S02_WORKSPACE_HOME"
        case .cascadeStreaming: return "S03_CASCADE_STREAMING"
        case .permissionGate:   return "S04_PERMISSION_GATE"
        case .askQuestion:      return "S05_ASK_QUESTION_MODAL"
        case .artifactPlan:     return "S06_ARTIFACT_PLAN_REVIEW"
        case .turnDiff:         return "S07_TURN_DIFF_INSPECTOR"
        case .liveActivity:     return "S08_LIVE_ACTIVITY_LOCKSCREEN"
        }
    }
}

/// Resolves `antigravity://verify/<case>` deep links into deterministic offline scenes
/// without requiring live Google OAuth credentials or external network access.
public enum DebugSceneFactory {
    public static func resolveDeepLink(_ url: URL) -> ESDDVerifySceneCase? {
        guard url.scheme == "antigravity", url.host == "verify" else {
            return nil
        }
        let slug = url.lastPathComponent
        return ESDDVerifySceneCase(rawValue: slug)
    }
}
