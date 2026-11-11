import SwiftUI
import AntigravityData

public typealias AntigravityShellController = AntigravityRootContainerView

/// Primary bottom navigation tabs in the Floating Liquid Glass Tab Bar.
public enum ShellTab: String, CaseIterable, Sendable, Identifiable {
    case agents
    case automations
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .agents:      return "Agents"
        case .automations: return "Automations"
        case .settings:    return "Settings"
        }
    }

    public var symbolName: String {
        switch self {
        case .agents:      return "bubble.left"
        case .automations: return "clock.arrow.circlepath"
        case .settings:    return "slider.horizontal.3"
        }
    }

    public var fabSymbolName: String {
        switch self {
        case .agents:      return "pencil"
        case .automations: return "plus"
        case .settings:    return "qrcode.viewfinder"
        }
    }

    public var defaultFABAccessibilityId: String {
        switch self {
        case .agents:      return "fab-compose"
        case .automations: return "fab-add-automation"
        case .settings:    return "fab-pair-host"
        }
    }
}

/// Shared UE v2.0 surface, border, and ink tokens complementing `AntigravityTheme`.
enum UEChromePalette {
    static let surfacePopover = Color(red: 0x25 / 255.0, green: 0x27 / 255.0, blue: 0x2F / 255.0)
    static let surfaceSheet = Color(red: 0x17 / 255.0, green: 0x18 / 255.0, blue: 0x1D / 255.0)
    static let surfaceSheetGroup = Color(red: 0x20 / 255.0, green: 0x22 / 255.0, blue: 0x29 / 255.0)
    static let surfacePill = Color(red: 0x17 / 255.0, green: 0x19 / 255.0, blue: 0x1F / 255.0)
    static let surfaceSubtleBox = Color(red: 0x1B / 255.0, green: 0x1D / 255.0, blue: 0x23 / 255.0)
    static let surfaceGlassTab = Color(red: 0x1B / 255.0, green: 0x1D / 255.0, blue: 0x23 / 255.0)
    static let surfaceActiveTabSlot = Color(red: 0x31 / 255.0, green: 0x34 / 255.0, blue: 0x3E / 255.0)
    static let inkOnPrimaryCTA = Color(red: 0x0A / 255.0, green: 0x0E / 255.0, blue: 0x17 / 255.0)
    static let textPrimary = Color(red: 0xF5 / 255.0, green: 0xF7 / 255.0, blue: 0xFA / 255.0)
    static let textBody = Color(red: 0xD5 / 255.0, green: 0xD8 / 255.0, blue: 0xE2 / 255.0)
    static let textSecondary = Color(red: 0x8E / 255.0, green: 0x93 / 255.0, blue: 0xA2 / 255.0)
    static let textMuted = Color(red: 0x7C / 255.0, green: 0x81 / 255.0, blue: 0x90 / 255.0)
    static let cardBorder = Color.white.opacity(0.08)
    static let subtleDivider = Color.white.opacity(0.07)
}

/// Signature UE01 / UE06 global bottom navigation chrome:
/// Left Floating Liquid Glass 3-Tab Capsule (`Agents` | `Automations` | `Settings`)
/// + Detached Right `56×56pt` Periwinkle (`AntigravityTheme.accentPeriwinkle`) Circular FAB.
public struct AntigravityFloatingTabBar: View {
    public let selectedTab: ShellTab
    public let tabBarAccessibilityId: String
    public let fabAccessibilityId: String
    public var onSelectTab: (ShellTab) -> Void
    public var onTapFAB: () -> Void

    public init(
        selectedTab: ShellTab,
        tabBarAccessibilityId: String = "floating-tab-bar",
        fabAccessibilityId: String? = nil,
        onSelectTab: @escaping (ShellTab) -> Void = { _ in },
        onTapFAB: @escaping () -> Void = {}
    ) {
        self.selectedTab = selectedTab
        self.tabBarAccessibilityId = tabBarAccessibilityId
        self.fabAccessibilityId = fabAccessibilityId ?? selectedTab.defaultFABAccessibilityId
        self.onSelectTab = onSelectTab
        self.onTapFAB = onTapFAB
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Left: Floating Liquid Glass 3-Tab Capsule
            HStack(spacing: 2) {
                ForEach(ShellTab.allCases) { tab in
                    let isSelected = (tab == selectedTab)
                    Button {
                        onSelectTab(tab)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbolName)
                                .font(.system(size: 17, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(
                            isSelected
                                ? AntigravityTheme.accentPeriwinkle
                                : Color(red: 0xC2 / 255.0, green: 0xC6 / 255.0, blue: 0xD2 / 255.0)
                        )
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            Group {
                                if isSelected {
                                    Capsule()
                                        .fill(UEChromePalette.surfaceActiveTabSlot)
                                }
                            }
                        )
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tab-item-\(tab.rawValue)")
                }
            }
            .padding(4)
            .frame(height: 60)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .fill(UEChromePalette.surfaceGlassTab.opacity(0.90))
                }
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(tabBarAccessibilityId)

            // Right: Detached 56x56pt Periwinkle Circular FAB
            Button {
                onTapFAB()
            } label: {
                Image(systemName: selectedTab.fabSymbolName)
                    .font(.system(size: selectedTab == .automations ? 22 : 19, weight: .semibold))
                    .foregroundStyle(UEChromePalette.inkOnPrimaryCTA)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(AntigravityTheme.accentPeriwinkle)
                    )
                    .shadow(color: Color.black.opacity(0.40), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(fabAccessibilityId)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}

/// Full-bleed card row `ButtonStyle` ensuring 100% solid pixel hit-testing across
/// text, spacers, and padding on both iOS Simulator (`DeviceHub` mouse clicks) and physical touch,
/// with instant tactile press feedback and zero `PlainButtonStyle` transparent dead zones.
public struct AntigravityInteractiveRowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AntigravityTheme.surfaceCard
                    .overlay(Color.white.opacity(configuration.isPressed ? 0.09 : 0.0))
            )
            .contentShape(Rectangle())
    }
}

/// Adaptive shell container (`AntigravityShellController`) routing all 13 UE v2.0 flows
/// interactively or rendering deterministic isolated ESDD verification scenes (`UE01`..`UE13`).
public struct AntigravityRootContainerView: View {
    @Bindable public var store: AntigravitySessionStore
    @Binding public var activeVerifyCase: ESDDVerifySceneCase?

    @State private var selectedTab: ShellTab = .agents
    @State private var activeModalSheet: ModalSheetDestination?
    @State private var chatReturnProjectSlug: String?

    private enum ModalSheetDestination: String, Identifiable {
        case displayOptions
        case createProject
        case contextMenuPreview

        var id: String { rawValue }
    }

    public init(
        store: AntigravitySessionStore,
        activeVerifyCase: Binding<ESDDVerifySceneCase?>
    ) {
        self.store = store
        self._activeVerifyCase = activeVerifyCase
    }

    public var body: some View {
        Group {
            if let verifyCase = activeVerifyCase {
                isolatedESDDSceneView(for: verifyCase)
            } else {
                interactiveNavigationView
            }
        }
        .background(AntigravityTheme.canvasObsidian.ignoresSafeArea())
    }

    // MARK: - Interactive Navigation Shell

    @ViewBuilder
    private var interactiveNavigationView: some View {
        ZStack {
            switch store.activeRoute {
            case .planReview:
                ImplementationPlanReviewViewController(store: store)
            case .turnDiffReview:
                TurnDiffReviewViewController(store: store)
            case .projectDetail(let projectSlug):
                ProjectDetailViewController(
                    store: store,
                    projectSlug: projectSlug,
                    onBack: {
                        chatReturnProjectSlug = nil
                        store.activeRoute = .tabRoot
                    },
                    onOpenConversation: { convId in
                        chatReturnProjectSlug = projectSlug
                        openOrCreateConversation(convId, defaultProjectSlug: projectSlug)
                    }
                )
            case .cascadeChat:
                CascadeChatViewController(
                    store: store,
                    onBack: {
                        if let returnSlug = chatReturnProjectSlug {
                            chatReturnProjectSlug = nil
                            store.activeRoute = .projectDetail(returnSlug)
                        } else {
                            store.activeRoute = .tabRoot
                        }
                    }
                )
            case .pairingSettings:
                settingsTabContainerView
            case .tabRoot:
                switch selectedTab {
                case .agents:
                    AgentsHomeViewController(
                        store: store,
                        onSelectTab: { tab in selectedTab = tab },
                        onOpenDisplayOptions: { activeModalSheet = .displayOptions },
                        onOpenNewProject: { activeModalSheet = .createProject },
                        onOpenProjectDetail: { slug in
                            chatReturnProjectSlug = nil
                            store.selectProject(slug)
                        },
                        onOpenContextMenuPreview: { activeModalSheet = .contextMenuPreview },
                        onOpenConversation: { convId in
                            chatReturnProjectSlug = nil
                            openOrCreateConversation(convId, defaultProjectSlug: store.selectedProjectId)
                        }
                    )
                case .automations:
                    AutomationsViewController(
                        store: store,
                        onSelectTab: { tab in selectedTab = tab },
                        onOpenDisplayOptions: { activeModalSheet = .displayOptions }
                    )
                case .settings:
                    settingsTabContainerView
                }
            }
        }
        .sheet(item: $activeModalSheet) { sheet in
            switch sheet {
            case .displayOptions:
                DisplayOptionsSheetView(
                    store: store,
                    onDismiss: { activeModalSheet = nil }
                )
            case .createProject:
                CreateProjectSheetView(
                    store: store,
                    onDismiss: { activeModalSheet = nil }
                )
            case .contextMenuPreview:
                ConversationContextPreviewMenu(
                    store: store,
                    onDismiss: { activeModalSheet = nil }
                )
            }
        }
    }

    private var settingsTabContainerView: some View {
        VStack(spacing: 0) {
            RemotePairingViewController(
                store: store,
                onConnected: {
                    store.activeRoute = .tabRoot
                    selectedTab = .agents
                }
            )
            Spacer(minLength: 0)
            AntigravityFloatingTabBar(
                selectedTab: .settings,
                onSelectTab: { tab in
                    store.activeRoute = .tabRoot
                    selectedTab = tab
                },
                onTapFAB: {
                    store.activeRoute = .tabRoot
                    selectedTab = .agents
                }
            )
        }
        .background(AntigravityTheme.canvasObsidian)
    }

    private func openOrCreateConversation(_ rawId: String, defaultProjectSlug: String) {
        if rawId == "new-conversation" || rawId.hasPrefix("new-") {
            let slug = rawId.hasPrefix("new-") && rawId != "new-conversation"
                ? String(rawId.dropFirst(4))
                : defaultProjectSlug
            _ = store.createConversationInProject(slug)
            return
        }
        let mappedId: String = {
            switch rawId {
            case "conv-rate-limiter", "proj-conv-rate-limiter": return "cas-rate-limiter"
            case "conv-flaky-settlement", "proj-conv-flaky-batch": return "cas-flaky-settlement"
            case "conv-upgrade-go", "proj-conv-upgrade-go": return "cas-upgrade-go"
            case "conv-release-checklist": return "cas-release-checklist"
            default: return rawId
            }
        }()
        store.selectCascade(mappedId)
    }

    // MARK: - Isolated Deterministic ESDD Scenes (UE01 .. UE13)

    @ViewBuilder
    private func isolatedESDDSceneView(for verifyCase: ESDDVerifySceneCase) -> some View {
        switch verifyCase {
        case .agentsHome:
            AgentsHomeViewController(store: store)
        case .displayOptions:
            DisplayOptionsSheetView(store: store)
        case .contextMenuPin:
            ConversationContextPreviewMenu(store: store)
        case .projectDetail:
            ProjectDetailViewController(store: store)
        case .createProject:
            CreateProjectSheetView(store: store)
        case .automations:
            AutomationsViewController(store: store)
        case .chatAndComposer:
            CascadeChatViewController(store: store)
        case .addContext:
            AddContextSheetView(store: store)
        case .modelAndMode:
            ModelAndModeSheetView(store: store)
        case .structuredQuestion:
            StructuredQuestionCardView(store: store)
        case .planReview:
            ImplementationPlanReviewViewController(store: store)
        case .turnDiffReview:
            TurnDiffReviewViewController(store: store)
        case .liveActivitySpec:
            AntigravityLiveActivitySpecShowcaseView(store: store)
        }
    }
}
