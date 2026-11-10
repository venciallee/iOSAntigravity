import SwiftUI
import AntigravityData

/// State `UE02_DISPLAY_OPTIONS`: Display Options & Sort Conversations Popover Sheet.
/// Matches `/home/antigravity/iOS_·_Display_Options.png` 1:1.
public struct DisplayOptionsSheetView: View {
    @Bindable public var store: AntigravitySessionStore
    public var onDismiss: (() -> Void)?

    public enum GroupByOption: String, CaseIterable {
        case project = "Project"
        case host = "Host"
        case none = "None"
    }

    public enum ConversationSortField: String, CaseIterable, Identifiable {
        case lastUpdated = "Last Updated"
        case dateCreated = "Date Created"
        case title = "Title"

        public var id: String { rawValue }
    }

    public enum SortOrderDirection: String, CaseIterable, Identifiable {
        case newestFirst = "Newest First"
        case oldestFirst = "Oldest First"

        public var id: String { rawValue }
    }

    @State private var groupBy: GroupByOption = .project
    @State private var sortField: ConversationSortField = .lastUpdated
    @State private var sortDirection: SortOrderDirection = .newestFirst
    @State private var sortProjectsLabel: String = "Custom Order"
    @State private var autoPin: Bool = false
    @State private var archivedOnly: Bool = false
    @State private var unreadCount: Int = 3
    @State private var isSortPopoverPresented: Bool = true

    public init(
        store: AntigravitySessionStore,
        onDismiss: (() -> Void)? = nil
    ) {
        self.store = store
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed Agents backdrop matching UE02 reference composition
            VStack(alignment: .leading, spacing: 0) {
                Text("Agents")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.24))
                    .padding(.leading, 18)
                    .padding(.top, 56)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())

            // Bottom Sheet Surface
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: 38, height: 5)
                        .padding(.top, 10)

                    sheetHeaderBar

                    VStack(spacing: 12) {
                        groupingAndSortingCard
                        filterAndDisplayCard
                        togglesCard
                        markAllAsReadCard
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 10)
                }
                .frame(maxWidth: .infinity)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 28,
                        style: .continuous
                    )
                    .fill(UEChromePalette.surfaceSheet)
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 28,
                        style: .continuous
                    )
                    .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                )

                // Floating iOS pull-down Sort Popover Menu anchored below "Sort Conversations"
                if isSortPopoverPresented {
                    sortPopoverMenu
                        .padding(.top, 180)
                        .padding(.trailing, 24)
                }
            }
            .padding(.top, 108)
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
    }

    // MARK: - Header Bar (Reset / Display Options / Done)

    private var sheetHeaderBar: some View {
        HStack {
            Button {
                groupBy = .project
                sortField = .lastUpdated
                sortDirection = .newestFirst
                autoPin = false
                archivedOnly = false
            } label: {
                Text("Reset")
                    .font(.system(size: 16.5, weight: .regular))
                    .foregroundStyle(Color(red: 0x9D / 255.0, green: 0xA2 / 255.0, blue: 0xB0 / 255.0))
                    .frame(minWidth: 56, minHeight: AntigravityTheme.minTouchTargetPt, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sheet-reset-btn")

            Spacer()

            Text("Display Options")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white)

            Spacer()

            Button {
                isSortPopoverPresented = false
                onDismiss?()
            } label: {
                Text("Done")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                    .frame(minWidth: 56, minHeight: AntigravityTheme.minTouchTargetPt, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sheet-done-btn")
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Card 1: Group By / Sort Conversations / Sort Projects

    private var groupingAndSortingCard: some View {
        VStack(spacing: 0) {
            Button {
                let all = GroupByOption.allCases
                if let idx = all.firstIndex(of: groupBy) {
                    groupBy = all[(idx + 1) % all.count]
                }
            } label: {
                HStack {
                    Text("Group By")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(UEChromePalette.textPrimary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text(groupBy.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(UEChromePalette.textSecondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(UEChromePalette.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("row-group-by")

            Divider()
                .overlay(UEChromePalette.subtleDivider)

            Button {
                isSortPopoverPresented.toggle()
            } label: {
                HStack {
                    Text("Sort Conversations")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(UEChromePalette.textPrimary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text(sortField.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(UEChromePalette.textSecondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(UEChromePalette.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(isSortPopoverPresented ? Color.white.opacity(0.04) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("row-sort-conversations")

            Divider()
                .overlay(UEChromePalette.subtleDivider)

            Button {
                sortProjectsLabel = (sortProjectsLabel == "Custom Order") ? "Alphabetical" : "Custom Order"
            } label: {
                HStack {
                    Text("Sort Projects")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(UEChromePalette.textPrimary)
                    Spacer()
                    HStack(spacing: 6) {
                        Text(sortProjectsLabel)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(UEChromePalette.textSecondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(UEChromePalette.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(UEChromePalette.surfaceSheetGroup)
        )
    }

    // MARK: - Card 2: Filter / Display

    private var filterAndDisplayCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Filter")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(UEChromePalette.textPrimary)
                Spacer()
                HStack(spacing: 6) {
                    Text("All conversations")
                        .font(.system(size: 15.5, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UEChromePalette.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)

            Divider()
                .overlay(UEChromePalette.subtleDivider)

            HStack {
                Text("Display")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(UEChromePalette.textPrimary)
                Spacer()
                HStack(spacing: 6) {
                    Text("Comfortable · Previews")
                        .font(.system(size: 15.5, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UEChromePalette.textMuted)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(UEChromePalette.surfaceSheetGroup)
        )
    }

    // MARK: - Card 3: Auto Pin & Archived Only Toggles

    private var togglesCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    autoPin.toggle()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Pin")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(UEChromePalette.textPrimary)
                        Text("Pin a conversation when you message it")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(UEChromePalette.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(width: 96, minHeight: 54, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("toggle-auto-pin")

                Spacer()

                Toggle("", isOn: $autoPin)
                    .labelsHidden()
                    .tint(AntigravityTheme.accentPeriwinkle)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)

            Divider()
                .overlay(UEChromePalette.subtleDivider)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Archived Only")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(UEChromePalette.textPrimary)
                    Text("Show only archived conversations")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $archivedOnly)
                    .labelsHidden()
                    .tint(AntigravityTheme.accentPeriwinkle)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .accessibilityIdentifier("toggle-archived-only")
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(UEChromePalette.surfaceSheetGroup)
        )
    }

    // MARK: - Card 4: Mark All as Read

    private var markAllAsReadCard: some View {
        Button {
            unreadCount = 0
        } label: {
            HStack {
                Text("Mark All as Read")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                Spacer()
                Text("\(unreadCount) unread")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(UEChromePalette.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(UEChromePalette.surfaceSheetGroup)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("btn-mark-all-read")
    }

    // MARK: - Sort Popover Menu

    private var sortPopoverMenu: some View {
        VStack(spacing: 0) {
            ForEach(Array(ConversationSortField.allCases.enumerated()), id: \.element.id) { index, field in
                Button {
                    sortField = field
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(sortField == field ? Color.white : Color.clear)
                            .frame(width: 16)
                        Text(field.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < ConversationSortField.allCases.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                }
            }

            Rectangle()
                .fill(Color(red: 0x1D / 255.0, green: 0x1F / 255.0, blue: 0x25 / 255.0))
                .frame(height: 7)

            ForEach(Array(SortOrderDirection.allCases.enumerated()), id: \.element.id) { index, direction in
                Button {
                    sortDirection = direction
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(sortDirection == direction ? Color.white : Color.clear)
                            .frame(width: 16)
                        Text(direction.rawValue)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < SortOrderDirection.allCases.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                }
            }
        }
        .frame(width: 236)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0x2A / 255.0, green: 0x2C / 255.0, blue: 0x34 / 255.0).opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.50), radius: 24, x: 0, y: 12)
        .accessibilityIdentifier("sort-popover-menu")
    }
}
