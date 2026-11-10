import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shared ActivityKit payload for Dynamic Island, Lock Screen, and Apple Watch Smart Stack.
public struct AntigravityActivityAttributes: Codable, Sendable, Hashable {
    public struct ContentState: Codable, Sendable, Hashable {
        public var statusRaw: String
        public var currentStepIndex: Int
        public var totalSteps: Int
        public var activeToolAction: String
        public var pendingApprovalCommand: String?
        public var elapsedSeconds: Int

        public init(
            statusRaw: String,
            currentStepIndex: Int,
            totalSteps: Int,
            activeToolAction: String,
            pendingApprovalCommand: String? = nil,
            elapsedSeconds: Int = 0
        ) {
            self.statusRaw = statusRaw
            self.currentStepIndex = currentStepIndex
            self.totalSteps = totalSteps
            self.activeToolAction = activeToolAction
            self.pendingApprovalCommand = pendingApprovalCommand
            self.elapsedSeconds = elapsedSeconds
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
