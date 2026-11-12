import SwiftUI
import AntigravityData

/// Native Matte Obsidian / Liquid Glass Composer (`ChatComposerView`) pinned at the bottom of `UE07_CHAT_AND_COMPOSER`.
/// Features:
/// - Removable `[@ratelimit.go ×]` context chip (`composer-chip-ratelimit`)
/// - Multi-line `TextField` (`Use 1000/s instead — staging is smaller than prod.`)
/// - Bottom toolbar with circular `+` (`composer-btn-add-context` -> `AddContextSheetView`),
///   `[Planning ⌄]` pill (`composer-pill-mode` -> `ModelAndModeSheetView`),
///   `[Gemini 3.1 Pro ⌄]` pill (`composer-pill-model` -> `ModelAndModeSheetView`),
///   `mic` button, and circular `#8EB4FF` Periwinkle Send button (`composer-btn-send`).
public struct ChatComposerView: View {
    @Bindable public var store: AntigravitySessionStore
    @FocusState private var isInputFocused: Bool

    @State private var attachedChipLabels: [String]
    @State private var draftMessageText: String
    @State private var isShowingAddContextSheet: Bool = false
    @State private var isShowingModelAndModeSheet: Bool = false

    private static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    private static let inkOnCTA = Color(red: 0x0A / 255.0, green: 0x0E / 255.0, blue: 0x17 / 255.0) // #0A0E17
    private static let composerCardBg = Color(red: 0x14 / 255.0, green: 0x15 / 255.0, blue: 0x19 / 255.0) // #141519
    private static let controlPillBg = Color(red: 0x20 / 255.0, green: 0x22 / 255.0, blue: 0x2A / 255.0)

    public init(store: AntigravitySessionStore) {
        self.store = store
        if !store.isVerificationMode || store.hasPairedBackend || store.isLiveBackendConnected {
            self._attachedChipLabels = State(initialValue: store.composerAttachments.map(\.label))
            self._draftMessageText = State(initialValue: store.composerDraftText)
        } else {
            self._attachedChipLabels = State(initialValue: ["@ratelimit.go"])
            self._draftMessageText = State(initialValue: "Use 1000/s instead — staging is smaller than prod.")
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Context Chips Strip
            if !attachedChipLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachedChipLabels, id: \.self) { label in
                            Button {
                                attachedChipLabels.removeAll { $0 == label }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(label)
                                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(AntigravityTheme.inkReading)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(AntigravityTheme.inkSecondary)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                                .background(Self.controlPillBg)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                label.contains("ratelimit")
                                    ? "composer-chip-ratelimit"
                                    : "composer-chip-\(label)"
                            )
                        }
                    }
                }
            }

            // Multi-line Draft Input
            TextField(
                "Reply to agent or @mention files...",
                text: $draftMessageText,
                axis: .vertical
            )
            .lineLimit(1...4)
            .font(.system(size: 15.5))
            .foregroundStyle(AntigravityTheme.inkReading)
            .focused($isInputFocused)
            .onSubmit {
                submitMessage()
            }
            .padding(.horizontal, 2)
            .accessibilityIdentifier("composer-text-input")

            // Bottom Toolbar: `+`, `Planning ⌄`, `<Active Model> ⌄`, `mic`, `↑` Send
            HStack(spacing: 5) {
                // 1. Circular `+` Add Context Button
                Button {
                    isShowingAddContextSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                        .background(Self.controlPillBg)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("composer-btn-add-context")

                // 2. `[Planning / Fast ⌄]` Mode Pill (bound directly to `store.selectedModelConfig.mode`)
                Button {
                    isShowingModelAndModeSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text(store.selectedModelConfig.mode.rawValue)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AntigravityTheme.inkReading)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(minWidth: AntigravityTheme.minTouchTargetPt, minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(Self.controlPillBg)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("composer-pill-mode")

                // 3. `[<Active Model> ⌄]` Model Pill (bound directly to `store.selectedModelConfig.displayName`)
                Button {
                    isShowingModelAndModeSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text(store.selectedModelConfig.displayName)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AntigravityTheme.inkLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                    }
                    .padding(.horizontal, 9)
                    .frame(minWidth: AntigravityTheme.minTouchTargetPt, minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(Self.controlPillBg)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("composer-pill-model")

                Spacer(minLength: 0)

                // 4. Voice Dictation Mic Button
                Button {
                    isInputFocused = true
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                        .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("composer-btn-mic")

                // 5. Circular `#8EB4FF` Periwinkle Send Button
                Button {
                    submitMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Self.inkOnCTA)
                        .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
                        .background(Self.periwinkle)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("composer-btn-send")
            }
        }
        .padding(10)
        .background(Self.composerCardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            if !store.composerDraftText.isEmpty {
                draftMessageText = store.composerDraftText
            }
        }
        .sheet(isPresented: $isShowingAddContextSheet) {
            AddContextSheetView(
                store: store,
                onAddLabels: { added in
                    for item in added where !attachedChipLabels.contains(item) {
                        attachedChipLabels.append(item)
                    }
                },
                onDismiss: {
                    isShowingAddContextSheet = false
                }
            )
        }
        .sheet(isPresented: $isShowingModelAndModeSheet) {
            ModelAndModeSheetView(
                store: store,
                onDismiss: {
                    isShowingModelAndModeSheet = false
                }
            )
        }
    }

    private func submitMessage() {
        let trimmed = draftMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachedChipLabels.isEmpty else { return }
        store.composerAttachments = attachedChipLabels.map { label in
            let cleanFile = label.replacingOccurrences(of: "@", with: "")
            let targetUri: String
            if store.selectedWorkspaceUri.hasPrefix("cloud://") || store.selectedWorkspaceUri.isEmpty {
                targetUri = store.isVerificationMode
                    ? "file:///Users/wl/code/ledger-svc/\(cleanFile)"
                    : "antigravity://file/\(cleanFile)"
            } else {
                let rawPath = store.selectedWorkspaceUri
                    .replacingOccurrences(of: "file://", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                targetUri = "file:///\(rawPath)/\(cleanFile)"
            }
            return ComposerAttachmentChip(
                kind: .fileMention,
                label: label,
                targetUri: targetUri
            )
        }
        store.composerDraftText = trimmed
        store.sendCurrentDraft()
        draftMessageText = ""
        attachedChipLabels.removeAll()
    }
}
