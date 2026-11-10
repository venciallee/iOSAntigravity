import Foundation
import Observation

/// Central `@Observable` state coordinator for `iOSAntigravity`.
/// Drives UIKit and SwiftUI controllers from local SQLite projections and live Connect-RPC streams,
/// and supports deterministic offline ESDD fixture injection for `--ui-verify`.
@MainActor
@Observable
public final class AntigravitySessionStore {
    public var activeHost: RemoteHostInstance
    public var workspaces: [WorkspaceInfo]
    public var selectedWorkspaceUri: String
    public var summaries: [CascadeSummary]
    public var activeCascadeId: String
    public var activeSteps: [CascadeStep]
    public var activeArtifacts: [ArtifactSnapshot]
    public var activeTurnDiffs: [FilePatchDiff]
    public var selectedModelConfig: CascadeModelConfig
    public var safeAutoAcceptEnabled: Bool

    public init(
        activeHost: RemoteHostInstance,
        workspaces: [WorkspaceInfo] = [],
        selectedWorkspaceUri: String = "",
        summaries: [CascadeSummary] = [],
        activeCascadeId: String = "",
        activeSteps: [CascadeStep] = [],
        activeArtifacts: [ArtifactSnapshot] = [],
        activeTurnDiffs: [FilePatchDiff] = [],
        selectedModelConfig: CascadeModelConfig = CascadeModelConfig(
            modelId: "claude-sonnet-4-5",
            displayName: "Claude Sonnet 4.5",
            effort: .high,
            mode: .planning
        ),
        safeAutoAcceptEnabled: Bool = true
    ) {
        self.activeHost = activeHost
        self.workspaces = workspaces
        self.selectedWorkspaceUri = selectedWorkspaceUri
        self.summaries = summaries
        self.activeCascadeId = activeCascadeId
        self.activeSteps = activeSteps
        self.activeArtifacts = activeArtifacts
        self.activeTurnDiffs = activeTurnDiffs
        self.selectedModelConfig = selectedModelConfig
        self.safeAutoAcceptEnabled = safeAutoAcceptEnabled
    }

    /// Deterministic ESDD baseline store matching `specs/esdd-ir.json` and the user's host `lt74xt6l0m-golden-star`.
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
                activeCascadeCount: 2
            ),
            WorkspaceInfo(
                workspaceUri: "file:///home/antigravity/exa-core",
                displayName: "antigravity/exa-core",
                activeBranch: "release/v2.30",
                worktrees: ["release/v2.30"],
                activeCascadeCount: 1
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
                isPinned: true,
                pendingInteractionTitle: "Approve command: python3 verification/esdd-verify.py"
            ),
            CascadeSummary(
                cascadeId: "cas-02-running",
                title: "Audit CoreText 120fps Streaming Cell Layout",
                workspaceUri: "file:///home/antigravity/venciallee/iOSAntigravity",
                branchName: "feat/live-activity",
                status: .inProgress,
                stepCount: 14,
                isPinned: true
            ),
            CascadeSummary(
                cascadeId: "cas-03-done",
                title: "Decode Binary Protobuf Trajectory Steps (>600 ceiling)",
                workspaceUri: "file:///home/antigravity/venciallee/iOSAntigravity",
                branchName: "main",
                status: .done,
                stepCount: 642,
                isPinned: false
            )
        ]

        let steps = [
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 20,
                type: .userInput,
                status: .done,
                userInput: "Implement the Connect-RPC 5-byte envelope parser and run the ESDD verification suite."
            ),
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 21,
                type: .taskBoundary,
                status: .inProgress,
                taskBoundary: TaskBoundaryPayload(
                    taskName: "Phase 2: Connect-RPC Streaming & ESDD Verification",
                    taskStatus: "Running E2E protocol & HIG geometry assertions",
                    taskSummary: "Verified 5-byte Connect framing and binary Protobuf step decoding."
                )
            ),
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 22,
                type: .plannerResponse,
                status: .done,
                plannerResponse: PlannerResponsePayload(
                    response: "I have implemented `ConnectEnvelope.swift` and `ProtobufStepDecoder.swift`, and wired `InteractionBuilder` to match field 56 (`requestedInteraction`). Now executing the ESDD suite.",
                    thinking: "Analyzing exa.language_server_pb.LanguageServerService framing: 1B flags + 4B big-endian uint32 length. Checking RequestedInteraction oneof field numbers (3=runCommand, 19=filePermission, 21=permission, 22=askQuestion).",
                    thinkingDurationSeconds: 3.4
                )
            ),
            CascadeStep(
                cascadeId: "cas-01-waiting",
                stepIndex: 23,
                type: .codeAction,
                status: .done,
                codeAction: CodeActionPayload(
                    targetFileUri: "file:///home/antigravity/venciallee/iOSAntigravity/Packages/AntigravityData/Sources/AntigravityData/Protocol/ConnectEnvelope.swift",
                    description: "Implement 5-byte Connect streaming parser & binary Protobuf decoder",
                    additions: 184,
                    deletions: 22
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
            )
        ]

        return AntigravitySessionStore(
            activeHost: host,
            workspaces: workspaces,
            selectedWorkspaceUri: workspaces[0].workspaceUri,
            summaries: summaries,
            activeCascadeId: "cas-01-waiting",
            activeSteps: steps,
            activeArtifacts: artifacts,
            activeTurnDiffs: diffs
        )
    }
}
