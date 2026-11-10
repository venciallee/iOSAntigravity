import SwiftUI

/// Liquid Glass container & Amber Approval card modifiers matching the 13 official iOS UE screens.
public struct AntigravityGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var isHighlighted: Bool
    public var isAmberWarning: Bool

    public init(cornerRadius: CGFloat = 24, isHighlighted: Bool = false, isAmberWarning: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isHighlighted = isHighlighted
        self.isAmberWarning = isAmberWarning
    }

    public func body(content: Content) -> some View {
        let strokeColor: Color = {
            if isAmberWarning {
                return AntigravityTheme.statusWaiting.opacity(0.36)
            } else if isHighlighted {
                return AntigravityTheme.accentPeriwinkle.opacity(0.45)
            } else {
                return AntigravityTheme.glassHairline
            }
        }()

        let fillOverlay: Color = isAmberWarning
            ? AntigravityTheme.statusWaiting.opacity(0.07)
            : Color.clear

        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AntigravityTheme.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(fillOverlay)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
    }
}

public extension View {
    func antigravityGlass(
        cornerRadius: CGFloat = 24,
        isHighlighted: Bool = false,
        isAmberWarning: Bool = false
    ) -> some View {
        modifier(
            AntigravityGlassModifier(
                cornerRadius: cornerRadius,
                isHighlighted: isHighlighted,
                isAmberWarning: isAmberWarning
            )
        )
    }
}
