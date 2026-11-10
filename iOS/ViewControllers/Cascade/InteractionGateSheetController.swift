import SwiftUI
import AntigravityData

/// States `S04_PERMISSION_GATE` & `S05_ASK_QUESTION_MODAL`:
/// Handles `CORTEX_STEP_STATUS_WAITING (9)` steps with native Liquid Glass approval sheets
/// (`Allow Once`, `Always Allow in Turn (turnGrants)`, `Safe Auto-Accept`, and `ask_question` multi-select).
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
        VStack(alignment: .leading, spacing: 16) {
            switch mode {
            case .permissionGate:
                Text("Permission Gate · Step 24")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.statusWaiting)

                Text("python3 verification/esdd-verify.py --suite all")
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AntigravityTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("permission-resource-box")

                Toggle("Safe Auto-Accept Read-Only & In-Workspace Steps", isOn: $store.safeAutoAcceptEnabled)
                    .font(AntigravityTheme.TypographyTier.process.font)
                    .foregroundStyle(AntigravityTheme.inkLabel)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .accessibilityIdentifier("toggle-safe-auto-accept")

                Button(action: {}) {
                    Text("Always Allow in Turn (turnGrants)")
                        .font(AntigravityTheme.TypographyTier.evidence.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-allow-turn-grant")

                HStack(spacing: 12) {
                    Button(action: {}) {
                        Text("Allow Once")
                            .font(AntigravityTheme.TypographyTier.chrome.font)
                            .foregroundStyle(AntigravityTheme.inkLabel)
                            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                    }
                    .background(AntigravityTheme.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("btn-allow-once")

                    Button(action: {}) {
                        Text("Reject")
                            .font(AntigravityTheme.TypographyTier.chrome.font)
                            .foregroundStyle(AntigravityTheme.statusError)
                            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                    }
                    .background(AntigravityTheme.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("btn-reject-permission")
                }

            case .askQuestion:
                Text("Clarification Needed · ask_question")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.accentSecondary)

                Text("Which transport channel should be the default when pairing a new iOS device?")
                    .font(AntigravityTheme.TypographyTier.reading.font)
                    .foregroundStyle(AntigravityTheme.inkReading)

                ForEach(0..<3, id: \.self) { idx in
                    Button(action: {}) {
                        Text("Option \(idx + 1)")
                            .font(AntigravityTheme.TypographyTier.evidence.font)
                            .foregroundStyle(AntigravityTheme.inkLabel)
                            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt, alignment: .leading)
                            .padding(.horizontal, 14)
                    }
                    .background(AntigravityTheme.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("option-card-\(idx)")
                }

                Button(action: {}) {
                    Text("Submit Answer")
                        .font(AntigravityTheme.TypographyTier.evidence.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-submit-answer")
            }
        }
        .padding(20)
        .background(AntigravityTheme.canvasObsidian)
    }
}
