import SwiftUI

/// Normative design tokens extracted 1:1 from the 13 official Antigravity iOS UE screens:
/// Matte OLED Obsidian (`#090A0D`), Grouped Dark Cards (`#141519`), Periwinkle Soft Blue CTA (`#8EB4FF`),
/// Warm Amber Face ID Approval (`#EBB365`), Emerald Diff Addition (`#57C88A`), and Coral Deletion (`#F07167`).
public enum AntigravityTheme {
    // MARK: - Surfaces
    public static let canvasObsidian = Color(red: 0x09 / 255.0, green: 0x0A / 255.0, blue: 0x0D / 255.0)
    public static let surfaceObsidian = Color(red: 0x0F / 255.0, green: 0x10 / 255.0, blue: 0x14 / 255.0)
    public static let surfaceCard = Color(red: 0x14 / 255.0, green: 0x15 / 255.0, blue: 0x19 / 255.0)
    public static let surfaceElevated = Color(red: 0x1D / 255.0, green: 0x1F / 255.0, blue: 0x26 / 255.0)
    public static let surfacePopover = Color(red: 0x25 / 255.0, green: 0x27 / 255.0, blue: 0x2F / 255.0)
    public static let glassHairline = Color.white.opacity(0.08)

    // MARK: - Brand Accents (Latest UE Spec)
    /// Primary Periwinkle Soft Blue (`#8EB4FF`) used on primary CTAs, FABs, selected borders, and checkboxes.
    public static let accentPeriwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0)
    public static let accentPrimary = accentPeriwinkle
    public static let accentSecondary = Color(red: 0x7D / 255.0, green: 0xA7 / 255.0, blue: 0xFF / 255.0)
    /// Dark ink used inside filled `#8EB4FF` or `#EBB365` primary buttons (`#0A0E17`).
    public static let inkOnPrimaryCTA = Color(red: 0x0A / 255.0, green: 0x0E / 255.0, blue: 0x17 / 255.0)
    public static let pillActiveWhite = Color.white

    // MARK: - Semantic Status Palette
    /// Running (`运行中`) — Periwinkle Blue `#7DA7FF`
    public static let statusRunning = Color(red: 0x7D / 255.0, green: 0xA7 / 255.0, blue: 0xFF / 255.0)
    /// Needs You / Waiting Approval (`等你处理`) — Warm Amber Gold `#EBB365`
    public static let statusWaiting = Color(red: 0xEB / 255.0, green: 0xB3 / 255.0, blue: 0x65 / 255.0)
    /// Done / Diff Additions (`完成`) — Emerald `#57C88A`
    public static let statusDone = Color(red: 0x57 / 255.0, green: 0xC8 / 255.0, blue: 0x8A / 255.0)
    /// Deletions / Destructive — Coral Red `#F07167`
    public static let statusError = Color(red: 0xF0 / 255.0, green: 0x71 / 255.0, blue: 0x67 / 255.0)

    // MARK: - Ink Hierarchy
    public static let inkReading = Color(red: 0xF5 / 255.0, green: 0xF6 / 255.0, blue: 0xF8 / 255.0)
    public static let inkLabel = Color(red: 0xD1 / 255.0, green: 0xD5 / 255.0, blue: 0xDF / 255.0)
    public static let inkSecondary = Color(red: 0x8A / 255.0, green: 0x90 / 255.0, blue: 0x9E / 255.0)
    public static let inkMuted = Color(red: 0x55 / 255.0, green: 0x5A / 255.0, blue: 0x66 / 255.0)

    // MARK: - HIG Geometry Invariants
    public static let minTouchTargetPt: CGFloat = 44.0
    public static let cardCornerRadiusPt: CGFloat = 18.0
    public static let sheetCornerRadiusPt: CGFloat = 28.0
    public static let floatingTabBarCornerRadiusPt: CGFloat = 30.0
    public static let fabDiameterPt: CGFloat = 56.0

    // MARK: - 5-Tier Semantic Typography
    public enum TypographyTier {
        case largeTitle
        case reading
        case evidence
        case process
        case metadata
        case chrome

        public var font: Font {
            switch self {
            case .largeTitle:
                return .system(size: 32, weight: .bold, design: .default)
            case .reading:
                return .system(size: 16, weight: .regular, design: .default)
            case .evidence:
                return .system(size: 16, weight: .semibold, design: .default)
            case .process:
                return .system(size: 14, weight: .regular, design: .default)
            case .metadata:
                return .system(size: 13, weight: .medium, design: .monospaced)
            case .chrome:
                return .system(size: 14, weight: .semibold, design: .default)
            }
        }
    }
}
