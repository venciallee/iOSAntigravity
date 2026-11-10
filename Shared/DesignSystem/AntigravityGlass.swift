import SwiftUI

/// Liquid Glass surface modifier with 1px specular hairline border and subtle cosmic glow.
public struct AntigravityLiquidGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var isHighlighted: Bool

    public init(cornerRadius: CGFloat = 20, isHighlighted: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                isHighlighted
                                    ? AntigravityTheme.accentPrimary.opacity(0.55)
                                    : AntigravityTheme.hairlineBorder,
                                lineWidth: 1
                            )
                    )
            )
    }
}

extension View {
    public func antigravityGlass(cornerRadius: CGFloat = 20, isHighlighted: Bool = false) -> some View {
        modifier(AntigravityLiquidGlassModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}
