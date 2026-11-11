import SwiftUI
import AntigravityData

/// State `UE01_AGENTS_HOME`: Primary Agents Hub (Conversation & Project Hub).
/// Matches `/home/antigravity/iOS_·_Agents_首页.png` 1:1.
public struct AgentsHomeViewController: View {
    @Bindable public var store: AntigravitySessionStore

    public var onSelectTab: ((ShellTab) -> Void)?
    public var onOpenDisplayOptions: (() -> Void)?
    public var onOpenNewProject: (() -> Void)?
    public var onOpenProjectDetail: ((String) -> Void)?
    public var onOpenContextMenuPreview: (() -> Void)?
    public var onOpenConversation: ((String) -> Void)?

    public enum HostFilterTarget: String, CaseIterable, Identifiable {
        case macBookPro = "MacBook Pro"
        case cloud = "Cloud"
        case allHosts = "All Hosts"

        public var id: String { rawValue }
    }

    public enum QuickStatusFilter: String, CaseIterable, Identifiable {
        case all
        case running
        case needsYou
        case unread

        public var id: String { rawValue }
    }

    public enum IndicatorStyle: Equatable {
        case runningArc
        case needsReviewHalo
        case unreadDot
        case none
    }

    public struct AgentConversationItem: Identifiable, Equatable {
        public let id: String
        public var title: String
        public var statusLine: String
        public var statusHighlight: StatusTone
        public var projectSlug: String
        public var timestampLabel: String
        public var additions: Int?
        public var deletions: Int?
        public var indicator: IndicatorStyle
        public var isPinned: Bool
        public var isUnread: Bool
        public var isArchived: Bool

        public enum StatusTone: Equatable {
            case running
            case waiting
            case neutral
        }
    }

    public struct AgentProjectSection: Identifiable, Equatable {
        public let id: String
        public var slug: String
        public var subtitle: String
        public var isCloud: Bool
        public var conversations: [AgentConversationItem]
    }

    @State private var selectedHost: HostFilterTarget = .macBookPro
    @State private var searchText: String = ""
    @State private var selectedFilter: QuickStatusFilter = .all
    @State private var collapsedProjects: Set<String> = []
    @State private var standaloneSheet: StandaloneModal?

    @State private var pinnedItems: [AgentConversationItem] = [
        AgentConversationItem(
            id: "conv-rate-limiter",
            title: "Add rate limiter to /transfers",
            statusLine: "Running · Step 4 of 7 · go test ./internal/...",
            statusHighlight: .running,
            projectSlug: "ledger-svc",
            timestampLabel: "now",
            additions: nil,
            deletions: nil,
            indicator: .runningArc,
            isPinned: true,
            isUnread: false,
            isArchived: false
        ),
        AgentConversationItem(
            id: "conv-release-checklist",
            title: "Release checklist v2.3",
            statusLine: "Done · Walkthrough ready",
            statusHighlight: .neutral,
            projectSlug: "web-console",
            timestampLabel: "1h",
            additions: nil,
            deletions: nil,
            indicator: .none,
            isPinned: true,
            isUnread: false,
            isArchived: false
        )
    ]

    @State private var projectSections: [AgentProjectSection] = [
        AgentProjectSection(
            id: "ledger-svc",
            slug: "ledger-svc",
            subtitle: "Local · MacBook Pro · main",
            isCloud: false,
            conversations: [
                AgentConversationItem(
                    id: "conv-flaky-settlement",
                    title: "Fix flaky TestSettlementBatch",
                    statusLine: "Needs review · Implementation plan ready",
                    statusHighlight: .waiting,
                    projectSlug: "ledger-svc",
                    timestampLabel: "8m",
                    additions: nil,
                    deletions: nil,
                    indicator: .needsReviewHalo,
                    isPinned: false,
                    isUnread: true,
                    isArchived: false
                ),
                AgentConversationItem(
                    id: "conv-upgrade-go",
                    title: "Upgrade to Go 1.25",
                    statusLine: "Done · 6 files changed",
                    statusHighlight: .neutral,
                    projectSlug: "ledger-svc",
                    timestampLabel: "1h",
                    additions: 42,
                    deletions: 31,
                    indicator: .unreadDot,
                    isPinned: false,
                    isUnread: true,
                    isArchived: false
                ),
                AgentConversationItem(
                    id: "conv-idempotency-keys",
                    title: "Idempotency keys for payouts",
                    statusLine: "Done · Merged into main",
                    statusHighlight: .neutral,
                    projectSlug: "ledger-svc",
                    timestampLabel: "Yesterday",
                    additions: nil,
                    deletions: nil,
                    indicator: .none,
                    isPinned: false,
                    isUnread: false,
                    isArchived: false
                )
            ]
        ),
        AgentProjectSection(
            id: "web-console",
            slug: "web-console",
            subtitle: "Cloud · acme/web-console · main",
            isCloud: true,
            conversations: [
                AgentConversationItem(
                    id: "conv-web-console-csp",
                    title: "Audit CSP headers for checkout",
                    statusLine: "Running in cloud · Step 2 of 5",
                    statusHighlight: .running,
                    projectSlug: "web-console",
                    timestampLabel: "now",
                    additions: nil,
                    deletions: nil,
                    indicator: .runningArc,
                    isPinned: false,
                    isUnread: true,
                    isArchived: false
                )
            ]
        )
    ]

    private enum StandaloneModal: String, Identifiable {
        case displayOptions
        case newProject
        case contextMenu

        var id: String { rawValue }
    }

    public init(
        store: AntigravitySessionStore,
        onSelectTab: ((ShellTab) -> Void)? = nil,
        onOpenDisplayOptions: (() -> Void)? = nil,
        onOpenNewProject: (() -> Void)? = nil,
        onOpenProjectDetail: ((String) -> Void)? = nil,
        onOpenContextMenuPreview: (() -> Void)? = nil,
        onOpenConversation: ((String) -> Void)? = nil
    ) {
        self.store = store
        self.onSelectTab = onSelectTab
        self.onOpenDisplayOptions = onOpenDisplayOptions
        self.onOpenNewProject = onOpenNewProject
        self.onOpenProjectDetail = onOpenProjectDetail
        self.onOpenContextMenuPreview = onOpenContextMenuPreview
        self.onOpenConversation = onOpenConversation
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    topHeaderToolbar
                    heroTitleAndSearchSection
                    filterPillStrip
                    if !filteredPinnedItems.isEmpty {
                        pinnedSectionView
                    }
                    ForEach(filteredProjectSections) { project in
                        projectSectionView(project)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .refreshable {
                await store.refreshWorkspacesAndSummaries()
            }

            // Subtle bottom obsidian gradient behind floating liquid glass chrome
            LinearGradient(
                colors: [
                    AntigravityTheme.canvasObsidian.opacity(0.0),
                    AntigravityTheme.canvasObsidian.opacity(0.82),
                    AntigravityTheme.canvasObsidian
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 84)
            .allowsHitTesting(false)

            AntigravityFloatingTabBar(
                selectedTab: .agents,
                tabBarAccessibilityId: "floating-tab-bar",
                fabAccessibilityId: "fab-compose",
                onSelectTab: { tab in
                    onSelectTab?(tab)
                },
                onTapFAB: {
                    triggerOpenConversation("new-conversation")
                }
            )
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
        .sheet(item: $standaloneSheet) { modal in
            switch modal {
            case .displayOptions:
                DisplayOptionsSheetView(store: store, onDismiss: { standaloneSheet = nil })
            case .newProject:
                CreateProjectSheetView(store: store, onDismiss: { standaloneSheet = nil })
            case .contextMenu:
                ConversationContextPreviewMenu(store: store, onDismiss: { standaloneSheet = nil })
            }
        }
    }

    // MARK: - 1. Top Bar (Host Switcher + Display Options + New Project)

    private var topHeaderToolbar: some View {
        HStack(spacing: 8) {
            Menu {
                if store.isLiveBackendConnected {
                    Button {
                        Task {
                            await store.refreshWorkspacesAndSummaries()
                        }
                    } label: {
                        Label("Sync Desktop Sessions Now", systemImage: "arrow.clockwise")
                    }
                    Button {
                        onSelectTab?(.settings)
                    } label: {
                        Label("Host & Pairing Settings", systemImage: "qrcode.viewfinder")
                    }
                    Divider()
                } else {
                    Button {
                        onSelectTab?(.settings)
                    } label: {
                        Label("Pair Mac / Cloud Host...", systemImage: "qrcode.viewfinder")
                    }
                    Divider()
                }
                ForEach(HostFilterTarget.allCases) { target in
                    Button {
                        selectedHost = target
                    } label: {
                        Label(
                            target.rawValue,
                            systemImage: selectedHost == target ? "checkmark.circle.fill" : (target == .cloud ? "cloud" : "laptopcomputer")
                        )
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(selectedHost == .cloud ? AntigravityTheme.accentPeriwinkle : AntigravityTheme.statusDone)
                        .frame(width: 8, height: 8)
                    Text(store.isLiveBackendConnected ? store.activeHost.hostname : selectedHost.rawValue)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(UEChromePalette.textPrimary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(UEChromePalette.textSecondary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .background(
                    Capsule()
                        .fill(UEChromePalette.surfacePill)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("host-switcher-pill")

            Spacer()

            Button {
                if let onOpenDisplayOptions {
                    onOpenDisplayOptions()
                } else {
                    standaloneSheet = .displayOptions
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UEChromePalette.textPrimary)
                    .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                    .background(
                        Circle()
                            .fill(UEChromePalette.surfacePill)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-display-options")

            Button {
                if let onOpenNewProject {
                    onOpenNewProject()
                } else {
                    standaloneSheet = .newProject
                }
            } label: {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UEChromePalette.textPrimary)
                    .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                    .background(
                        Circle()
                            .fill(UEChromePalette.surfacePill)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-new-project")
        }
    }

    // MARK: - 2. Large Title & Search Conversations Input

    private var heroTitleAndSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Agents")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Color.white)

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(UEChromePalette.textMuted)

                TextField("Search conversations", text: $searchText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(UEChromePalette.textPrimary)
                    .tint(AntigravityTheme.accentPeriwinkle)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(UEChromePalette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(UEChromePalette.surfacePill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("agents-search-input")
        }
    }

    // MARK: - 3. Filter Pills Strip

    private var filterPillStrip: some View {
        let runningBadge = store.isLiveBackendConnected ? store.runningCount : 2
        let needsYouBadge = store.isLiveBackendConnected ? store.needsYouCount : 1
        let unreadBadge = store.isLiveBackendConnected ? store.unreadCount : 3

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPillButton(
                    filter: .all,
                    label: "All",
                    dotColor: nil,
                    accessibilityId: "filter-pill-all"
                )
                filterPillButton(
                    filter: .running,
                    label: "Running \(runningBadge)",
                    dotColor: AntigravityTheme.statusRunning,
                    accessibilityId: "filter-pill-running"
                )
                filterPillButton(
                    filter: .needsYou,
                    label: "Needs you \(needsYouBadge)",
                    dotColor: AntigravityTheme.statusWaiting,
                    accessibilityId: "filter-pill-needs-you"
                )
                filterPillButton(
                    filter: .unread,
                    label: "Unread \(unreadBadge)",
                    dotColor: nil,
                    accessibilityId: "filter-pill-unread"
                )
            }
        }
    }

    private func filterPillButton(
        filter: QuickStatusFilter,
        label: String,
        dotColor: Color?,
        accessibilityId: String
    ) -> some View {
        let isActive = (selectedFilter == filter)
        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 5) {
                if let dotColor {
                    Circle()
                        .fill(isActive ? AntigravityTheme.canvasObsidian : dotColor)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.system(size: 13.5, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? AntigravityTheme.canvasObsidian : UEChromePalette.textBody)
                    .lineLimit(1)
            }
            .padding(.horizontal, 11.5)
            .frame(minWidth: 44, minHeight: AntigravityTheme.minTouchTargetPt)
            .background(
                Capsule()
                    .fill(isActive ? Color.white : UEChromePalette.surfacePill)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? Color.clear : UEChromePalette.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }

    // MARK: - 4. Pinned Conversations Card

    private var pinnedSectionView: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(UEChromePalette.textMuted)
                Text("PINNED")
                    .font(.system(size: 11.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(UEChromePalette.textMuted)
            }
            .padding(.leading, 4)
            .padding(.top, 2)

            VStack(spacing: 0) {
                ForEach(Array(filteredPinnedItems.enumerated()), id: \.element.id) { index, item in
                    conversationRow(item: item, showProjectSlug: true)
                    if index < filteredPinnedItems.count - 1 {
                        Divider()
                            .overlay(UEChromePalette.subtleDivider)
                            .padding(.leading, 44)
                    }
                }
            }
            .background(AntigravityTheme.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pinned-section-card")
        }
    }

    // MARK: - 5. Collapsible Project Group Sections

    private func projectSectionView(_ project: AgentProjectSection) -> some View {
        let isCollapsed = collapsedProjects.contains(project.slug)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    triggerOpenProjectDetail(project.slug)
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(UEChromePalette.surfacePill)
                            .frame(width: 34, height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                            )
                            .overlay(
                                Image(systemName: project.isCloud ? "cloud" : "folder")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(UEChromePalette.textBody)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(project.slug)
                                .font(.system(size: 16.5, weight: .semibold))
                                .foregroundStyle(UEChromePalette.textPrimary)
                            Text(project.subtitle)
                                .font(.system(size: 12.5, weight: .regular))
                                .foregroundStyle(UEChromePalette.textMuted)
                        }
                    }
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-header-\(project.slug)")

                Spacer(minLength: 4)

                Button {
                    triggerOpenConversation("new-\(project.slug)")
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(UEChromePalette.textBody)
                        .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-add-conv-\(project.slug)")

                Button {
                    if isCollapsed {
                        collapsedProjects.remove(project.slug)
                    } else {
                        collapsedProjects.insert(project.slug)
                    }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UEChromePalette.textSecondary)
                        .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-collapse-\(project.slug)")
            }

            if !isCollapsed {
                VStack(spacing: 0) {
                    if project.conversations.isEmpty && store.isLiveBackendConnected {
                        Button {
                            triggerOpenConversation("new-\(project.slug)")
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.bubble")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                                Text("No conversations yet · Start one in \(project.slug)")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(UEChromePalette.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                        }
                        .buttonStyle(AntigravityInteractiveRowButtonStyle())
                        .accessibilityIdentifier("empty-project-conv-\(project.slug)")
                    } else {
                        ForEach(Array(project.conversations.enumerated()), id: \.element.id) { index, item in
                            conversationRow(item: item, showProjectSlug: false)
                            if index < project.conversations.count - 1 {
                                Divider()
                                    .overlay(UEChromePalette.subtleDivider)
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                )
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            project.slug == "ledger-svc" ? "project-group-ledger-svc" : "project-group-\(project.slug)"
        )
    }

    // MARK: - 6. Conversation Row with Full-Width Hit-Testing & Context Menu

    private func triggerOpenConversation(_ id: String) {
        if let onOpenConversation {
            onOpenConversation(id)
            return
        }
        if id == "new-conversation" || id.hasPrefix("new-") {
            let slug = id.hasPrefix("new-") && id != "new-conversation"
                ? String(id.dropFirst(4))
                : store.selectedProjectId
            _ = store.createConversationInProject(slug)
            return
        }
        store.selectCascade(id)
    }

    private func triggerOpenProjectDetail(_ slug: String) {
        if let onOpenProjectDetail {
            onOpenProjectDetail(slug)
        } else {
            store.selectProject(slug)
        }
    }

    private func conversationRow(item: AgentConversationItem, showProjectSlug: Bool) -> some View {
        Button {
            triggerOpenConversation(item.id)
        } label: {
            HStack(alignment: .center, spacing: 11) {
                HStack(alignment: .top, spacing: 11) {
                    leadingStatusIndicator(item.indicator)
                        .frame(width: 18, height: 20)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2.5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.title)
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundStyle(UEChromePalette.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(item.timestampLabel)
                                .font(.system(size: 12.5, weight: .regular))
                                .foregroundStyle(UEChromePalette.textMuted)
                        }

                        HStack(spacing: 5) {
                            Text(item.statusLine)
                                .font(.system(size: 13.5, weight: .regular))
                                .foregroundStyle(statusTextColor(for: item.statusHighlight))
                                .lineLimit(1)

                            if let add = item.additions, let del = item.deletions {
                                Text("+\(add)")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(AntigravityTheme.statusDone)
                                Text("−\(del)")
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(AntigravityTheme.statusError)
                            }
                        }

                        if showProjectSlug {
                            Text(item.projectSlug)
                                .font(.system(size: 12.5, weight: .regular))
                                .foregroundStyle(UEChromePalette.textMuted)
                        }
                    }
                }

                if store.isLiveBackendConnected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(UEChromePalette.textMuted.opacity(0.65))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
        }
        .buttonStyle(AntigravityInteractiveRowButtonStyle())
        .contextMenu {
            Button {
                togglePinConversation(id: item.id)
            } label: {
                Label(item.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }
            Button {
                toggleUnreadConversation(id: item.id)
            } label: {
                Label("Mark as Unread", systemImage: "circle.inset.filled")
            }
            Button {
                if let onOpenContextMenuPreview {
                    onOpenContextMenuPreview()
                } else {
                    standaloneSheet = .contextMenu
                }
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button {
                triggerOpenProjectDetail(item.projectSlug)
            } label: {
                Label("Move to Project", systemImage: "folder")
            }
            Divider()
            Button {
                archiveConversation(id: item.id)
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            Button(role: .destructive) {
                deleteConversation(id: item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityIdentifier("conv-row-\(item.id)")
    }

    @ViewBuilder
    private func leadingStatusIndicator(_ style: IndicatorStyle) -> some View {
        switch style {
        case .runningArc:
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
                    .rotationEffect(.degrees(-85))
            }
        case .needsReviewHalo:
            ZStack {
                Circle()
                    .fill(AntigravityTheme.statusWaiting.opacity(0.22))
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(AntigravityTheme.statusWaiting)
                    .frame(width: 8.5, height: 8.5)
            }
        case .unreadDot:
            ZStack {
                Circle()
                    .fill(AntigravityTheme.statusRunning.opacity(0.20))
                    .frame(width: 17, height: 17)
                Circle()
                    .fill(AntigravityTheme.statusRunning)
                    .frame(width: 8, height: 8)
            }
        case .none:
            Color.clear
                .frame(width: 15, height: 15)
        }
    }

    private func statusTextColor(for tone: AgentConversationItem.StatusTone) -> Color {
        switch tone {
        case .running: return AntigravityTheme.statusRunning
        case .waiting: return AntigravityTheme.statusWaiting
        case .neutral: return UEChromePalette.textSecondary
        }
    }

    // MARK: - Filtering & Live Store Binding

    private var usesLiveStoreData: Bool {
        store.isLiveBackendConnected || store.summaries.contains(where: { summary in
            ![
                "cas-rate-limiter",
                "cas-release-checklist",
                "cas-flaky-settlement",
                "cas-upgrade-go",
                "cas-idempotency-payouts",
                "cas-pgx-v5-migration",
                "cas-audit-csp-headers",
                "cas-audit-log-admin"
            ].contains(summary.cascadeId)
        })
    }

    private func mapStoreSummary(_ s: CascadeSummary) -> AgentConversationItem {
        let tone: AgentConversationItem.StatusTone
        let indicator: IndicatorStyle
        switch s.status {
        case .inProgress, .pending:
            tone = .running
            indicator = .runningArc
        case .waiting, .blocked:
            tone = .waiting
            indicator = .needsReviewHalo
        default:
            tone = .neutral
            indicator = s.isUnread ? .unreadDot : .none
        }
        return AgentConversationItem(
            id: s.cascadeId,
            title: s.title,
            statusLine: s.statusSubtitle.isEmpty ? (s.lastMessagePreview ?? s.status.displayBadgeText) : s.statusSubtitle,
            statusHighlight: tone,
            projectSlug: s.projectSlug,
            timestampLabel: s.relativeTimeLabel,
            additions: s.totalAdditions > 0 ? s.totalAdditions : nil,
            deletions: s.totalDeletions > 0 ? s.totalDeletions : nil,
            indicator: indicator,
            isPinned: s.isPinned,
            isUnread: s.isUnread,
            isArchived: s.isArchived
        )
    }

    private var filteredPinnedItems: [AgentConversationItem] {
        let source = usesLiveStoreData
            ? store.summaries.filter(\.isPinned).map(mapStoreSummary)
            : pinnedItems
        return source.filter { matchesFilters($0) }
    }

    private var filteredProjectSections: [AgentProjectSection] {
        let sourceSections: [AgentProjectSection]
        if usesLiveStoreData {
            sourceSections = store.projects.map { proj in
                let convs = store.summaries
                    .filter { !$0.isPinned && $0.projectSlug == proj.id }
                    .map(mapStoreSummary)
                return AgentProjectSection(
                    id: proj.id,
                    slug: proj.name,
                    subtitle: proj.homeSubtitle,
                    isCloud: proj.runtime == .cloud,
                    conversations: convs
                )
            }
        } else {
            sourceSections = projectSections
        }

        return sourceSections.compactMap { section in
            let filteredConvs = section.conversations.filter { matchesFilters($0) }
            if filteredConvs.isEmpty && !searchText.isEmpty {
                return nil
            }
            var copy = section
            copy.conversations = filteredConvs
            return copy
        }
    }

    private func matchesFilters(_ item: AgentConversationItem) -> Bool {
        guard !item.isArchived else { return false }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            let matchesTitle = item.title.lowercased().contains(query)
            let matchesProject = item.projectSlug.lowercased().contains(query)
            let matchesStatus = item.statusLine.lowercased().contains(query)
            if !matchesTitle && !matchesProject && !matchesStatus {
                return false
            }
        }

        switch selectedFilter {
        case .all:
            return true
        case .running:
            return item.statusHighlight == .running
        case .needsYou:
            return item.statusHighlight == .waiting
        case .unread:
            return item.isUnread
        }
    }

    private func togglePinConversation(id: String) {
        store.togglePinCascade(id)
        if let idx = pinnedItems.firstIndex(where: { $0.id == id }) {
            var removed = pinnedItems.remove(at: idx)
            removed.isPinned = false
            if let pIdx = projectSections.firstIndex(where: { $0.slug == removed.projectSlug }) {
                projectSections[pIdx].conversations.insert(removed, at: 0)
            }
            return
        }
        for pIdx in projectSections.indices {
            if let cIdx = projectSections[pIdx].conversations.firstIndex(where: { $0.id == id }) {
                var moved = projectSections[pIdx].conversations.remove(at: cIdx)
                moved.isPinned = true
                pinnedItems.insert(moved, at: 0)
                return
            }
        }
    }

    private func toggleUnreadConversation(id: String) {
        store.toggleUnreadCascade(id)
        for pIdx in projectSections.indices {
            if let cIdx = projectSections[pIdx].conversations.firstIndex(where: { $0.id == id }) {
                projectSections[pIdx].conversations[cIdx].isUnread.toggle()
                if projectSections[pIdx].conversations[cIdx].indicator == .none {
                    projectSections[pIdx].conversations[cIdx].indicator = .unreadDot
                }
                return
            }
        }
    }

    private func archiveConversation(id: String) {
        store.archiveCascade(id)
        if let idx = pinnedItems.firstIndex(where: { $0.id == id }) {
            pinnedItems[idx].isArchived = true
            return
        }
        for pIdx in projectSections.indices {
            if let cIdx = projectSections[pIdx].conversations.firstIndex(where: { $0.id == id }) {
                projectSections[pIdx].conversations[cIdx].isArchived = true
                return
            }
        }
    }

    private func deleteConversation(id: String) {
        store.deleteCascade(id)
        pinnedItems.removeAll { $0.id == id }
        for pIdx in projectSections.indices {
            projectSections[pIdx].conversations.removeAll { $0.id == id }
        }
    }
}
