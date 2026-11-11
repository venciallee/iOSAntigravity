import SwiftUI
import AntigravityData

/// State `UE06_AUTOMATIONS`: Automations Hub (`SCHEDULED · 2`, `ALWAYS ON · 1`, `PAUSED · 1`).
/// Matches `/home/antigravity/iOS_·_Automations.png` 1:1.
public struct AutomationsViewController: View {
    @Bindable public var store: AntigravitySessionStore
    public var onSelectTab: ((ShellTab) -> Void)?
    public var onOpenDisplayOptions: (() -> Void)?

    public struct ScheduledAutomationCardModel: Identifiable {
        public let id: String
        public var title: String
        public var subtitle: String
        public var nextRunText: String
        public var lastRunText: String
        public var needsReview: Bool
        public let cardAccessibilityId: String
        public let playAccessibilityId: String
    }

    @State private var quickPromptText: String = ""
    @State private var isPausedResumed: Bool = false

    @State private var scheduledAutomations: [ScheduledAutomationCardModel] = [
        ScheduledAutomationCardModel(
            id: "auto-nightly-audit",
            title: "Nightly dependency audit",
            subtitle: "ledger-svc · Daily at 02:00 · Flash",
            nextRunText: "Tonight, 02:00",
            lastRunText: "Succeeded · 22h ago",
            needsReview: false,
            cardAccessibilityId: "automation-card-nightly",
            playAccessibilityId: "btn-run-nightly"
        ),
        ScheduledAutomationCardModel(
            id: "auto-weekly-flaky",
            title: "Weekly flaky-test report",
            subtitle: "ledger-svc · Mondays at 09:00 · Pro",
            nextRunText: "Mon, 09:00",
            lastRunText: "Needs review · 2d",
            needsReview: true,
            cardAccessibilityId: "automation-card-flaky",
            playAccessibilityId: "btn-run-flaky"
        )
    ]

    public init(
        store: AntigravitySessionStore,
        onSelectTab: ((ShellTab) -> Void)? = nil,
        onOpenDisplayOptions: (() -> Void)? = nil
    ) {
        self.store = store
        self.onSelectTab = onSelectTab
        self.onOpenDisplayOptions = onOpenDisplayOptions
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    topFilterToolbar
                    Text("Automations")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white)

                    quickCreateCapsuleBar

                    if !store.isVerificationMode || store.isLiveBackendConnected {
                        liveAutomationsBody
                    } else {
                        scheduledSection
                        alwaysOnSection
                        pausedSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 96)
            }
            .refreshable {
                await store.refreshWorkspacesAndSummaries()
            }

            LinearGradient(
                colors: [
                    AntigravityTheme.canvasObsidian.opacity(0.0),
                    AntigravityTheme.canvasObsidian.opacity(0.84),
                    AntigravityTheme.canvasObsidian
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 82)
            .allowsHitTesting(false)

            AntigravityFloatingTabBar(
                selectedTab: .automations,
                tabBarAccessibilityId: "floating-tab-bar",
                fabAccessibilityId: "fab-add-automation",
                onSelectTab: { tab in
                    onSelectTab?(tab)
                },
                onTapFAB: {
                    createInlineAutomation()
                }
            )
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
    }

    // MARK: - 1. Top Filter Button

    private var topFilterToolbar: some View {
        HStack {
            Spacer()
            Button {
                onOpenDisplayOptions?()
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UEChromePalette.textPrimary)
                    .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                    .background(Circle().fill(UEChromePalette.surfacePill))
                    .overlay(Circle().strokeBorder(UEChromePalette.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-automations-filter")
        }
    }

    // MARK: - 2. Natural-Language Quick Create Bar

    private var quickCreateCapsuleBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "bolt")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(UEChromePalette.textSecondary)

                TextField("Every weekday at 9, summarize", text: $quickPromptText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(UEChromePalette.textPrimary)
                    .tint(AntigravityTheme.accentPeriwinkle)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("automation-prompt-input")

            Button {
                createInlineAutomation()
            } label: {
                Text("Create")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(
                        Capsule()
                            .fill(Color(red: 0x26 / 255.0, green: 0x28 / 255.0, blue: 0x30 / 255.0))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-create-automation-inline")
        }
        .padding(.leading, 15)
        .padding(.trailing, 5)
        .frame(minHeight: 52)
        .background(
            Capsule()
                .fill(AntigravityTheme.surfaceCard)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: - 3. SCHEDULED · 2 Section

    private var scheduledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULED · \(scheduledAutomations.count)")
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(UEChromePalette.textMuted)
                .padding(.leading, 2)
                .padding(.top, 2)

            ForEach(scheduledAutomations.indices, id: \.self) { index in
                let item = scheduledAutomations[index]
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white)
                            Text(item.subtitle)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(UEChromePalette.textSecondary)
                        }

                        Spacer()

                        Button {
                            scheduledAutomations[index].lastRunText = "Running · just now"
                            scheduledAutomations[index].needsReview = false
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                                .frame(
                                    width: AntigravityTheme.minTouchTargetPt,
                                    height: AntigravityTheme.minTouchTargetPt
                                )
                                .background(
                                    Circle()
                                        .fill(Color(red: 0x1E / 255.0, green: 0x24 / 255.0, blue: 0x33 / 255.0))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(AntigravityTheme.accentPeriwinkle.opacity(0.20), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(item.playAccessibilityId)
                    }

                    HStack(spacing: 9) {
                        // NEXT RUN Stat Box
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NEXT RUN")
                                .font(.system(size: 10.5, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(UEChromePalette.textMuted)
                            Text(item.nextRunText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(UEChromePalette.textPrimary)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(UEChromePalette.surfaceSubtleBox)
                        )

                        // LAST RUN Stat Box
                        VStack(alignment: .leading, spacing: 3) {
                            Text("LAST RUN")
                                .font(.system(size: 10.5, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(
                                    item.needsReview ? AntigravityTheme.statusWaiting : UEChromePalette.textMuted
                                )

                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                if !item.needsReview {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundStyle(AntigravityTheme.statusDone)
                                }
                                Text(item.lastRunText)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(
                                        item.needsReview ? AntigravityTheme.statusWaiting : UEChromePalette.textPrimary
                                    )
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    item.needsReview
                                        ? AntigravityTheme.statusWaiting.opacity(0.14)
                                        : UEChromePalette.surfaceSubtleBox
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    item.needsReview ? AntigravityTheme.statusWaiting.opacity(0.24) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AntigravityTheme.surfaceCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(item.cardAccessibilityId)
            }
        }
    }

    // MARK: - 4. ALWAYS ON · 1 Section

    private var alwaysOnSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("ALWAYS ON · 1")
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(UEChromePalette.textMuted)
                .padding(.leading, 2)
                .padding(.top, 2)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AntigravityTheme.statusDone.opacity(0.22))
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(AntigravityTheme.statusDone)
                        .frame(width: 9.5, height: 9.5)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    Text("Triage new pull requests")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Color.white)
                    Text("web-console · On PR opened · Flash Lite")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                    Text("Last run 14m ago")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(UEChromePalette.textBody)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(UEChromePalette.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AntigravityTheme.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
            )
            .accessibilityIdentifier("automation-card-always-on")
        }
    }

    // MARK: - 5. PAUSED · 1 Section

    private var pausedSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("PAUSED · \(isPausedResumed ? 0 : 1)")
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(UEChromePalette.textMuted)
                .padding(.leading, 2)
                .padding(.top, 2)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bundle size watch")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(
                            isPausedResumed
                                ? Color.white
                                : Color(red: 0xA0 / 255.0, green: 0xA5 / 255.0, blue: 0xB4 / 255.0)
                        )
                    Text("web-console · Daily at 08:00 · Flash")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(UEChromePalette.textMuted)
                }

                Spacer()

                Button {
                    isPausedResumed.toggle()
                } label: {
                    Text(isPausedResumed ? "Active" : "Resume")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(UEChromePalette.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                        .background(
                            Capsule()
                                .fill(Color(red: 0x23 / 255.0, green: 0x25 / 255.0, blue: 0x2D / 255.0))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-resume-paused")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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

    // MARK: - Live Backend Automations View

    @ViewBuilder
    private var liveAutomationsBody: some View {
        if store.automations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("SCHEDULED · 0")
                    .font(.system(size: 11.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(UEChromePalette.textMuted)
                    .padding(.leading, 2)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    let hostOnline = store.isLiveBackendConnected && store.activeHost.isOnline
                    HStack(spacing: 8) {
                        Circle()
                            .fill(hostOnline ? AntigravityTheme.statusDone : AntigravityTheme.statusError)
                            .frame(width: 8, height: 8)
                        Text(hostOnline ? "Connected to \(store.activeHost.hostname)" : "Offline · \(store.activeHost.hostname)")
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                    Text("Antigravity Desktop does not define built-in cron automations yet. Enter a schedule above or tap + to create a live Companion automation scoped to `\(store.selectedProject?.name ?? "workspace")`.")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(UEChromePalette.textSecondary)
                        .lineSpacing(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AntigravityTheme.surfaceCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(UEChromePalette.cardBorder, lineWidth: 1)
                )
            }
        } else {
            if !store.scheduledAutomations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SCHEDULED · \(store.scheduledAutomations.count)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(UEChromePalette.textMuted)
                        .padding(.leading, 2)
                        .padding(.top, 2)

                    ForEach(store.scheduledAutomations) { item in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color.white)
                                    Text(item.scheduleSummary)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(UEChromePalette.textSecondary)
                                }
                                Spacer()
                                Button {
                                    store.triggerAutomationNow(item.id)
                                } label: {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(AntigravityTheme.accentPeriwinkle)
                                        .frame(
                                            width: AntigravityTheme.minTouchTargetPt,
                                            height: AntigravityTheme.minTouchTargetPt
                                        )
                                        .background(
                                            Circle()
                                                .fill(Color(red: 0x1E / 255.0, green: 0x24 / 255.0, blue: 0x33 / 255.0))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(AntigravityTheme.accentPeriwinkle.opacity(0.20), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            HStack(spacing: 9) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("NEXT RUN")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .tracking(0.5)
                                        .foregroundStyle(UEChromePalette.textMuted)
                                    Text(item.nextRunText)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(UEChromePalette.textPrimary)
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(UEChromePalette.surfaceSubtleBox)
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("LAST RUN")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .tracking(0.5)
                                        .foregroundStyle(UEChromePalette.textMuted)
                                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                                        Image(systemName: item.isRunningNow ? "bolt.fill" : "checkmark")
                                            .font(.system(size: 10.5, weight: .bold))
                                            .foregroundStyle(item.isRunningNow ? AntigravityTheme.statusRunning : AntigravityTheme.statusDone)
                                        Text(item.lastRunText)
                                            .font(.system(size: 13.5, weight: .medium))
                                            .foregroundStyle(UEChromePalette.textPrimary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity, minHeight: 50, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(UEChromePalette.surfaceSubtleBox)
                                )
                            }
                        }
                        .padding(13)
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

            if !store.pausedAutomations.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("PAUSED · \(store.pausedAutomations.count)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(UEChromePalette.textMuted)
                        .padding(.leading, 2)
                        .padding(.top, 2)

                    ForEach(store.pausedAutomations) { item in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 15.5, weight: .semibold))
                                    .foregroundStyle(Color(red: 0xA0 / 255.0, green: 0xA5 / 255.0, blue: 0xB4 / 255.0))
                                Text(item.scheduleSummary)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(UEChromePalette.textMuted)
                            }
                            Spacer()
                            Button {
                                store.resumeAutomation(item.id)
                            } label: {
                                Text("Resume")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(UEChromePalette.textPrimary)
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                                    .background(
                                        Capsule()
                                            .fill(Color(red: 0x23 / 255.0, green: 0x25 / 255.0, blue: 0x2D / 255.0))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
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
        }
    }

    private func createInlineAutomation() {
        let trimmed = quickPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "Weekday morning summary" : trimmed
        if !store.isVerificationMode || store.isLiveBackendConnected {
            _ = store.createAutomationFromPrompt(title)
            quickPromptText = ""
            return
        }
        let newCard = ScheduledAutomationCardModel(
            id: "auto-\(scheduledAutomations.count + 1)",
            title: title,
            subtitle: "ledger-svc · Weekdays at 09:00 · Flash",
            nextRunText: "Tomorrow, 09:00",
            lastRunText: "Scheduled · Ready",
            needsReview: false,
            cardAccessibilityId: "automation-card-custom-\(scheduledAutomations.count + 1)",
            playAccessibilityId: "btn-run-custom-\(scheduledAutomations.count + 1)"
        )
        scheduledAutomations.insert(newCard, at: 0)
        quickPromptText = ""
    }
}
