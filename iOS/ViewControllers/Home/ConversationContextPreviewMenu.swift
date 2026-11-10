import SwiftUI
import AntigravityData

/// State `UE03_CONTEXT_MENU_PIN`: Long-Press Rich Context Preview Menu & Swipe Pin/Archive Shortcut.
/// Matches `/home/antigravity/iOS_·_长按菜单_Pin.png` 1:1.
public struct ConversationContextPreviewMenu: View {
    @Bindable public var store: AntigravitySessionStore
    public var onDismiss: (() -> Void)?

    @State private var isPinned: Bool = false
    @State private var isUnread: Bool = false
    @State private var swipeTargetPinned: Bool = false
    @State private var swipeTargetArchived: Bool = false

    public init(
        store: AntigravitySessionStore,
        onDismiss: (() -> Void)? = nil
    ) {
        self.store = store
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Soft ambient blurred glow matching UE03 dark backdrop
            AntigravityTheme.canvasObsidian
                .ignoresSafeArea()
                .overlay(alignment: .topLeading) {
                    Ellipse()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 140, height: 42)
                        .blur(radius: 20)
                        .offset(x: 20, y: 58)
                }

            VStack(alignment: .leading, spacing: 14) {
                Spacer()
                    .frame(height: 62)

                richPreviewCard

                contextActionMenuCard

                swipeShortcutPreviewSection

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
    }

    // MARK: - 1. Rich Long-Press Preview Card

    private var richPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AntigravityTheme.statusWaiting.opacity(0.22))
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(AntigravityTheme.statusWaiting)
                        .frame(width: 9.5, height: 9.5)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fix flaky TestSettlementBatch")
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Text("ledger-svc · Gemini 3.1 Pro · 8m")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                }

                Spacer()
            }

            Text("The flake comes from a shared fake clock across parallel subtests in settlement_test.go. I wrote a plan to isolate it per test — review it before I change anything?")
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(3.5)
                .foregroundStyle(UEChromePalette.textBody)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    onDismiss?()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UEChromePalette.textBody)
                        Text("Implementation Plan")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(UEChromePalette.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color(red: 0x26 / 255.0, green: 0x28 / 255.0, blue: 0x30 / 255.0))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chip-implementation-plan")

                Button {
                    onDismiss?()
                } label: {
                    Text("Awaiting review")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.statusWaiting)
                        .padding(.horizontal, 14)
                        .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(AntigravityTheme.statusWaiting.opacity(0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(AntigravityTheme.statusWaiting.opacity(0.24), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chip-awaiting-review")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0x1A / 255.0, green: 0x1B / 255.0, blue: 0x20 / 255.0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
        .accessibilityIdentifier("context-preview-card")
    }

    // MARK: - 2. 6-Item iOS Context Menu

    private var contextActionMenuCard: some View {
        VStack(spacing: 0) {
            menuRowButton(
                title: isPinned ? "Unpin" : "Pin",
                symbol: "pin",
                isHighlighted: true,
                isDestructive: false,
                accessibilityId: "menu-action-pin"
            ) {
                isPinned.toggle()
            }

            Divider().overlay(UEChromePalette.subtleDivider)

            menuRowButton(
                title: isUnread ? "Mark as Read" : "Mark as Unread",
                symbol: "circle.inset.filled",
                isHighlighted: false,
                isDestructive: false,
                accessibilityId: "menu-action-unread"
            ) {
                isUnread.toggle()
            }

            Divider().overlay(UEChromePalette.subtleDivider)

            menuRowButton(
                title: "Rename",
                symbol: "pencil",
                isHighlighted: false,
                isDestructive: false,
                accessibilityId: "menu-action-rename"
            ) {
                onDismiss?()
            }

            Divider().overlay(UEChromePalette.subtleDivider)

            menuRowButton(
                title: "Move to Project",
                symbol: "chevron.right",
                isHighlighted: false,
                isDestructive: false,
                accessibilityId: "menu-action-move"
            ) {
                onDismiss?()
            }

            Rectangle()
                .fill(Color(red: 0x1A / 255.0, green: 0x1B / 255.0, blue: 0x21 / 255.0))
                .frame(height: 7)

            menuRowButton(
                title: "Archive",
                symbol: "archivebox",
                isHighlighted: false,
                isDestructive: false,
                accessibilityId: "menu-action-archive"
            ) {
                onDismiss?()
            }

            Divider().overlay(UEChromePalette.subtleDivider)

            menuRowButton(
                title: "Delete",
                symbol: "trash",
                isHighlighted: false,
                isDestructive: true,
                accessibilityId: "menu-action-delete"
            ) {
                onDismiss?()
            }
        }
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(UEChromePalette.surfacePopover)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 22, x: 0, y: 10)
    }

    private func menuRowButton(
        title: String,
        symbol: String,
        isHighlighted: Bool,
        isDestructive: Bool,
        accessibilityId: String,
        action: @escaping () -> Void
    ) -> some View {
        let fg = isDestructive ? AntigravityTheme.statusError : Color.white
        return Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(fg)
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 45)
            .background(isHighlighted ? Color.white.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }

    // MARK: - 3. Swipe Shortcut Row Preview

    private var swipeShortcutPreviewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SWIPE SHORTCUT")
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(UEChromePalette.textMuted)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Go 1.25")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text(swipeTargetArchived ? "Archived · 1h" : "Done · 1h")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(UEChromePalette.textMuted)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                .background(AntigravityTheme.surfaceCard)

                Button {
                    swipeTargetPinned.toggle()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pin")
                            .font(.system(size: 14.5, weight: .semibold))
                        Text(swipeTargetPinned ? "Pinned" : "Pin")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(UEChromePalette.inkOnPrimaryCTA)
                    .frame(width: 78, height: 66)
                    .background(AntigravityTheme.accentPeriwinkle)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("swipe-action-pin")

                Button {
                    swipeTargetArchived.toggle()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 14.5, weight: .medium))
                        Text("Archive")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(width: 78, height: 66)
                    .background(Color(red: 0x38 / 255.0, green: 0x3A / 255.0, blue: 0x43 / 255.0))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("swipe-action-archive")
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
            )
        }
        .padding(.top, 2)
    }
}
