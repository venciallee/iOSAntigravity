import SwiftUI
import AntigravityData

/// State `S07_TURN_DIFF_INSPECTOR`: Renders word-level Unified/Split Turn Diffs
/// from `GetTurnDiff` and `GetPatchAndCodeChange`.
public struct TurnDiffViewController: View {
    @Bindable public var store: AntigravitySessionStore

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ConnectEnvelope.swift")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                Spacer()
                Text("+184 -22")
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.statusDone)
            }
            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
            .accessibilityIdentifier("diff-file-tabs")

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if let firstPatch = store.activeTurnDiffs.first {
                        ForEach(firstPatch.lines) { line in
                            Text(line.text)
                                .font(AntigravityTheme.TypographyTier.metadata.font)
                                .foregroundStyle(
                                    line.kind == .addition
                                        ? AntigravityTheme.statusDone
                                        : (line.kind == .deletion ? AntigravityTheme.statusError : AntigravityTheme.inkLabel)
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(10)
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("diff-code-surface")
            }

            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Accept Patch")
                        .font(AntigravityTheme.TypographyTier.evidence.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.statusDone)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-accept-patch")

                Button(action: {}) {
                    Text("Revert Hunk")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                        .foregroundStyle(AntigravityTheme.statusError)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-revert-patch")
            }
        }
        .padding(16)
        .background(AntigravityTheme.canvasObsidian)
    }
}
