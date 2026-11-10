#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

/// Antigravity Obsidian & Liquid Glass Design System tokens (`specs/01-antigravity-design-system.md`).
public enum AntigravityTheme {

    // MARK: - Obsidian Surface Hierarchy

    public static let canvasObsidian = Color(red: 0x09 / 255.0, green: 0x0B / 255.0, blue: 0x10 / 255.0)
    public static let surfaceElevated = Color(red: 0x11 / 255.0, green: 0x15 / 255.0, blue: 0x20 / 255.0)
    public static let surfaceCard = Color(red: 0x16 / 255.0, green: 0x1B / 255.0, blue: 0x29 / 255.0)
    public static let hairlineBorder = Color.white.opacity(0.08)

    // MARK: - Antigravity Cosmic Brand & Signal Colors

    public static let accentPrimary = Color(red: 0x63 / 255.0, green: 0x66 / 255.0, blue: 0xF1 / 255.0)   // #6366F1
    public static let accentSecondary = Color(red: 0x8B / 255.0, green: 0x5C / 255.0, blue: 0xF6 / 255.0) // #8B5CF6
    public static let accentCyan = Color(red: 0x06 / 255.0, green: 0xB6 / 255.0, blue: 0xD4 / 255.0)      // #06B6D4

    public static let statusRunning = Color(red: 0x38 / 255.0, green: 0xBD / 255.0, blue: 0xF8 / 255.0)   // #38BDF8
    public static let statusWaiting = Color(red: 0xF5 / 255.0, green: 0x9E / 255.0, blue: 0x0B / 255.0)   // #F59E0B
    public static let statusDone = Color(red: 0x10 / 255.0, green: 0xB9 / 255.0, blue: 0x81 / 255.0)      // #10B981
    public static let statusError = Color(red: 0xF4 / 255.0, green: 0x3F / 255.0, blue: 0x5E / 255.0)     // #F43F5E

    // MARK: - 5-Tier Ink Tokens

    public static let inkReading = Color(red: 0xF8 / 255.0, green: 0xFA / 255.0, blue: 0xFC / 255.0)      // #F8FAFC
    public static let inkLabel = Color(red: 0xE2 / 255.0, green: 0xE8 / 255.0, blue: 0xF0 / 255.0)        // #E2E8F0
    public static let inkSecondary = Color(red: 0x94 / 255.0, green: 0xA3 / 255.0, blue: 0xB8 / 255.0)    // #94A3B8
    public static let inkTertiary = Color(red: 0x64 / 255.0, green: 0x74 / 255.0, blue: 0x8B / 255.0)     // #64748B

    // MARK: - 5-Tier Semantic Typography Roles

    public enum TypographyTier: String, CaseIterable, Sendable {
        case reading
        case evidence
        case process
        case metadata
        case chrome

        public var font: Font {
            switch self {
            case .reading:  return .system(size: 16, weight: .regular, design: .default)
            case .evidence: return .system(size: 14, weight: .medium, design: .default)
            case .process:  return .system(size: 13, weight: .regular, design: .default)
            case .metadata: return .system(size: 11, weight: .regular, design: .monospaced)
            case .chrome:   return .system(size: 13, weight: .medium, design: .default)
            }
        }
    }

    public static let minTouchTargetPt: CGFloat = 44.0
}
