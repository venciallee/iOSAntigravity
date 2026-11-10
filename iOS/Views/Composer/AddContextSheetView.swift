import SwiftUI
import AntigravityData

/// State `UE08_ADD_CONTEXT`: Official Add Context modal sheet (`iOS · Add Context`).
/// Features:
/// - `Add Context` header with circular `×` close button
/// - Search input (`Search files, folders, skills...`, `context-search-input`)
/// - 5 category tiles (`Files`, `Folder`, `Mentions`, `Actions`, `Skills`)
/// - Grouped multi-select sections: `FILES & FOLDERS`, `MENTIONS`, `ACTIONS & SKILLS`
/// - Sticky footer with `3 selected` count and Periwinkle `#8EB4FF` `Add to message` CTA (`btn-add-to-message`).
public struct AddContextSheetView: View {
    public enum CategoryTile: String, CaseIterable, Identifiable, Sendable {
        case files = "Files"
        case folder = "Folder"
        case mentions = "Mentions"
        case actions = "Actions"
        case skills = "Skills"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .files: return "doc"
            case .folder: return "folder"
            case .mentions: return "at"
            case .actions: return "bolt"
            case .skills: return "cube"
            }
        }

        public var testId: String {
            switch self {
            case .files: return "tile-files"
            case .folder: return "tile-folder"
            case .mentions: return "tile-mentions"
            case .actions: return "tile-actions"
            case .skills: return "tile-skills"
            }
        }
    }

    private struct ContextRowSpec: Identifiable {
        let id: String
        let section: String
        let category: CategoryTile
        let iconName: String
        let title: String
        let subtitle: String
        let isMonospacedTitle: Bool
        let usesPlusAffordance: Bool
        let testId: String
    }

    @Bindable public var store: AntigravitySessionStore
    public var onAddLabels: (([String]) -> Void)?
    public var onDismiss: (() -> Void)?

    @State private var searchQuery: String = ""
    @State private var activeCategoryFilter: CategoryTile? = nil
    @State private var selectedItemIds: Set<String> = [
        "ratelimit.go",
        "idempotency-payouts",
        "go-testing"
    ]

    private static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    private static let inkOnCTA = Color(red: 0x0A / 255.0, green: 0x0E / 255.0, blue: 0x17 / 255.0) // #0A0E17
    private static let sheetSurface = Color(red: 0x15 / 255.0, green: 0x16 / 255.0, blue: 0x1B / 255.0)
    private static let groupSurface = Color(red: 0x1E / 255.0, green: 0x20 / 255.0, blue: 0x28 / 255.0)
    private static let tileSurface = Color(red: 0x21 / 255.0, green: 0x23 / 255.0, blue: 0x2B / 255.0)

    private let allRows: [ContextRowSpec] = [
        ContextRowSpec(
            id: "ratelimit.go",
            section: "FILES & FOLDERS",
            category: .files,
            iconName: "doc",
            title: "ratelimit.go",
            subtitle: "internal/middleware · changed this turn",
            isMonospacedTitle: true,
            usesPlusAffordance: false,
            testId: "ctx-row-ratelimit"
        ),
        ContextRowSpec(
            id: "load/",
            section: "FILES & FOLDERS",
            category: .folder,
            iconName: "folder",
            title: "load/",
            subtitle: "Folder · 3 files",
            isMonospacedTitle: true,
            usesPlusAffordance: false,
            testId: "ctx-row-load-folder"
        ),
        ContextRowSpec(
            id: "idempotency-payouts",
            section: "MENTIONS",
            category: .mentions,
            iconName: "bubble.left",
            title: "Idempotency keys for payouts",
            subtitle: "Conversation · ledger-svc",
            isMonospacedTitle: false,
            usesPlusAffordance: false,
            testId: "ctx-row-idempotency"
        ),
        ContextRowSpec(
            id: "terminal-last-test",
            section: "MENTIONS",
            category: .mentions,
            iconName: "terminal",
            title: "Terminal · last test run",
            subtitle: "Output · 214 lines",
            isMonospacedTitle: false,
            usesPlusAffordance: false,
            testId: "ctx-row-terminal"
        ),
        ContextRowSpec(
            id: "/boost",
            section: "ACTIONS & SKILLS",
            category: .actions,
            iconName: "bolt",
            title: "/boost",
            subtitle: "Action · extra multi-agent reasoning pass",
            isMonospacedTitle: true,
            usesPlusAffordance: true,
            testId: "ctx-row-boost"
        ),
        ContextRowSpec(
            id: "go-testing",
            section: "ACTIONS & SKILLS",
            category: .skills,
            iconName: "cube",
            title: "go-testing",
            subtitle: "Skill · table-driven tests, -race, golden files",
            isMonospacedTitle: false,
            usesPlusAffordance: false,
            testId: "ctx-row-go-testing"
        )
    ]

    public init(
        store: AntigravitySessionStore,
        onAddLabels: (([String]) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.store = store
        self.onAddLabels = onAddLabels
        self.onDismiss = onDismiss
    }

    private func filteredRows(in section: String) -> [ContextRowSpec] {
        allRows.filter { row in
            guard row.section == section else { return false }
            if let cat = activeCategoryFilter, row.category != cat {
                return false
            }
            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return true }
            return row.title.lowercased().contains(q) || row.subtitle.lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)

            VStack(spacing: 0) {
                // Sheet Grabber
                Capsule()
                    .fill(Color.white.opacity(0.26))
                    .frame(width: 38, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                // Header Bar
                ZStack {
                    Text("Add Context")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AntigravityTheme.inkReading)

                    HStack {
                        Spacer()
                        Button {
                            dismissSheet()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Self.tileSurface)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AntigravityTheme.inkLabel)
                            }
                            .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("btn-close-add-context")
                    }
                }
                .padding(.horizontal, 14)

                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                    TextField("Search files, folders, skills...", text: $searchQuery)
                        .font(.system(size: 15))
                        .foregroundStyle(AntigravityTheme.inkReading)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .background(Self.tileSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .accessibilityIdentifier("context-search-input")

                // 5 Category Tiles
                HStack(spacing: 8) {
                    ForEach(CategoryTile.allCases) { tile in
                        let isSelected = activeCategoryFilter == tile
                        Button {
                            activeCategoryFilter = (activeCategoryFilter == tile) ? nil : tile
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: tile.iconName)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(isSelected ? Self.periwinkle : AntigravityTheme.inkReading)
                                Text(tile.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(isSelected ? Self.periwinkle : AntigravityTheme.inkLabel)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .background(Self.tileSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(
                                        isSelected ? Self.periwinkle : Color.white.opacity(0.06),
                                        lineWidth: isSelected ? 1.5 : 1
                                    )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(tile.testId)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Grouped Sections ScrollView
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(["FILES & FOLDERS", "MENTIONS", "ACTIONS & SKILLS"], id: \.self) { sectionTitle in
                            let rows = filteredRows(in: sectionTitle)
                            if !rows.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(sectionTitle)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .tracking(0.6)
                                        .foregroundStyle(AntigravityTheme.inkSecondary)
                                        .padding(.horizontal, 4)

                                    VStack(spacing: 0) {
                                        ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                            contextRowButton(row)
                                            if idx < rows.count - 1 {
                                                Divider()
                                                    .overlay(Color.white.opacity(0.06))
                                                    .padding(.leading, 44)
                                            }
                                        }
                                    }
                                    .background(Self.groupSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                // Sticky Bottom Footer
                Divider()
                    .overlay(Color.white.opacity(0.08))

                HStack {
                    Text("\(selectedItemIds.count) selected")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AntigravityTheme.inkSecondary)

                    Spacer()

                    Button {
                        commitSelection()
                    } label: {
                        Text("Add to message")
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundStyle(Self.inkOnCTA)
                            .padding(.horizontal, 24)
                            .frame(minHeight: 48)
                            .background(Self.periwinkle)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("btn-add-to-message")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(Self.sheetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .background(AntigravityTheme.canvasObsidian)
    }

    private func contextRowButton(_ row: ContextRowSpec) -> some View {
        let isSelected = selectedItemIds.contains(row.id)
        return Button {
            if isSelected {
                selectedItemIds.remove(row.id)
            } else {
                selectedItemIds.insert(row.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: row.iconName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(
                            row.isMonospacedTitle
                                ? .system(size: 14.5, weight: .medium, design: .monospaced)
                                : .system(size: 15, weight: .medium)
                        )
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .lineLimit(1)
                    Text(row.subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Self.periwinkle)
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Self.inkOnCTA)
                    }
                } else if row.usesPlusAffordance {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 54)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(row.testId)
    }

    private func commitSelection() {
        let labels = allRows
            .filter { selectedItemIds.contains($0.id) }
            .map { row in
                row.category == .files ? "@\(row.title)" : row.title
            }
        if selectedItemIds.contains("ratelimit.go") {
            store.attachFileMention("internal/middleware/ratelimit.go")
        }
        onAddLabels?(labels)
        dismissSheet()
    }

    private func dismissSheet() {
        if let onDismiss {
            onDismiss()
        } else {
            store.currentRoute = .chatAndComposer
        }
    }
}
