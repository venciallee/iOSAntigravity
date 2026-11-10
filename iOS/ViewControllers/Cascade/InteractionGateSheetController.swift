import SwiftUI
import AntigravityData

/// Permission Gate & Question Modal (`InteractionGateSheetController`) bridging sheet presentations
/// to `InlineCommandApprovalCardView` (Face ID biometric gate) and `StructuredQuestionCardView`.
public struct InteractionGateSheetController: View {
    public enum PresentationMode: Sendable {
        case permissionGate
        case askQuestion
    }

    @Bindable public var store: AntigravitySessionStore
    public var mode: PresentationMode

    public init(store: AntigravitySessionStore, mode: PresentationMode) {
        self.store = store
        self.mode = mode
    }

    public var body: some View {
        switch mode {
        case .permissionGate:
            VStack(alignment: .leading, spacing: 16) {
                InlineCommandApprovalCardView(store: store)
            }
            .padding(16)
            .background(AntigravityTheme.canvasObsidian)

        case .askQuestion:
            StructuredQuestionCardView(store: store)
        }
    }
}
