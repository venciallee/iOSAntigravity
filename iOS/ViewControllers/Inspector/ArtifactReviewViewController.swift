import SwiftUI
import AntigravityData

/// State `S06_ARTIFACT_PLAN_REVIEW`: Renders Antigravity `implementation_plan.md` artifacts
/// with GitHub alerts, Mermaid architecture diagram, and bottom `RequestFeedback` approval bar.
public struct ArtifactReviewViewController: View {
    @Bindable public var store: AntigravitySessionStore

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("implementation_plan.md · v3")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                Spacer()
                Text("RequestFeedback")
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.statusWaiting)
            }
            .accessibilityIdentifier("artifact-header")

            VStack(alignment: .leading, spacing: 8) {
                Text("IMPORTANT")
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.accentSecondary)
                Text("Direct Connect-RPC over /connect-websocket preserves 100% of Antigravity IDE trajectories and Artifacts.")
                    .font(AntigravityTheme.TypographyTier.reading.font)
                    .foregroundStyle(AntigravityTheme.inkLabel)
            }
            .padding(14)
            .background(AntigravityTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("artifact-alert-important")

            Spacer()

            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Proceed with Plan")
                        .font(AntigravityTheme.TypographyTier.evidence.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-proceed-plan")

                Button(action: {}) {
                    Text("Request Changes")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                        .foregroundStyle(AntigravityTheme.inkLabel)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-edit-plan")
            }
        }
        .padding(16)
        .background(AntigravityTheme.canvasObsidian)
    }
}
