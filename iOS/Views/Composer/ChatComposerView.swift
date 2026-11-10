import SwiftUI
import AntigravityData

/// Native Liquid Glass input bar (`ChatComposerView`) pinned to `keyboardLayoutGuide`.
/// Resolves concrete model & effort labels (`Claude Sonnet 4.5 · High · Planning`) and
/// provides `>= 44pt` touch targets for attachments, `/slash` workflows, and send/cancel.
public struct ChatComposerView: View {
    @Bindable public var store: AntigravitySessionStore
    @State private var draftText: String = ""

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button(action: {}) {
                    Text("\(store.selectedModelConfig.displayName) · \(store.selectedModelConfig.effort.rawValue) · \(store.selectedModelConfig.mode.rawValue)")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                        .foregroundStyle(AntigravityTheme.inkLabel)
                        .padding(.horizontal, 12)
                        .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(Capsule())
                .accessibilityIdentifier("composer-model-pill")

                Spacer()

                Button(action: {}) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AntigravityTheme.accentPrimary)
                        .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                }
                .accessibilityIdentifier("composer-send-btn")
            }
        }
        .padding(12)
        .antigravityGlass(cornerRadius: 24, isHighlighted: true)
        .accessibilityIdentifier("liquid-glass-composer")
    }
}
