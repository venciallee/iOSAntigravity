import SwiftUI
import AntigravityData

/// Adaptive shell container (`AntigravityShellController`) that routes between
/// Pairing (`S01`), Session List (`S02`), Cascade Message List & Composer (`S03`),
/// Permission/Question Gates (`S04`/`S05`), Artifact Review (`S06`), and Turn Diffs (`S07`),
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
            if let verifyCase = activeVerifyCase {
                isolatedESDDSceneView(for: verifyCase)
            } else {
                interactiveNavigationView
            }
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
    }

    @ViewBuilder
    private var interactiveNavigationView: some View {
        switch store.currentRoute {
        case .pairingQR:
            RemotePairingViewController(store: store)
        case .workspaceHome:
            WorkspaceHomeViewController(store: store)
        case .cascadeChat:
            CascadeChatViewController(store: store)
        case .artifactInspector:
            ArtifactReviewViewController(store: store)
        case .turnDiffInspector:
            TurnDiffViewController(store: store)
        }
    }

    @ViewBuilder
    private func isolatedESDDSceneView(for verifyCase: ESDDVerifySceneCase) -> some View {
        switch verifyCase {
        case .pairingQR:
            RemotePairingViewController(store: store)
        case .workspaceHome:
            WorkspaceHomeViewController(store: store)
        case .cascadeStreaming:
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
}
