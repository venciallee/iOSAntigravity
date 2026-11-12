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

/// Authentic Antigravity Desktop 2×2 four-dot pulsing loading indicator (`::`) shown on active/running
/// conversation rows and streaming status bars.
public struct AntigravityFourDotLoadingView: View {
    public var isAnimated: Bool
    public var dotSize: CGFloat
    public var spacing: CGFloat
    public var tint: Color

    private static let phaseOpacities: [[Double]] = [
        [0.36, 0.64, 0.28, 0.92],
        [0.92, 0.36, 0.64, 0.28],
        [0.28, 0.92, 0.36, 0.64],
        [0.64, 0.28, 0.92, 0.36]
    ]

    public init(
        isAnimated: Bool = true,
        dotSize: CGFloat = 4.5,
        spacing: CGFloat = 3.5,
        tint: Color = Color.white
    ) {
        self.isAnimated = isAnimated
        self.dotSize = dotSize
        self.spacing = spacing
        self.tint = tint
    }

    public var body: some View {
        if isAnimated {
            TimelineView(.periodic(from: .now, by: 0.05)) { context in
                let t = context.date.timeIntervalSinceReferenceDate * 5.2
                // Clockwise 2x2 order: top-left (0), top-right (1), bottom-right (3), bottom-left (2)
                let phaseOffsets: [Double] = [0.0, .pi * 0.5, .pi * 1.5, .pi]
                let waves = phaseOffsets.map { offset in
                    0.5 + 0.5 * sin(t - offset)
                }
                let opacities = waves.map { 0.18 + 0.82 * $0 }
                let scales = waves.map { CGFloat(0.80 + 0.36 * $0) }
                fourDotGrid(opacities: opacities, scales: scales)
            }
        } else {
            fourDotGrid(opacities: Self.phaseOpacities[0], scales: [1.0, 1.0, 1.0, 1.0])
        }
    }

    private func fourDotGrid(opacities: [Double], scales: [CGFloat]) -> some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                Circle()
                    .fill(tint.opacity(opacities[0]))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(scales[0])
                Circle()
                    .fill(tint.opacity(opacities[1]))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(scales[1])
            }
            HStack(spacing: spacing) {
                Circle()
                    .fill(tint.opacity(opacities[2]))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(scales[2])
                Circle()
                    .fill(tint.opacity(opacities[3]))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(scales[3])
            }
        }
        .frame(width: dotSize * 2 + spacing + 2, height: dotSize * 2 + spacing + 2)
    }
}

/// Leading periwinkle running-arc indicator with live rotation when connected to Antigravity Desktop.
public struct AntigravityRunningArcIndicatorView: View {
    public var isAnimated: Bool

    public init(isAnimated: Bool = false) {
        self.isAnimated = isAnimated
    }

    public var body: some View {
        if isAnimated {
            TimelineView(.periodic(from: .now, by: 0.033)) { context in
                let angle = (context.date.timeIntervalSinceReferenceDate * 270.0)
                    .truncatingRemainder(dividingBy: 360.0)
                arcRing(angleDegrees: angle - 85.0)
            }
        } else {
            arcRing(angleDegrees: -85.0)
        }
    }

    private func arcRing(angleDegrees: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0x2A / 255.0, green: 0x31 / 255.0, blue: 0x42 / 255.0), lineWidth: 2)
                .frame(width: 15, height: 15)
            Circle()
                .trim(from: 0.0, to: 0.32)
                .stroke(
                    AntigravityTheme.statusRunning,
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
                .frame(width: 15, height: 15)
                .rotationEffect(.degrees(angleDegrees))
        }
    }
}

