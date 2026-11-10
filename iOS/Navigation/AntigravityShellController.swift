import SwiftUI
import AntigravityData

/// Adaptive shell container (`AntigravityShellController`) that routes between
/// Pairing, Workspace Home, Cascade Streaming Chat, Artifacts, and Turn Diffs,
/// or directly renders an isolated ESDD verification scene when launched with `--ui-verify`.
public struct AntigravityRootContainerView: View {
    @Bindable public var store: AntigravitySessionStore
    @Binding public var activeVerifyCase: ESDDVerifySceneCase?

    public init(
        store: AntigravitySessionStore,
        activeVerifyCase: Binding<ESDDVerifySceneCase?>
    ) {
        self.store = store
        self._activeVerifyCase = activeVerifyCase
    }

    public var body: some View {
        Group {
            switch activeVerifyCase {
            case .pairingQR:
                RemotePairingViewController(store: store)
            case .workspaceHome:
                WorkspaceHomeViewController(store: store)
            case .cascadeStreaming, .none:
                CascadeChatViewController(store: store)
            case .permissionGate:
                InteractionGateSheetController(store: store, mode: .permissionGate)
            case .askQuestion:
                InteractionGateSheetController(store: store, mode: .askQuestion)
            case .artifactPlan:
                ArtifactReviewViewController(store: store)
            case .turnDiff:
                TurnDiffViewController(store: store)
            case .liveActivity:
                AntigravityLiveActivityView(
                    attributes: AntigravityActivityAttributes(
                        cascadeId: store.activeCascadeId,
                        cascadeTitle: "Implement Native Connect-RPC & Live Activity",
                        hostName: store.activeHost.hostname,
                        workspaceName: "venciallee/iOSAntigravity",
                        branchName: "feat/connect-rpc-client"
                    ),
                    state: AntigravityActivityAttributes.ContentState(
                        statusRaw: "WAITING",
                        currentStepIndex: 24,
                        totalSteps: 28,
                        activeToolAction: "Waiting for approval: esdd-verify.py",
                        pendingApprovalCommand: "python3 verification/esdd-verify.py --suite all",
                        elapsedSeconds: 84
                    )
                )
            }
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
    }
}
