import SwiftUI
import AntigravityData

/// State `S02_WORKSPACE_HOME`: Complete Session List (会话列表) view controller.
/// Features:
/// - Connected Host status pill (`lt74xt6l0m-golden-star · 18ms`) & Workspace switcher
/// - Liquid Glass real-time Search Bar (filters by title, branch, or pending command)
/// - Git Worktree horizontal filter strip (`All Branches`, `⎇ main`, `⎇ feat/connect-rpc-client`, `⎇ feat/live-activity`)
/// - Status category filter pills (`All`, `Waiting`, `Running`, `Pinned`, `Completed`)
/// - Pinned & Recent Conversation sections with inline `WAITING` quick-approve action, swipe-to-pin/archive/delete, and `New Cascade` creation.
public struct WorkspaceHomeViewController: View {
    @Bindable public var store: AntigravitySessionStore
    @State private var newCascadeTitle: String = ""
    @State private var newCascadePrompt: String = ""

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            topHostAndNewSessionBar
            workspaceSwitcherAndSearchBar
            worktreeFilterStrip
            statusCategoryStrip
            sessionListScrollView
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(AntigravityTheme.canvasObsidian)
        .sheet(item: $store.presentedSheet) { sheet in
            if case .newCascadeSheet = sheet {
                newCascadeModalView
            }
        }
    }

    // MARK: - 1. Top Host Status Pill & New Cascade Button

    private var topHostAndNewSessionBar: some View {
        HStack(spacing: 10) {
            Button {
                store.currentRoute = .pairingQR
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(store.activeHost.isOnline ? AntigravityTheme.statusDone : AntigravityTheme.statusError)
                        .frame(width: 8, height: 8)
                    Text("\(store.activeHost.hostname) · \(store.activeHost.latencyMs)ms")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                        .foregroundStyle(AntigravityTheme.inkLabel)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .antigravityGlass(cornerRadius: 22)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("host-status-pill")

            Spacer()

            Button {
                store.createNewCascade(
                    title: "New Agentic Cascade",
                    branchName: store.selectedWorktreeFilter ?? store.currentWorkspace?.activeBranch ?? "main"
                )
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("New Cascade")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                }
                .foregroundStyle(AntigravityTheme.inkReading)
                .padding(.horizontal, 14)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .background(AntigravityTheme.accentPrimary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-new-cascade")
        }
    }

    // MARK: - 2. Workspace Switcher & Search Bar

    private var workspaceSwitcherAndSearchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                ForEach(store.workspaces) { ws in
                    Button {
                        store.selectWorkspace(ws.workspaceUri)
                    } label: {
                        Label(
                            "\(ws.displayName) (\(ws.activeBranch))",
                            systemImage: ws.workspaceUri == store.selectedWorkspaceUri ? "checkmark.circle.fill" : "folder"
                        )
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.gearshape")
                        .foregroundStyle(AntigravityTheme.accentSecondary)
                    Text(store.currentWorkspace?.displayName ?? "venciallee/iOSAntigravity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                    Spacer()
                    if store.waitingApprovalCount > 0 {
                        Text("\(store.waitingApprovalCount) WAITING")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.statusWaiting)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AntigravityTheme.statusWaiting.opacity(0.16))
                            .clipShape(Capsule())
                    }
                }
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .accessibilityIdentifier("workspace-switcher-menu")

            // Search Input Box
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                TextField("Search conversations, branches, or commands...", text: $store.searchQuery)
                    .font(AntigravityTheme.TypographyTier.reading.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .accessibilityIdentifier("session-search-input")
                if !store.searchQuery.isEmpty {
                    Button {
                        store.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                            .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
            .background(AntigravityTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - 3. Git Worktree Filter Strip

    private var worktreeFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                worktreePill(title: "All Branches", branchValue: nil)
                ForEach(store.availableWorktrees, id: \.self) { branch in
                    worktreePill(title: "⎇ \(branch)", branchValue: branch)
                }
            }
        }
        .accessibilityIdentifier("worktree-filter-bar")
    }

    private func worktreePill(title: String, branchValue: String?) -> some View {
        let isSelected = store.selectedWorktreeFilter == branchValue
        return Button {
            store.selectedWorktreeFilter = branchValue
        } label: {
            Text(title)
                .font(AntigravityTheme.TypographyTier.metadata.font)
                .foregroundStyle(isSelected ? AntigravityTheme.inkReading : AntigravityTheme.inkLabel)
                .padding(.horizontal, 12)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .background(
                    isSelected
                        ? AntigravityTheme.accentPrimary.opacity(0.28)
                        : AntigravityTheme.surfaceCard
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. Status Category Filter Strip

    private var statusCategoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SessionFilterCategory.allCases) { category in
                    let isSelected = store.selectedFilterCategory == category
                    Button {
                        store.selectedFilterCategory = category
                    } label: {
                        Text(categoryLabel(for: category))
                            .font(AntigravityTheme.TypographyTier.chrome.font)
                            .foregroundStyle(isSelected ? AntigravityTheme.inkReading : AntigravityTheme.inkSecondary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(isSelected ? AntigravityTheme.surfaceElevated : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func categoryLabel(for category: SessionFilterCategory) -> String {
        switch category {
        case .all: return "All (\(store.summaries.filter { !$0.isArchived }.count))"
        case .waitingApproval: return "Waiting (\(store.waitingApprovalCount))"
        case .running: return "Running (\(store.runningCascadeCount))"
        case .pinned: return "Pinned (\(store.pinnedSummaries.count))"
        case .done: return "Completed"
        }
    }

    // MARK: - 5. Session List ScrollView (Pinned + Recent)

    private var sessionListScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if !store.pinnedSummaries.isEmpty {
                    Text("PINNED CASCADES")
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                        .padding(.top, 4)

                    ForEach(store.pinnedSummaries) { summary in
                        CascadeSummaryRowCard(
                            store: store,
                            summary: summary,
                            accessibilityId: summary.status == .waiting
                                ? "cascade-card-waiting"
                                : "cascade-card-running"
                        )
                    }
                }

                if !store.unpinnedSummaries.isEmpty {
                    Text("RECENT CASCADES")
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                        .padding(.top, 8)

                    ForEach(store.unpinnedSummaries) { summary in
                        CascadeSummaryRowCard(
                            store: store,
                            summary: summary,
                            accessibilityId: "cascade-card-\(summary.cascadeId)"
                        )
                    }
                }

                if store.filteredSummaries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 32))
                            .foregroundStyle(AntigravityTheme.inkMuted)
                        Text("No matching conversations")
                            .font(AntigravityTheme.TypographyTier.evidence.font)
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .refreshable {
            await store.refreshWorkspacesAndSummaries()
        }
    }

    // MARK: - 6. New Cascade Creation Sheet

    private var newCascadeModalView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start New Cascade")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AntigravityTheme.inkReading)

            TextField("Conversation title (optional)", text: $newCascadeTitle)
                .padding(12)
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            TextField("Initial task prompt...", text: $newCascadePrompt, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 12) {
                Button {
                    store.presentedSheet = nil
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    let title = newCascadeTitle.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "New Agentic Session"
                        : newCascadeTitle
                    store.createNewCascade(
                        title: title,
                        initialPrompt: newCascadePrompt.isEmpty ? nil : newCascadePrompt
                    )
                    store.presentedSheet = nil
                } label: {
                    Text("Launch Cascade")
                        .font(AntigravityTheme.TypographyTier.evidence.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .background(AntigravityTheme.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(20)
        .background(AntigravityTheme.canvasObsidian)
    }
}

/// Individual row card inside the Session List (`WorkspaceHomeViewController`).
public struct CascadeSummaryRowCard: View {
    @Bindable public var store: AntigravitySessionStore
    public let summary: CascadeSummary
    public let accessibilityId: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                store.selectCascade(summary.cascadeId)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        if summary.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AntigravityTheme.accentSecondary)
                        }
                        Text(summary.title)
                            .font(AntigravityTheme.TypographyTier.evidence.font)
                            .foregroundStyle(AntigravityTheme.inkReading)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        statusBadge
                    }

                    if let preview = summary.lastMessagePreview, !preview.isEmpty {
                        Text(preview)
                            .font(AntigravityTheme.TypographyTier.process.font)
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 10) {
                        Text("⎇ \(summary.branchName)")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.inkLabel)
                        Text("· \(summary.stepCount) steps")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                        if summary.totalAdditions > 0 || summary.totalDeletions > 0 {
                            Text("+\(summary.totalAdditions) -\(summary.totalDeletions)")
                                .font(AntigravityTheme.TypographyTier.metadata.font)
                                .foregroundStyle(AntigravityTheme.statusDone)
                        }
                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)

            // Inline Quick Action Bar when a session is WAITING for user permission
            if summary.status == .waiting, let pendingTitle = summary.pendingInteractionTitle {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(AntigravityTheme.statusWaiting)
                    Text(pendingTitle)
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.inkLabel)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        store.selectCascade(summary.cascadeId)
                        if let waitingStep = store.pendingWaitingStep {
                            store.resolveWaitingStep(stepIndex: waitingStep.stepIndex, decision: .allowOnce)
                        }
                    } label: {
                        Text("Approve")
                            .font(AntigravityTheme.TypographyTier.chrome.font)
                            .foregroundStyle(AntigravityTheme.inkReading)
                            .padding(.horizontal, 12)
                            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.accentPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .frame(minHeight: 72)
        .background(
            summary.cascadeId == store.activeCascadeId
                ? AntigravityTheme.surfaceElevated
                : AntigravityTheme.surfaceCard
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button {
                store.togglePinCascade(summary.cascadeId)
            } label: {
                Label(summary.isPinned ? "Unpin Cascade" : "Pin Cascade", systemImage: summary.isPinned ? "pin.slash" : "pin")
            }
            Button {
                store.archiveCascade(summary.cascadeId)
            } label: {
                Label("Archive Cascade", systemImage: "archivebox")
            }
            Button(role: .destructive) {
                store.deleteCascade(summary.cascadeId)
            } label: {
                Label("Delete Cascade", systemImage: "trash")
            }
        }
        .accessibilityIdentifier(accessibilityId)
    }

    private var statusBadge: some View {
        let color: Color = {
            switch summary.status {
            case .waiting: return AntigravityTheme.statusWaiting
            case .inProgress, .pending: return AntigravityTheme.statusRunning
            case .done: return AntigravityTheme.statusDone
            case .error, .cancelled, .blocked: return AntigravityTheme.statusError
            case .unspecified: return AntigravityTheme.inkSecondary
            }
        }()

        return Text(summary.status.displayBadgeText)
            .font(AntigravityTheme.TypographyTier.metadata.font)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
    }
}
