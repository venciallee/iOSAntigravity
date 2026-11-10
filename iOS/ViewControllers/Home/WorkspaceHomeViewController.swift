import SwiftUI
import AntigravityData

/// State `S02_WORKSPACE_HOME`: Displays connected host `lt74xt6l0m-golden-star`,
/// Git worktree filter pills, and real-time `JetboxSubscribeToSummaries` conversations
/// restored in `<10ms` from SQLite projections.
public struct WorkspaceHomeViewController: View {
    @Bindable public var store: AntigravitySessionStore

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AntigravityTheme.statusDone)
                        .frame(width: 8, height: 8)
                    Text("\(store.activeHost.hostname) · \(store.activeHost.latencyMs)ms")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                        .foregroundStyle(AntigravityTheme.inkLabel)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .antigravityGlass(cornerRadius: 22)
                .accessibilityIdentifier("host-status-pill")

                Spacer()

                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New Cascade")
                    }
                    .font(AntigravityTheme.TypographyTier.chrome.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .padding(.horizontal, 14)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.accentPrimary)
                .clipShape(Capsule())
                .accessibilityIdentifier("btn-new-cascade")
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.summaries) { summary in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(summary.title)
                                    .font(AntigravityTheme.TypographyTier.evidence.font)
                                    .foregroundStyle(AntigravityTheme.inkReading)
                                Text("\(summary.branchName) · \(summary.stepCount) steps")
                                    .font(AntigravityTheme.TypographyTier.metadata.font)
                                    .foregroundStyle(AntigravityTheme.inkSecondary)
                            }
                            Spacer()
                            Text(summary.status.jsonName.replacingOccurrences(of: "CORTEX_STEP_STATUS_", with: ""))
                                .font(AntigravityTheme.TypographyTier.metadata.font)
                                .foregroundStyle(
                                    summary.status == .waiting
                                        ? AntigravityTheme.statusWaiting
                                        : AntigravityTheme.statusRunning
                                )
                        }
                        .padding(14)
                        .frame(minHeight: 60)
                        .background(AntigravityTheme.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .background(AntigravityTheme.canvasObsidian)
    }
}
