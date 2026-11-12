import SwiftUI
import AntigravityData

/// State `UE07_CHAT_AND_COMPOSER`: Official Message List, 7-Segment Task Card, Face ID Command Gate & Composer (`iOS · 消息列表与输入框`).
/// Dynamically renders live `store.displayItems` (`CascadeStepCellView` / `CascadeEvidenceGroupCardView`)
/// for newly created sessions, sent messages, and live Connect-RPC streaming turns while preserving
/// exact 1:1 `UE07` showcase rendering on the `cas-rate-limiter` ESDD fixture.
public struct CascadeChatViewController: View {
    @Bindable public var store: AntigravitySessionStore
    public var onBack: (() -> Void)?
    @State private var isTurnStopped: Bool = false

    private static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    private static let warmAmber = Color(red: 0xEB / 255.0, green: 0xB3 / 255.0, blue: 0x65 / 255.0) // #EBB365
    private static let emeraldDone = Color(red: 0x57 / 255.0, green: 0xC8 / 255.0, blue: 0x8A / 255.0) // #57C88A
    private static let coralError = Color(red: 0xF0 / 255.0, green: 0x71 / 255.0, blue: 0x67 / 255.0) // #F07167
    private static let pillBg = Color(red: 0x1A / 255.0, green: 0x1C / 255.0, blue: 0x23 / 255.0)

    public init(
        store: AntigravitySessionStore,
        onBack: (() -> Void)? = nil
    ) {
        self.store = store
        self.onBack = onBack
    }

    private var isStaticESDDFixtureView: Bool {
        store.isVerificationMode
            && !store.hasPairedBackend
            && !store.isLiveBackendConnected
            && store.activeCascadeId == "cas-rate-limiter"
            && store.activeSteps.count == 6
    }

    private var activeProjectWorkspace: ProjectWorkspace? {
        if let slug = store.activeSummary?.projectSlug {
            return store.projects.first(where: { $0.id == slug || $0.name == slug })
        }
        return store.selectedProject
    }

    private var isActiveSessionCloud: Bool {
        store.activeSummary?.isCloud == true || activeProjectWorkspace?.runtime == .cloud
    }

    private var effectiveHeaderHostLabel: String {
        if isActiveSessionCloud {
            return (store.hasPairedBackend || store.isLiveBackendConnected) ? "Antigravity" : "Cloud"
        }
        let hostTitle = store.activeSummary?.originHostName ?? store.activeHost.hostname
        if store.hasPairedBackend && (!store.isLiveBackendConnected || !store.activeHost.isOnline) {
            return "\(hostTitle) · Offline"
        }
        return hostTitle
    }

    private var shouldAnimateLive: Bool {
        !store.isVerificationMode || store.isLiveBackendConnected
    }

    private var streamingFollowSignature: Int {
        let lastStep = store.activeSteps.last
        let proseLen = lastStep?.plannerResponse?.response.count ?? 0
        let thoughtLen = lastStep?.plannerResponse?.thinking?.count ?? 0
        let statusRaw = lastStep?.status.rawValue ?? 0
        return (store.activeSteps.count &* 1_000_003) &+ (proseLen &* 31) &+ (thoughtLen &* 7) &+ statusRaw
    }

    public var body: some View {
        VStack(spacing: 0) {
            chatTopNavigationBar

            Divider()
                .overlay(Color.white.opacity(0.06))

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 9) {
                        if isStaticESDDFixtureView {
                            staticRateLimiterShowcaseBody
                        } else if store.displayItems.isEmpty {
                            emptyOrLoadingSessionCard
                        } else {
                            ForEach(store.displayItems) { item in
                                switch item {
                                case .single(let step):
                                    CascadeStepCellView(store: store, step: step)
                                case .evidenceGroup(let groupId, let groupedSteps):
                                    CascadeEvidenceGroupCardView(
                                        store: store,
                                        groupId: groupId,
                                        steps: groupedSteps
                                    )
                                }
                            }

                            if store.isCascadeStreaming || store.activeSummary?.status == .inProgress || store.activeSummary?.status == .pending {
                                HStack(spacing: 10) {
                                    AntigravityFourDotLoadingView(
                                        isAnimated: shouldAnimateLive,
                                        dotSize: 4.5,
                                        spacing: 3.5,
                                        tint: Self.periwinkle
                                    )
                                    Text("Agent is thinking and executing steps...")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundStyle(AntigravityTheme.inkSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AntigravityTheme.surfaceCard.opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .accessibilityIdentifier("chat-inline-four-dot-loading")
                            }
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("chat-bottom-anchor")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .onChange(of: streamingFollowSignature) { _, _ in
                    guard !isStaticESDDFixtureView, store.isAutoScrollPinnedToBottom else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrollProxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
                    }
                }
            }

            if !store.displayItems.isEmpty, let errText = store.stepLoadErrorText {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Self.coralError)
                        .frame(width: 7, height: 7)
                    Text(errText)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Self.coralError)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button("Dismiss") {
                        store.stepLoadErrorText = nil
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Self.periwinkle)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.top, 4)
            }

            // Above-Composer Status Strip
            if isStaticESDDFixtureView || store.isCascadeStreaming || store.pendingWaitingStep != nil || store.activeSummary?.status == .inProgress {
                waitingStatusStrip
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
            }

            // Pinned Composer Card
            ChatComposerView(store: store)
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 6)
        }
        .background(AntigravityTheme.canvasObsidian)
        .onChange(of: store.isCascadeStreaming) { _, streaming in
            if streaming {
                isTurnStopped = false
            }
        }
        .task(id: store.activeCascadeId) {
            isTurnStopped = false
            if (store.hasPairedBackend || store.isLiveBackendConnected) && !store.activeCascadeId.isEmpty {
                store.syncStepsForCascade(store.activeCascadeId, pollUntilIdle: true)
            }
        }
    }

    @ViewBuilder
    private var staticRateLimiterShowcaseBody: some View {
        UserPromptContextBubbleView(
            promptText: nil,
            contextChips: ["@transfers.go", "Skill · go-testing"]
        )

        CollapsibleThoughtRowView(durationSeconds: 14)

        Text("Plan approved with your 2 comments. Tests pass — next is a load test, which needs your OK.")
            .font(.system(size: 15))
            .foregroundStyle(AntigravityTheme.inkReading)
            .lineSpacing(2.5)
            .fixedSize(horizontal: false, vertical: true)

        EmbeddedImplementationPlanCardView(
            title: "Implementation Plan",
            statusSubtitle: "Approved · 2 comments addressed"
        ) {
            store.currentRoute = .planReview
        }

        SevenSegmentTaskProgressCardView(
            completedCount: 4,
            totalCount: 7,
            elapsedLabel: "2m 41s"
        )

        InlineCommandApprovalCardView(store: store)
    }

    @ViewBuilder
    private var emptyOrLoadingSessionCard: some View {
        if (store.hasPairedBackend || store.isLiveBackendConnected) && store.isLoadingSteps {
            HStack(spacing: 12) {
                AntigravityFourDotLoadingView(
                    isAnimated: shouldAnimateLive,
                    dotSize: 4.5,
                    spacing: 3.5,
                    tint: Self.periwinkle
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Loading conversation history...")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                    Text("Syncing trajectory steps from \(effectiveHeaderHostLabel)")
                        .font(.system(size: 13))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AntigravityTheme.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 12)
            .accessibilityIdentifier("chat-loading-steps")
        } else if (store.hasPairedBackend || store.isLiveBackendConnected), let err = store.stepLoadErrorText {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Self.coralError)
                        .frame(width: 8, height: 8)
                    Text("Could not load trajectory steps")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                }
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                Button {
                    store.syncStepsForCascade(store.activeCascadeId, pollUntilIdle: true)
                } label: {
                    Text("Retry")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Self.periwinkle)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Self.pillBg)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AntigravityTheme.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 12)
        } else {
            let isOfflinePaired = !isActiveSessionCloud && store.hasPairedBackend && (!store.isLiveBackendConnected || !store.activeHost.isOnline)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isOfflinePaired ? Self.coralError : (store.isLiveBackendConnected ? Self.emeraldDone : Self.periwinkle))
                        .frame(width: 8, height: 8)
                    Text(isOfflinePaired ? "Host Offline · Queued Outbox Ready" : (store.isLiveBackendConnected ? "Ready for Prompt" : "New Session Ready"))
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                }
                Text("Bound to `\(activeProjectWorkspace?.name ?? store.activeSummary?.projectSlug ?? "workspace")` on `\(effectiveHeaderHostLabel)`. Send a message below to run on \(isActiveSessionCloud ? "Antigravity Cloud" : "Antigravity Desktop").")
                    .font(.system(size: 13.5))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                    .lineSpacing(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AntigravityTheme.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 12)
        }
    }

    // MARK: - Top Navigation Bar

    private var chatTopNavigationBar: some View {
        let navTitle = store.activeSummary?.title ?? ((store.hasPairedBackend || store.isLiveBackendConnected) ? "Conversation" : "Add rate limiter to /transfers")
        let projectLabel = activeProjectWorkspace?.name ?? store.activeSummary?.projectSlug ?? "ledger-svc"
        let branchLabel = store.activeSummary?.branchName ?? activeProjectWorkspace?.activeBranch ?? "main"
        let showDiffPill = (!store.hasPairedBackend && !store.isLiveBackendConnected) || store.totalDiffAdditions > 0 || store.totalDiffDeletions > 0

        return HStack(spacing: 8) {
            Button {
                if let onBack {
                    onBack()
                } else {
                    store.currentRoute = .tabRoot
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Self.periwinkle)
                    .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-back-sessions")

            VStack(alignment: .leading, spacing: 2) {
                Text(navTitle)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("chat-nav-title")

                Text("\(projectLabel) · \(branchLabel) · \(effectiveHeaderHostLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if showDiffPill {
                Button {
                    store.currentRoute = .turnDiffReview
                } label: {
                    HStack(spacing: 5) {
                        Text("+\(store.totalDiffAdditions)")
                            .foregroundStyle(Self.emeraldDone)
                        Text("-\(store.totalDiffDeletions)")
                            .foregroundStyle(Self.coralError)
                    }
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 11)
                    .frame(minWidth: AntigravityTheme.minTouchTargetPt, minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(Self.pillBg)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chat-diff-pill")
            }

            // `•••` Overflow Menu
            Menu {
                Button("Open Implementation Plan") {
                    store.currentRoute = .planReview
                }
                Button("Review Turn Changes") {
                    store.currentRoute = .turnDiffReview
                }
                Button("Refresh Trajectory Steps") {
                    store.syncStepsForCascade(store.activeCascadeId, pollUntilIdle: true)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
            }
            .accessibilityIdentifier("btn-chat-more")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    // MARK: - Above-Composer Status Strip

    private var waitingStatusStrip: some View {
        let statusLabel: String = {
            if isTurnStopped {
                return "Turn stopped"
            }
            if store.pendingWaitingStep != nil {
                return "Waiting for your approval · Step \(store.activeSteps.count)"
            }
            if store.isCascadeStreaming {
                let sourceTitle = isActiveSessionCloud ? "Antigravity Cloud" : (store.activeSummary?.originHostName ?? store.activeHost.hostname)
                return "Streaming from \(sourceTitle) · \(store.activeSteps.count) steps"
            }
            return "Waiting for your approval · Step 5 of 7"
        }()

        return HStack(spacing: 8) {
            if !isStaticESDDFixtureView && !isTurnStopped && store.pendingWaitingStep == nil && store.isCascadeStreaming {
                AntigravityRunningArcIndicatorView(isAnimated: shouldAnimateLive)
            } else {
                Circle()
                    .fill(isTurnStopped ? AntigravityTheme.inkSecondary : (store.pendingWaitingStep != nil ? Self.warmAmber : Self.periwinkle))
                    .frame(width: 8, height: 8)
            }

            Text(statusLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isTurnStopped ? AntigravityTheme.inkSecondary : (store.pendingWaitingStep != nil ? Self.warmAmber : Self.periwinkle))
                .lineLimit(1)

            Spacer()

            Button {
                isTurnStopped = true
                store.stopActiveCascadeStreaming()
            } label: {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                    Text("Stop")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                }
                .padding(.horizontal, 14)
                .frame(minWidth: AntigravityTheme.minTouchTargetPt, minHeight: AntigravityTheme.minTouchTargetPt)
                .background(Self.pillBg)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-stop-turn")
        }
    }
}
