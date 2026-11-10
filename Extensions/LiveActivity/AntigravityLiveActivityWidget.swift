import SwiftUI
import AppIntents
import AntigravityData

/// AppIntent enabling one-tap command approval directly from the iOS 18 Lock Screen
/// or Dynamic Island without opening the full app.
public struct ApproveWaitingStepIntent: AppIntent {
    public static let title: LocalizedStringResource = "Approve Waiting Step"
    public static let description = IntentDescription("Approves the waiting Antigravity step via HandleCascadeUserInteraction.")

    @Parameter(title: "Cascade ID")
    public var cascadeId: String

    @Parameter(title: "Step Index")
    public var stepIndex: Int

    public init() {
        self.cascadeId = ""
        self.stepIndex = 0
    }

    public init(cascadeId: String, stepIndex: Int) {
        self.cascadeId = cascadeId
        self.stepIndex = stepIndex
    }

    public func perform() async throws -> some IntentResult {
        return .result()
    }
}

/// Renders the Lock Screen Live Activity card and Dynamic Island (Compact, Minimal, Expanded)
/// for active Antigravity Cascades and WAITING permission gates.
public struct AntigravityLiveActivityView: View {
    public let attributes: AntigravityActivityAttributes
    public let state: AntigravityActivityAttributes.ContentState

    public init(
        attributes: AntigravityActivityAttributes,
        state: AntigravityActivityAttributes.ContentState
    ) {
        self.attributes = attributes
        self.state = state
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(state.pendingApprovalCommand != nil ? AntigravityTheme.statusWaiting : AntigravityTheme.statusRunning)
                    .frame(width: 8, height: 8)
                Text(attributes.hostName)
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                Spacer()
                Text("Step \(state.currentStepIndex)/\(state.totalSteps) · \(state.elapsedSeconds)s")
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.inkTertiary)
            }

            Text(attributes.cascadeTitle)
                .font(AntigravityTheme.TypographyTier.evidence.font)
                .foregroundStyle(AntigravityTheme.inkReading)
                .lineLimit(1)

            if let cmd = state.pendingApprovalCommand {
                HStack(spacing: 8) {
                    Text(cmd)
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.statusWaiting)
                        .lineLimit(1)
                    Spacer()
                    Button(intent: ApproveWaitingStepIntent(cascadeId: attributes.cascadeId, stepIndex: state.currentStepIndex)) {
                        Text("Approve")
                            .font(AntigravityTheme.TypographyTier.chrome.font)
                            .padding(.horizontal, 14)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    }
                    .tint(AntigravityTheme.accentPrimary)
                }
            } else {
                Text(state.activeToolAction)
                    .font(AntigravityTheme.TypographyTier.process.font)
                    .foregroundStyle(AntigravityTheme.inkSecondary)
            }
        }
        .padding(16)
        .background(AntigravityTheme.surfaceCard)
    }
}
