import SwiftUI
import AntigravityData

/// State `UE09_MODEL_AND_MODE`: Official Model, Mode & Custom Agent Picker sheet (`iOS · 模型 / Agent 模式选择`).
/// Features:
/// - `Model & Mode` header + Periwinkle `Done` button (`btn-model-done`)
/// - Side-by-side `Planning` (`mode-card-planning` with `#8EB4FF` border) and `Fast` (`mode-card-fast`) mode cards
/// - `MODEL` list (`Gemini 3.1 Pro ✓`, `Gemini 3.8 Flash`, `Claude Opus 5.5 [Thinking]`, `Claude Sonnet 5.5 [Thinking]`)
/// - Note: `A new model takes effect on the next turn.`
/// - `AGENT` persona pills (`Default` pure white active pill, `go-reviewer`, `release-captain`).
public struct ModelAndModeSheetView: View {
    @Bindable public var store: AntigravitySessionStore
    public var onSelectConfiguration: ((String, String, String) -> Void)?
    public var onDismiss: (() -> Void)?

    private static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    private static let sheetSurface = Color(red: 0x17 / 255.0, green: 0x18 / 255.0, blue: 0x1E / 255.0)
    private static let cardSurface = Color(red: 0x20 / 255.0, green: 0x22 / 255.0, blue: 0x2A / 255.0)
    private static let planningActiveSurface = Color(red: 0x1F / 255.0, green: 0x25 / 255.0, blue: 0x33 / 255.0)

    public init(
        store: AntigravitySessionStore,
        onSelectConfiguration: ((String, String, String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.store = store
        self.onSelectConfiguration = onSelectConfiguration
        self.onDismiss = onDismiss
    }

    private var displayedModels: [CascadeModelConfig] {
        store.availableModels.isEmpty ? CascadeModelConfig.liveDefaultCatalog : store.availableModels
    }

    private var displayedAgents: [String] {
        store.availableAgents.isEmpty ? ["Default"] : store.availableAgents
    }

    public var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: displayedModels.count > 4 ? 36 : 88)

            VStack(alignment: .leading, spacing: 14) {
                // Top Grabber
                HStack {
                    Spacer()
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 38, height: 5)
                    Spacer()
                }
                .padding(.top, 10)

                // Title & Done Header
                ZStack {
                    Text("Model & Mode")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AntigravityTheme.inkReading)

                    HStack {
                        Spacer()
                        Button {
                            applyAndDismiss()
                        } label: {
                            Text("Done")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Self.periwinkle)
                                .padding(.horizontal, 8)
                                .frame(minWidth: AntigravityTheme.minTouchTargetPt, minHeight: AntigravityTheme.minTouchTargetPt)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("btn-model-done")
                    }
                }

                // Planning vs Fast Mode Cards
                HStack(spacing: 12) {
                    modeCardButton(
                        mode: .planning,
                        iconName: "doc.text",
                        description: "Plans first and writes artifacts for you to review",
                        testId: "mode-card-planning"
                    )

                    modeCardButton(
                        mode: .fast,
                        iconName: "bolt",
                        description: "Acts directly — best for small, local edits",
                        testId: "mode-card-fast"
                    )
                }

                // MODEL Picker Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("MODEL")
                        .font(.system(size: 11.5, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(AntigravityTheme.inkSecondary)

                    if displayedModels.count > 4 {
                        ScrollView(.vertical, showsIndicators: true) {
                            modelRowsList
                        }
                        .frame(maxHeight: 280)
                        .background(Self.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        modelRowsList
                            .background(Self.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Text("A new model takes effect on the next turn.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                        .padding(.top, 2)
                }

                // AGENT Persona Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("AGENT")
                        .font(.system(size: 11.5, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(AntigravityTheme.inkSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        let agentList = displayedAgents
                        ForEach(Array(stride(from: 0, to: agentList.count, by: 2)), id: \.self) { rowStart in
                            HStack(spacing: 10) {
                                let firstName = agentList[rowStart]
                                agentPersonaPill(
                                    name: firstName,
                                    isMonospaced: firstName != "Default",
                                    testId: "agent-pill-\(firstName.lowercased())"
                                )
                                if rowStart + 1 < agentList.count {
                                    let secondName = agentList[rowStart + 1]
                                    agentPersonaPill(
                                        name: secondName,
                                        isMonospaced: secondName != "Default",
                                        testId: "agent-pill-\(secondName.lowercased())"
                                    )
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 18)
            .background(Self.sheetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .background(AntigravityTheme.canvasObsidian)
        .task {
            if store.hasPairedBackend || store.isLiveBackendConnected {
                await store.refreshModelCatalog()
            }
        }
    }

    private var modelRowsList: some View {
        let models = displayedModels
        return VStack(spacing: 0) {
            ForEach(Array(models.enumerated()), id: \.element.modelId) { idx, option in
                modelOptionRow(option, index: idx)
                if idx < models.count - 1 {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                        .padding(.leading, 16)
                }
            }
        }
    }

    private func modeCardButton(
        mode: CascadeExecutionMode,
        iconName: String,
        description: String,
        testId: String
    ) -> some View {
        let isSelected = store.selectedModelConfig.mode == mode
        return Button {
            store.selectedModelConfig.mode = mode
            onSelectConfiguration?(
                mode.rawValue,
                store.selectedModelConfig.displayName,
                store.selectedModelConfig.agentPersona
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? Self.periwinkle : AntigravityTheme.inkSecondary)
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                }

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(isSelected ? Self.planningActiveSurface : Self.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? Self.periwinkle : Color.white.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(testId)
    }

    private static func accessibilityId(for option: CascadeModelConfig, index: Int) -> String {
        let lower = option.displayName.lowercased()
        if option.modelId == "gemini-3-1-pro" || (index == 0 && lower.contains("gemini") && lower.contains("pro")) {
            return "model-row-gemini-pro"
        }
        if lower.contains("flash") {
            return "model-row-gemini-flash"
        }
        if lower.contains("opus") {
            return "model-row-claude-opus"
        }
        if lower.contains("sonnet") {
            return "model-row-claude-sonnet"
        }
        return "model-row-\(option.modelId)"
    }

    private func modelOptionRow(_ option: CascadeModelConfig, index: Int) -> some View {
        let isSelected = store.selectedModelConfig.modelId == option.modelId
            || store.selectedModelConfig.displayName == option.displayName
        return Button {
            store.selectedModelConfig = CascadeModelConfig(
                modelId: option.modelId,
                displayName: option.displayName,
                subtitle: option.subtitle,
                hasThinkingBadge: option.hasThinkingBadge,
                requiresUpgradeNote: option.requiresUpgradeNote,
                mode: store.selectedModelConfig.mode,
                agentPersona: store.selectedModelConfig.agentPersona,
                effort: option.effort,
                isModelAlias: option.isModelAlias
            )
            onSelectConfiguration?(
                store.selectedModelConfig.mode.rawValue,
                option.displayName,
                store.selectedModelConfig.agentPersona
            )
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(option.displayName)
                            .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(AntigravityTheme.inkReading)

                        if option.hasThinkingBadge {
                            Text("Thinking")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AntigravityTheme.inkLabel)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }

                    Text(option.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Self.periwinkle)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Self.accessibilityId(for: option, index: index))
    }

    private func agentPersonaPill(
        name: String,
        isMonospaced: Bool,
        testId: String
    ) -> some View {
        let isSelected = store.selectedModelConfig.agentPersona == name
        return Button {
            store.selectedModelConfig.agentPersona = name
            onSelectConfiguration?(
                store.selectedModelConfig.mode.rawValue,
                store.selectedModelConfig.displayName,
                name
            )
        } label: {
            Text(name)
                .font(
                    isMonospaced
                        ? .system(size: 13.5, weight: isSelected ? .bold : .medium, design: .monospaced)
                        : .system(size: 14, weight: .bold)
                )
                .foregroundStyle(isSelected ? Color(red: 0.04, green: 0.04, blue: 0.05) : AntigravityTheme.inkReading)
                .padding(.horizontal, 18)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .background(isSelected ? Color.white : Self.cardSurface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(testId)
    }

    private func applyAndDismiss() {
        onSelectConfiguration?(
            store.selectedModelConfig.mode.rawValue,
            store.selectedModelConfig.displayName,
            store.selectedModelConfig.agentPersona
        )
        if let onDismiss {
            onDismiss()
        } else {
            store.currentRoute = .chatAndComposer
        }
    }
}
