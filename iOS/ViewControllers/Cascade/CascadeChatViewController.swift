import SwiftUI
import AntigravityData

/// State `S03_CASCADE_STREAMING`: Complete Message List (消息列表) view controller.
/// Features:
/// - Top navigation bar with Back to Session List, conversation title, branch badge, Artifacts button, and Turn Diff button
/// - Sticky `TaskBoundary` progress banner with completion bar (`4/5 · 80%`)
/// - Grouped & virtualized `ScrollViewReader` message list supporting `CascadeDisplayItem`
///   (`.single(CascadeStep)` and collapsible `.evidenceGroup(id:steps:)`)
/// - Floating quick-jump pill for `WAITING` permission gates or latest streaming delta
/// - Pinned Liquid Glass `ChatComposerView` input bar at the bottom.
public struct CascadeChatViewController: View {
    @Bindable public var store: AntigravitySessionStore
    @State private var isTaskBoundarySummaryExpanded: Bool = false

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            chatTopNavigationBar

            if let tb = store.activeTaskBoundary {
                taskBoundaryHeaderBanner(tb)
            }

            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(store.displayItems) { item in
                                switch item {
                                case .single(let step):
                                    CascadeStepCellView(store: store, step: step)
                                        .id(step.id)
                                case .evidenceGroup(let groupId, let groupedSteps):
                                    CascadeEvidenceGroupCardView(
                                        store: store,
                                        groupId: groupId,
                                        steps: groupedSteps
                                    )
                                    .id(groupId)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .onChange(of: store.activeSteps.count) { _, _ in
                        if store.isAutoScrollPinnedToBottom, let lastId = store.displayItems.last?.id {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        } else {
                            store.unreadStreamingStepCount += 1
                        }
                    }
                }

                // Floating Jump Pill when a step is WAITING or user scrolled up during streaming
                if let waitingStep = store.pendingWaitingStep {
                    floatingWaitingGatePill(waitingStep: waitingStep)
                        .padding(.bottom, 10)
                } else if store.unreadStreamingStepCount > 0 {
                    floatingUnreadStepsPill
                        .padding(.bottom, 10)
                }
            }

            ChatComposerView(store: store)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
        .background(AntigravityTheme.canvasObsidian)
    }

    // MARK: - 1. Top Navigation Bar

    private var chatTopNavigationBar: some View {
        HStack(spacing: 10) {
            Button {
                store.currentRoute = .workspaceHome
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Cascades")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                }
                .foregroundStyle(AntigravityTheme.inkLabel)
                .padding(.horizontal, 10)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .background(AntigravityTheme.surfaceCard)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-back-sessions")

            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeSummary?.title ?? "Active Cascade")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("⎇ \(store.activeSummary?.branchName ?? "main")")
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.accentSecondary)
                    Text("· \(store.activeSteps.count) steps")
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                }
            }

            Spacer()

            // Artifact Review Inspector Button
            Button {
                store.currentRoute = .artifactInspector
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                    Text("\(store.activeArtifacts.count)")
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                }
                .foregroundStyle(AntigravityTheme.inkLabel)
                .padding(.horizontal, 10)
                .frame(minWidth: AntigravityTheme.minTouchTargetPt, minHeight: AntigravityTheme.minTouchTargetPt)
                .background(AntigravityTheme.surfaceCard)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-open-artifacts")

            // Turn Diff Inspector Button
            Button {
                store.currentRoute = .turnDiffInspector
            } label: {
                let totalAdd = store.activeTurnDiffs.reduce(0) { $0 + $1.additions }
                let totalDel = store.activeTurnDiffs.reduce(0) { $0 + $1.deletions }
                Text("+\(totalAdd) -\(totalDel)")
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.statusDone)
                    .padding(.horizontal, 10)
                    .frame(minWidth: AntigravityTheme.minTouchTargetPt, minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(AntigravityTheme.surfaceCard)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-open-turn-diff")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AntigravityTheme.surfaceObsidian)
    }

    // MARK: - 2. Sticky TaskBoundary Progress Banner

    private func taskBoundaryHeaderBanner(_ tb: TaskBoundaryPayload) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isTaskBoundarySummaryExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AntigravityTheme.statusRunning)
                            .frame(width: 7, height: 7)
                        Text(tb.taskName)
                            .font(AntigravityTheme.TypographyTier.evidence.font)
                            .foregroundStyle(AntigravityTheme.inkReading)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(tb.completedItems)/\(tb.totalItems) · \(Int(tb.progressFraction * 100))%")
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.accentSecondary)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AntigravityTheme.surfaceCard)
                            .frame(height: 5)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AntigravityTheme.accentPrimary, AntigravityTheme.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(12, geo.size.width * tb.progressFraction), height: 5)
                    }
                }
                .frame(height: 5)

                Text(tb.taskStatus)
                    .font(AntigravityTheme.TypographyTier.process.font)
                    .foregroundStyle(AntigravityTheme.statusRunning)
                    .lineLimit(1)

                if isTaskBoundarySummaryExpanded {
                    Text(tb.taskSummary)
                        .font(AntigravityTheme.TypographyTier.process.font)
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AntigravityTheme.surfaceElevated)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("task-boundary-banner")
    }

    // MARK: - 3. Floating Waiting Gate & Unread Pills

    private func floatingWaitingGatePill(waitingStep: CascadeStep) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AntigravityTheme.statusWaiting)
            Text("Step #\(waitingStep.stepIndex) waiting for approval")
                .font(AntigravityTheme.TypographyTier.chrome.font)
                .foregroundStyle(AntigravityTheme.inkReading)
            Button {
                store.resolveWaitingStep(stepIndex: waitingStep.stepIndex, decision: .allowOnce)
            } label: {
                Text("Approve Now")
                    .font(AntigravityTheme.TypographyTier.chrome.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .padding(.horizontal, 12)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(AntigravityTheme.accentPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .antigravityGlass(cornerRadius: 24, isHighlighted: true)
        .accessibilityIdentifier("floating-waiting-gate-pill")
    }

    private var floatingUnreadStepsPill: some View {
        Button {
            store.unreadStreamingStepCount = 0
            store.isAutoScrollPinnedToBottom = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                Text("\(store.unreadStreamingStepCount) new streaming steps")
                    .font(AntigravityTheme.TypographyTier.chrome.font)
            }
            .foregroundStyle(AntigravityTheme.inkReading)
            .padding(.horizontal, 14)
            .frame(minHeight: AntigravityTheme.minTouchTargetPt)
            .antigravityGlass(cornerRadius: 22, isHighlighted: true)
        }
        .buttonStyle(.plain)
    }
}
