import SwiftUI
import AntigravityData

/// State `S03_CASCADE_STREAMING`: Renders 120fps streaming conversation with
/// `TaskBoundary` progress banner, collapsible Thinking capsule, grouped File Evidence block,
/// native Terminal card, and Liquid Glass `ChatComposerView`.
public struct CascadeChatViewController: View {
    @Bindable public var store: AntigravitySessionStore

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // TaskBoundary Header Banner
            if let taskStep = store.activeSteps.first(where: { $0.type == .taskBoundary }),
               let tb = taskStep.taskBoundary {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tb.taskName)
                        .font(AntigravityTheme.TypographyTier.evidence.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                    Text(tb.taskStatus)
                        .font(AntigravityTheme.TypographyTier.process.font)
                        .foregroundStyle(AntigravityTheme.statusRunning)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(AntigravityTheme.surfaceElevated)
                .accessibilityIdentifier("task-boundary-banner")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(store.activeSteps) { step in
                        CascadeStepCellView(step: step)
                    }
                }
                .padding(16)
            }

            ChatComposerView(store: store)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .background(AntigravityTheme.canvasObsidian)
    }
}
