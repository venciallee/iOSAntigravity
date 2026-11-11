import SwiftUI
import AntigravityData

/// State `UE04_PROJECT_DETAIL`: Project Page & New Conversation in Project (`ledger-svc`).
/// Matches `/home/antigravity/iOS_·_项目页_New_Conversation_in_Project.png` 1:1.
public struct ProjectDetailViewController: View {
    @Bindable public var store: AntigravitySessionStore
    public let projectSlug: String
    public var onBack: (() -> Void)?
    public var onOpenConversation: ((String) -> Void)?

    public enum ProjectDetailTab: String, CaseIterable, Identifiable {
        case active
        case archived
        case automations

        public var id: String { rawValue }
    }

    private struct ProjectConversationRowModel: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let timestamp: String
        let indicator: IndicatorKind
        let additions: Int?
        let deletions: Int?

        enum IndicatorKind {
            case runningArc
            case needsReviewHalo
            case unreadDot
            case none
        }
    }

    @State private var selectedTab: ProjectDetailTab = .active
    @State private var finderFeedbackBanner: Bool = false

    private let activeRows: [ProjectConversationRowModel] = [
        ProjectConversationRowModel(
            id: "proj-conv-rate-limiter",
            title: "Add rate limiter to /transfers",
            subtitle: "Running · Step 4 of 7",
            timestamp: "now",
            indicator: .runningArc,
            additions: nil,
            deletions: nil
        ),
        ProjectConversationRowModel(
            id: "proj-conv-flaky-batch",
            title: "Fix flaky TestSettlementBatch",
            subtitle: "Needs review · Implementation plan ready",
            timestamp: "8m",
            indicator: .needsReviewHalo,
            additions: nil,
            deletions: nil
        ),
        ProjectConversationRowModel(
            id: "proj-conv-upgrade-go",
            title: "Upgrade to Go 1.25",
            subtitle: "Done · 6 files",
            timestamp: "1h",
            indicator: .unreadDot,
            additions: 42,
            deletions: 31
        )
    ]

    private let archivedRows: [ProjectConversationRowModel] = [
        ProjectConversationRowModel(
            id: "proj-conv-idempotency",
            title: "Idempotency keys for payouts",
            subtitle: "Done · Merged into main",
            timestamp: "Yesterday",
            indicator: .none,
            additions: 88,
            deletions: 12
        ),
        ProjectConversationRowModel(
            id: "proj-conv-webhook-sig",
            title: "Rotate HMAC webhook verifier",
            subtitle: "Done · Merged into main",
            timestamp: "4d",
            indicator: .none,
            additions: 34,
            deletions: 9
        )
    ]

    public init(
        store: AntigravitySessionStore,
        projectSlug: String = "ledger-svc",
        onBack: (() -> Void)? = nil,
        onOpenConversation: ((String) -> Void)? = nil
    ) {
        self.store = store
        self.projectSlug = projectSlug
        self.onBack = onBack
        self.onOpenConversation = onOpenConversation
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                topNavigationBar
                projectHeroSection
                metadataPillsRow
                newConversationButton
                underlineTabsStrip
                tabBodyContent
                thisProjectSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
    }

    // MARK: - 1. Top Navigation (< Agents + More Menu)

    private var topNavigationBar: some View {
        HStack {
            Button {
                if let onBack {
                    onBack()
                } else {
                    store.activeRoute = .tabRoot
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Agents")
                        .font(.system(size: 17, weight: .regular))
                }
                .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                .frame(minWidth: 76, minHeight: AntigravityTheme.minTouchTargetPt, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-back-agents")

            Spacer()

            Menu {
                Button {
                    finderFeedbackBanner = true
                    store.revealProjectInFinder(projectSlug)
                } label: {
                    Label("Reveal in Finder on Mac", systemImage: "laptopcomputer")
                }
                Button {} label: {
                    Label("Switch Git Branch (\(effectiveBranchName))", systemImage: "arrow.triangle.branch")
                }
                Button {} label: {
                    Label("Project Rules & Skills", systemImage: "doc.text")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
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
            .accessibilityIdentifier("btn-project-more")
        }
    }

    private var usesPairedStoreData: Bool {
        store.hasPairedBackend || store.isLiveBackendConnected
    }

    private var isPairedHostOnline: Bool {
        !store.hasPairedBackend || (store.isLiveBackendConnected && store.activeHost.isOnline)
    }

    private var liveProject: ProjectWorkspace? {
        store.projects.first(where: { $0.id == projectSlug || $0.name == projectSlug })
    }

    private var effectivePathDisplay: String {
        guard usesPairedStoreData else { return "~/code/\(projectSlug)" }
        let raw = liveProject?.pathDisplay ?? "~/workspace/\(projectSlug)"
        if raw.hasPrefix("/Users/") {
            let parts = raw.split(separator: "/", omittingEmptySubsequences: true)
            if parts.count >= 2 {
                let tail = parts.dropFirst(2).joined(separator: "/")
                return tail.isEmpty ? "~" : "~/\(tail)"
            }
        }
        return raw
    }

    private var effectiveHostBadgeDotColor: Color {
        guard usesPairedStoreData else { return AntigravityTheme.statusDone }
        if liveProject?.runtime == .cloud {
            return AntigravityTheme.accentPeriwinkle
        }
        return isPairedHostOnline ? AntigravityTheme.statusDone : AntigravityTheme.statusError
    }

    private var effectiveHostBadgeText: String {
        guard usesPairedStoreData else { return "Local · MacBook Pro" }
        if liveProject?.runtime == .cloud {
            if let uri = liveProject?.workspaceUri,
               let cloudLabel = AntigravityCloudDetector.extractCloudLocationLabel(uri),
               cloudLabel.caseInsensitiveCompare(liveProject?.name ?? projectSlug) != .orderedSame {
                return "Cloud · \(cloudLabel)"
            }
            return "Cloud"
        }
        let prefix = isPairedHostOnline ? "Local" : "Offline"
        return "\(prefix) · \(store.activeHost.hostname)"
    }

    private var effectiveBranchName: String {
        guard usesPairedStoreData else { return "main" }
        return liveProject?.activeBranch ?? "main"
    }

    private func mapLiveSummaryToRow(_ s: CascadeSummary) -> ProjectConversationRowModel {
        let indicator: ProjectConversationRowModel.IndicatorKind
        switch s.status {
        case .inProgress, .pending:
            indicator = .runningArc
        case .waiting, .blocked:
            indicator = .needsReviewHalo
        default:
            indicator = s.isUnread ? .unreadDot : .none
        }
        return ProjectConversationRowModel(
            id: s.cascadeId,
            title: s.title,
            subtitle: s.statusSubtitle.isEmpty ? s.status.displayBadgeText : s.statusSubtitle,
            timestamp: s.relativeTimeLabel,
            indicator: indicator,
            additions: s.totalAdditions > 0 ? s.totalAdditions : nil,
            deletions: s.totalDeletions > 0 ? s.totalDeletions : nil
        )
    }

    private var effectiveActiveRows: [ProjectConversationRowModel] {
        guard usesPairedStoreData else { return activeRows }
        return store.summaries
            .filter { ($0.projectSlug == projectSlug || $0.projectSlug == liveProject?.id) && !$0.isArchived }
            .map(mapLiveSummaryToRow)
    }

    private var effectiveArchivedRows: [ProjectConversationRowModel] {
        guard usesPairedStoreData else { return archivedRows }
        return store.summaries
            .filter { ($0.projectSlug == projectSlug || $0.projectSlug == liveProject?.id) && $0.isArchived }
            .map(mapLiveSummaryToRow)
    }

    private var effectiveProjectAutomations: [AutomationItem] {
        store.automations.filter { $0.projectSlug == projectSlug || $0.projectSlug == liveProject?.name }
    }

    // MARK: - 2. Hero Header ([Folder] ledger-svc + ~/code/ledger-svc)

    private var projectHeroSection: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(UEChromePalette.surfacePill)
                .frame(width: 56, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                )
                .overlay(
                    Image(systemName: (usesPairedStoreData && liveProject?.runtime == .cloud) ? "cloud" : "folder")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(UEChromePalette.textBody)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(liveProject?.name ?? projectSlug)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(Color.white)
                    .accessibilityIdentifier("project-hero-title")

                Text(effectivePathDisplay)
                    .font(.system(size: 13.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(UEChromePalette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
    }

    // MARK: - 3. Metadata Pills

    private var metadataPillsRow: some View {
        let totalConvCount = usesPairedStoreData
            ? (effectiveActiveRows.count + effectiveArchivedRows.count)
            : 5
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(effectiveHostBadgeDotColor)
                        .frame(width: 7, height: 7)
                    Text(effectiveHostBadgeText)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(UEChromePalette.textBody)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Capsule().fill(UEChromePalette.surfacePill))
                .overlay(Capsule().strokeBorder(UEChromePalette.cardBorder, lineWidth: 1))

                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(UEChromePalette.textSecondary)
                    Text(effectiveBranchName)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(UEChromePalette.textBody)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Capsule().fill(UEChromePalette.surfacePill))
                .overlay(Capsule().strokeBorder(UEChromePalette.cardBorder, lineWidth: 1))

                Text("\(totalConvCount) conversations")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(UEChromePalette.textBody)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(UEChromePalette.surfacePill))
                    .overlay(Capsule().strokeBorder(UEChromePalette.cardBorder, lineWidth: 1))
            }
        }
    }

    private func triggerOpenConversation(_ id: String) {
        if let onOpenConversation {
            onOpenConversation(id)
            return
        }
        if id == "new-conversation" || id.hasPrefix("new-") {
            _ = store.createConversationInProject(projectSlug)
            return
        }
        store.selectCascade(id)
    }

    // MARK: - 4. Full-Width Periwinkle CTA

    private var newConversationButton: some View {
        Button {
            triggerOpenConversation("new-\(projectSlug)")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 15.5, weight: .semibold))
                Text("New Conversation in Project")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(UEChromePalette.inkOnPrimaryCTA)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AntigravityTheme.accentPeriwinkle)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("btn-new-conv-in-project")
    }

    // MARK: - 5. Active / Archived / Automations Underline Tabs

    private var underlineTabsStrip: some View {
        let activeCountText = store.isLiveBackendConnected ? "\(effectiveActiveRows.count)" : "3"
        let archivedCountText = store.isLiveBackendConnected ? "\(effectiveArchivedRows.count)" : "2"
        let autoCountText = store.isLiveBackendConnected ? "\(effectiveProjectAutomations.count)" : "1"
        return VStack(spacing: 0) {
            HStack(spacing: 18) {
                underlineTabItem(
                    tab: .active,
                    title: "Active",
                    count: activeCountText,
                    accessibilityId: "project-tab-active"
                )
                underlineTabItem(
                    tab: .archived,
                    title: "Archived",
                    count: archivedCountText,
                    accessibilityId: "project-tab-archived"
                )
                underlineTabItem(
                    tab: .automations,
                    title: "Automations",
                    count: autoCountText,
                    accessibilityId: "project-tab-automations"
                )
                Spacer(minLength: 0)
            }
            Rectangle()
                .fill(UEChromePalette.cardBorder)
                .frame(height: 1)
        }
    }

    private func underlineTabItem(
        tab: ProjectDetailTab,
        title: String,
        count: String,
        accessibilityId: String
    ) -> some View {
        let isSelected = (selectedTab == tab)
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Color.white : UEChromePalette.textMuted)
                        .lineLimit(1)
                    Text(count)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(isSelected ? UEChromePalette.textSecondary : UEChromePalette.textMuted)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.top, 8)

                Rectangle()
                    .fill(isSelected ? Color.white : Color.clear)
                    .frame(height: 2)
            }
            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }

    // MARK: - 6. Project Conversations Card

    @ViewBuilder
    private var tabBodyContent: some View {
        let rows: [ProjectConversationRowModel] = (selectedTab == .archived) ? effectiveArchivedRows : effectiveActiveRows
        if store.isLiveBackendConnected && selectedTab == .automations {
            VStack(alignment: .leading, spacing: 0) {
                if effectiveProjectAutomations.isEmpty {
                    Text("No automations configured for \(projectSlug) yet.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(effectiveProjectAutomations) { auto in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(auto.title)
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundStyle(Color.white)
                            Text("\(auto.scheduleSummary) · \(auto.lastRunText)")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(UEChromePalette.textSecondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AntigravityTheme.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("project-conv-list")
        } else if store.isLiveBackendConnected && rows.isEmpty {
            Text(selectedTab == .archived ? "No archived conversations in \(projectSlug)." : "No active conversations in \(projectSlug).")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(UEChromePalette.textSecondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AntigravityTheme.surfaceCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("project-conv-list")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Button {
                        triggerOpenConversation(row.id)
                    } label: {
                        HStack(alignment: .center, spacing: 11) {
                            HStack(alignment: .top, spacing: 11) {
                                rowIndicator(row.indicator)
                                    .frame(width: 18, height: 20)
                                    .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(row.title)
                                            .font(.system(size: 15.5, weight: .semibold))
                                            .foregroundStyle(Color.white)
                                            .lineLimit(1)
                                        Spacer()
                                        if row.indicator == .runningArc {
                                            AntigravityFourDotLoadingView(isAnimated: store.isLiveBackendConnected)
                                                .accessibilityElement(children: .ignore)
                                                .accessibilityLabel("Running")
                                                .accessibilityIdentifier("loading-four-dots-\(row.id)")
                                        } else {
                                            Text(row.timestamp)
                                                .font(.system(size: 12.5, weight: .regular))
                                                .foregroundStyle(UEChromePalette.textMuted)
                                        }
                                    }

                                    HStack(spacing: 5) {
                                        Text(row.subtitle)
                                            .font(.system(size: 13.5, weight: .regular))
                                            .foregroundStyle(subtitleColor(for: row.indicator))
                                            .lineLimit(1)

                                        if let add = row.additions, let del = row.deletions {
                                            Text("+\(add)")
                                                .font(.system(size: 13.5, weight: .medium))
                                                .foregroundStyle(AntigravityTheme.statusDone)
                                            Text("−\(del)")
                                                .font(.system(size: 13.5, weight: .medium))
                                                .foregroundStyle(AntigravityTheme.statusError)
                                        }
                                    }
                                }
                            }

                            if store.isLiveBackendConnected && row.indicator != .runningArc {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(UEChromePalette.textMuted.opacity(0.65))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(minHeight: 58)
                    }
                    .buttonStyle(AntigravityInteractiveRowButtonStyle())
                    .accessibilityIdentifier("project-conv-row-\(row.id)")

                    if index < rows.count - 1 {
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
            .accessibilityIdentifier("project-conv-list")
        }
    }

    @ViewBuilder
    private func rowIndicator(_ kind: ProjectConversationRowModel.IndicatorKind) -> some View {
        switch kind {
        case .runningArc:
            AntigravityRunningArcIndicatorView(isAnimated: store.isLiveBackendConnected)
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
            Color.clear.frame(width: 15, height: 15)
        }
    }

    private func subtitleColor(for kind: ProjectConversationRowModel.IndicatorKind) -> Color {
        switch kind {
        case .runningArc:      return AntigravityTheme.statusRunning
        case .needsReviewHalo: return AntigravityTheme.statusWaiting
        case .unreadDot, .none: return UEChromePalette.textSecondary
        }
    }

    // MARK: - 7. THIS PROJECT Section

    private var thisProjectSection: some View {
        let firstAuto = effectiveProjectAutomations.first
        return VStack(alignment: .leading, spacing: 8) {
            Text("THIS PROJECT")
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(UEChromePalette.textMuted)
                .padding(.leading, 2)
                .padding(.top, 2)

            VStack(spacing: 0) {
                Button {
                    selectedTab = .automations
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(UEChromePalette.textSecondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(usesPairedStoreData ? (firstAuto?.title ?? "Project automations") : "Nightly dependency audit")
                                .font(.system(size: 15.5, weight: .medium))
                                .foregroundStyle(UEChromePalette.textPrimary)
                            Text(usesPairedStoreData ? (firstAuto?.scheduleSummary ?? "0 active · Tap to inspect") : "Daily 02:00 · Next run in 6h")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(UEChromePalette.textMuted)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(UEChromePalette.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-row-automation")

                Divider()
                    .overlay(UEChromePalette.subtleDivider)
                    .padding(.leading, 48)

                Button {
                    finderFeedbackBanner = true
                    store.revealProjectInFinder(projectSlug)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "laptopcomputer")
                            .font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(UEChromePalette.textSecondary)
                            .frame(width: 22)

                        Text(finderFeedbackBanner ? "Opened in Finder on \(usesPairedStoreData ? store.activeHost.hostname : "MacBook Pro")" : "Reveal in Finder on Mac")
                            .font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(UEChromePalette.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-row-finder")

                Divider()
                    .overlay(UEChromePalette.subtleDivider)
                    .padding(.leading, 48)

                Button {} label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc")
                            .font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(UEChromePalette.textSecondary)
                            .frame(width: 22)

                        Text("Project rules & skills")
                            .font(.system(size: 15.5, weight: .medium))
                            .foregroundStyle(UEChromePalette.textPrimary)

                        Spacer()

                        Text("4")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(UEChromePalette.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-row-skills")
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AntigravityTheme.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
            )
        }
    }
}
