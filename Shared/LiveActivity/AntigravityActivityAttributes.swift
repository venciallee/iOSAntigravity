import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shared ActivityKit payload for Dynamic Island (`Compact`, `Minimal`, `Expanded`),
/// Lock Screen Multi-Agent Banner, and Apple Watch Smart Stack (`UE13_LIVE_ACTIVITY_SPEC`).
public struct AntigravityActivityAttributes: Codable, Sendable, Hashable {
    public enum Phase: String, Codable, Sendable, Hashable {
        case running
        case waitingApproval
        case completed
    }

    public struct AgentSummaryItem: Codable, Sendable, Hashable, Identifiable {
        public var id: String
        public var title: String
        public var subtitle: String
        public var phase: Phase
        public var trailingLabel: String

        public init(
            id: String,
            title: String,
            subtitle: String,
            phase: Phase,
            trailingLabel: String
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.phase = phase
            self.trailingLabel = trailingLabel
        }
    }

    public struct ContentState: Codable, Sendable, Hashable {
        public var statusRaw: String
        public var currentStepIndex: Int
        public var totalSteps: Int
        public var activeToolAction: String
        public var pendingApprovalCommand: String?
        public var elapsedSeconds: Int
        public var additions: Int
        public var deletions: Int

        public init(
            statusRaw: String,
            currentStepIndex: Int,
            totalSteps: Int,
            activeToolAction: String,
            pendingApprovalCommand: String? = nil,
            elapsedSeconds: Int = 161,
            additions: Int = 128,
            deletions: Int = 14
        ) {
            self.statusRaw = statusRaw
            self.currentStepIndex = currentStepIndex
            self.totalSteps = totalSteps
            self.activeToolAction = activeToolAction
            self.pendingApprovalCommand = pendingApprovalCommand
            self.elapsedSeconds = elapsedSeconds
            self.additions = additions
            self.deletions = deletions
        }

        public var phase: Phase {
            if pendingApprovalCommand != nil || statusRaw.lowercased().contains("wait") {
                return .waitingApproval
            }
            if statusRaw.lowercased().contains("done") || statusRaw.lowercased().contains("complete") {
                return .completed
            }
            return .running
        }

        public var progressFraction: Double {
            guard totalSteps > 0 else { return 0 }
            return min(1.0, max(0.0, Double(currentStepIndex) / Double(totalSteps)))
        }

        public var formattedElapsed: String {
            let mins = elapsedSeconds / 60
            let secs = elapsedSeconds % 60
            return String(format: "%d:%02d", mins, secs)
        }
    }

    public var cascadeId: String
    public var cascadeTitle: String
    public var hostName: String
    public var workspaceName: String
    public var branchName: String

    public init(
        cascadeId: String,
        cascadeTitle: String,
        hostName: String,
        workspaceName: String,
        branchName: String
    ) {
        self.cascadeId = cascadeId
        self.cascadeTitle = cascadeTitle
        self.hostName = hostName
        self.workspaceName = workspaceName
        self.branchName = branchName
    }
}

#if canImport(ActivityKit)
extension AntigravityActivityAttributes: ActivityAttributes {}
#endif
