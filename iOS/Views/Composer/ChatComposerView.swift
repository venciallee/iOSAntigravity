import SwiftUI
import AntigravityData

/// Native Liquid Glass Input Bar (`ChatComposerView`) pinned to the bottom of `CascadeChatViewController`.
/// Features:
/// - Multi-line auto-expanding `TextField(..., axis: .vertical)` (`1...6` lines) bound to `store.composerDraftText`
/// - Interactive `/slash` command autocomplete popup (`/plan`, `/goal`, `/grill-me`, `/teamwork`, `/verify`)
/// - Interactive `@file` workspace file mention autocomplete popup
/// - Removable context attachment chips (`@ConnectEnvelope.swift`, screenshots, terminal logs)
/// - Concrete Model + Effort + Mode selector pill (`Claude Sonnet 4.5 · High · Planning`) with full configuration sheet
/// - Dynamic Send (`arrow.up.circle.fill`) / Stop Streaming (`stop.circle.fill`) button with `>= 44×44pt` touch targets.
public struct ChatComposerView: View {
    @Bindable public var store: AntigravitySessionStore
    @FocusState private var isInputFocused: Bool
    @State private var isShowingModelSheet: Bool = false

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 1. Slash Command Autocomplete Popup
            if !store.activeSlashCommandSuggestions.isEmpty {
                slashCommandAutocompleteCard
            }

            // 2. @File Mention Autocomplete Popup
            if !store.activeFileMentionSuggestions.isEmpty {
                fileMentionAutocompleteCard
            }

            // 3. Main Liquid Glass Composer Capsule
            VStack(alignment: .leading, spacing: 10) {
                // Context Attachment Chips Strip
                if !store.composerAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.composerAttachments) { chip in
                                HStack(spacing: 6) {
                                    Image(systemName: chip.kind == .fileMention ? "doc.text.fill" : "photo")
                                        .font(.system(size: 11))
                                        .foregroundStyle(AntigravityTheme.accentSecondary)
                                    Text(chip.label)
                                        .font(AntigravityTheme.TypographyTier.metadata.font)
                                        .foregroundStyle(AntigravityTheme.inkReading)
                                    Button {
                                        store.removeAttachment(chip.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(AntigravityTheme.inkSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AntigravityTheme.surfaceElevated)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .accessibilityIdentifier("composer-attachments-strip")
                }

                // Multi-line Auto-Growing Text Input
                TextField(
                    "Ask Antigravity, @mention files, or type / for workflows...",
                    text: $store.composerDraftText,
                    axis: .vertical
                )
                .lineLimit(1...6)
                .font(AntigravityTheme.TypographyTier.reading.font)
                .foregroundStyle(AntigravityTheme.inkReading)
                .focused($isInputFocused)
                .onSubmit {
                    if store.canSendCurrentDraft {
                        store.sendCurrentDraft()
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .accessibilityIdentifier("composer-text-input")

                // Bottom Control Strip: Attach (+), Slash (/), Model Config Pill, Send/Stop Button
                HStack(spacing: 8) {
                    // + Attachment Menu Button (>= 44x44pt)
                    Menu {
                        Section("Attach Workspace File (@)") {
                            ForEach(store.currentWorkspace?.indexedFiles ?? [], id: \.self) { filePath in
                                Button {
                                    store.attachFileMention(filePath)
                                } label: {
                                    Label((filePath as NSString).lastPathComponent, systemImage: "doc.badge.plus")
                                }
                            }
                        }
                        Section("Insert Workflow (/slash)") {
                            ForEach(SlashCommandItem.allCommands) { cmd in
                                Button {
                                    store.applySlashCommand(cmd)
                                } label: {
                                    Label("\(cmd.command) — \(cmd.title)", systemImage: cmd.iconName)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AntigravityTheme.inkLabel)
                            .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(Circle())
                    }
                    .accessibilityIdentifier("composer-attach-btn")

                    // Model / Effort / Mode Selector Pill (>= 44pt height)
                    Button {
                        isShowingModelSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AntigravityTheme.accentSecondary)
                            Text("\(store.selectedModelConfig.displayName) · \(store.selectedModelConfig.effort.rawValue) · \(store.selectedModelConfig.mode.rawValue)")
                                .font(AntigravityTheme.TypographyTier.chrome.font)
                                .foregroundStyle(AntigravityTheme.inkLabel)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                        .background(AntigravityTheme.surfaceElevated)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("composer-model-pill")

                    Spacer()

                    // Dynamic Send / Stop Streaming Button (>= 44x44pt)
                    if store.isCascadeStreaming && !store.canSendCurrentDraft {
                        Button {
                            store.stopActiveCascadeStreaming()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(AntigravityTheme.statusError)
                                .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("composer-stop-btn")
                    } else {
                        Button {
                            store.sendCurrentDraft()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(
                                    store.canSendCurrentDraft
                                        ? AntigravityTheme.accentPrimary
                                        : AntigravityTheme.inkMuted
                                )
                                .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("composer-send-btn")
                    }
                }
            }
            .padding(12)
            .antigravityGlass(cornerRadius: 24, isHighlighted: true)
            .accessibilityIdentifier("liquid-glass-composer")
        }
        .sheet(isPresented: $isShowingModelSheet) {
            modelConfigurationPickerSheet
        }
    }

    // MARK: - Slash Command Autocomplete Popup

    private var slashCommandAutocompleteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORKFLOW SLASH COMMANDS")
                .font(AntigravityTheme.TypographyTier.metadata.font)
                .foregroundStyle(AntigravityTheme.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(store.activeSlashCommandSuggestions) { item in
                Button {
                    store.applySlashCommand(item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.iconName)
                            .foregroundStyle(AntigravityTheme.accentSecondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.command)
                                    .font(AntigravityTheme.TypographyTier.metadata.font)
                                    .foregroundStyle(AntigravityTheme.accentPrimary)
                                Text(item.title)
                                    .font(AntigravityTheme.TypographyTier.evidence.font)
                                    .foregroundStyle(AntigravityTheme.inkReading)
                            }
                            Text(item.summary)
                                .font(AntigravityTheme.TypographyTier.process.font)
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
        .background(AntigravityTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("composer-slash-popup")
    }

    // MARK: - @File Mention Autocomplete Popup

    private var fileMentionAutocompleteCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MENTION WORKSPACE FILE (@)")
                .font(AntigravityTheme.TypographyTier.metadata.font)
                .foregroundStyle(AntigravityTheme.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(store.activeFileMentionSuggestions, id: \.self) { filePath in
                Button {
                    store.attachFileMention(filePath)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(AntigravityTheme.accentSecondary)
                        Text(filePath)
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.inkReading)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
        .background(AntigravityTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("composer-file-mention-popup")
    }

    // MARK: - Model / Effort / Mode Configuration Sheet

    private var modelConfigurationPickerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Model & Execution Configuration")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AntigravityTheme.inkReading)

            Text("SELECT MODEL")
                .font(AntigravityTheme.TypographyTier.metadata.font)
                .foregroundStyle(AntigravityTheme.inkSecondary)

            ForEach(CascadeModelConfig.catalog) { model in
                Button {
                    store.selectedModelConfig.modelId = model.modelId
                    store.selectedModelConfig.displayName = model.displayName
                    store.selectedModelConfig.providerBadge = model.providerBadge
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(AntigravityTheme.TypographyTier.evidence.font)
                                .foregroundStyle(AntigravityTheme.inkReading)
                            Text(model.providerBadge)
                                .font(AntigravityTheme.TypographyTier.process.font)
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                        }
                        Spacer()
                        if store.selectedModelConfig.modelId == model.modelId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AntigravityTheme.accentPrimary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(AntigravityTheme.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text("THINKING EFFORT")
                .font(AntigravityTheme.TypographyTier.metadata.font)
                .foregroundStyle(AntigravityTheme.inkSecondary)

            HStack(spacing: 10) {
                ForEach(ThinkingEffortLevel.allCases) { effort in
                    Button {
                        store.selectedModelConfig.effort = effort
                    } label: {
                        Text(effort.rawValue)
                            .font(AntigravityTheme.TypographyTier.chrome.font)
                            .foregroundStyle(store.selectedModelConfig.effort == effort ? AntigravityTheme.inkReading : AntigravityTheme.inkLabel)
                            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(
                                store.selectedModelConfig.effort == effort
                                    ? AntigravityTheme.accentPrimary
                                    : AntigravityTheme.surfaceCard
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("EXECUTION MODE")
                .font(AntigravityTheme.TypographyTier.metadata.font)
                .foregroundStyle(AntigravityTheme.inkSecondary)

            HStack(spacing: 10) {
                ForEach(CascadeExecutionMode.allCases) { mode in
                    Button {
                        store.selectedModelConfig.mode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(AntigravityTheme.TypographyTier.chrome.font)
                            .foregroundStyle(store.selectedModelConfig.mode == mode ? AntigravityTheme.inkReading : AntigravityTheme.inkLabel)
                            .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                            .background(
                                store.selectedModelConfig.mode == mode
                                    ? AntigravityTheme.accentPrimary
                                    : AntigravityTheme.surfaceCard
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                isShowingModelSheet = false
            } label: {
                Text("Done")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(AntigravityTheme.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(AntigravityTheme.canvasObsidian)
    }
}
