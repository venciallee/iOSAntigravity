import SwiftUI
import AntigravityData

/// States `S04_PERMISSION_GATE` & `S05_ASK_QUESTION_MODAL`:
/// Handles `CORTEX_STEP_STATUS_WAITING (9)` steps with native Liquid Glass approval sheets
/// (`Allow Once`, `Always Allow in Turn (turnGrants)`, editable command line, `Safe Auto-Accept`,
/// and `ask_question` single/multi-select with custom write-in input).
public struct InteractionGateSheetController: View {
    public enum PresentationMode: Sendable {
        case permissionGate
        case askQuestion
    }

    @Bindable public var store: AntigravitySessionStore
    public var mode: PresentationMode

    @State private var editableCommandLine: String = "python3 verification/esdd-verify.py --suite all"
    @State private var selectedQuestionOptions: Set<String> = [
        "(Recommended) Direct Connect-RPC over WebSocket / HTTPS"
    ]
    @State private var customWriteInAnswer: String = ""

    private let questionOptions: [String] = [
        "(Recommended) Direct Connect-RPC over WebSocket / HTTPS",
        "Google Cloud Relay Tunnel (antigravity.google.com/r/<id>)",
        "Offline Local SQLite Projection Mode Only"
    ]

    public init(store: AntigravitySessionStore, mode: PresentationMode) {
        self.store = store
        self.mode = mode
    }

    private var activeWaitingStepIndex: Int {
        store.pendingWaitingStep?.stepIndex ?? 24
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch mode {
            case .permissionGate:
                permissionGateContent
            case .askQuestion:
                askQuestionContent
            }
        }
        .padding(20)
        .background(AntigravityTheme.canvasObsidian)
        .onAppear {
            if let cmd = store.pendingWaitingStep?.runCommand?.commandLine {
                editableCommandLine = cmd
            }
        }
    }

    // MARK: - 1. Permission Gate Content (S04_PERMISSION_GATE)

    private var permissionGateContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(AntigravityTheme.statusWaiting)
                    Text("Permission Gate · Step #\(activeWaitingStepIndex)")
                        .font(AntigravityTheme.TypographyTier.evidence.font)
                        .foregroundStyle(AntigravityTheme.statusWaiting)
                }
                Spacer()
                Text("WAITING (9)")
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.statusWaiting)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AntigravityTheme.statusWaiting.opacity(0.16))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("PROPOSED TERMINAL COMMAND")
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.inkSecondary)

                TextField("Command line", text: $editableCommandLine, axis: .vertical)
                    .lineLimit(1...4)
                    .font(AntigravityTheme.TypographyTier.metadata.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AntigravityTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("permission-resource-box")

                HStack(spacing: 8) {
                    Text("CWD: \(store.pendingWaitingStep?.runCommand?.cwd ?? "/home/antigravity/venciallee/iOSAntigravity")")
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                        .lineLimit(1)
                    Spacer()
                    if let pattern = store.pendingWaitingStep?.requestedInteraction?.permission?.suggestedPersistPattern {
                        Text("Scope: \(pattern)")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.accentSecondary)
                    }
                }
            }

            Toggle("Safe Auto-Accept Read-Only & In-Workspace Steps", isOn: $store.safeAutoAcceptEnabled)
                .font(AntigravityTheme.TypographyTier.process.font)
                .foregroundStyle(AntigravityTheme.inkLabel)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .accessibilityIdentifier("toggle-safe-auto-accept")

            Button {
                store.resolveWaitingStep(
                    stepIndex: activeWaitingStepIndex,
                    decision: .alwaysAllowInTurn
                )
            } label: {
                Text("Always Allow in Turn (turnGrants)")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
            .background(AntigravityTheme.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("btn-allow-turn-grant")

            HStack(spacing: 12) {
                Button {
                    let original = store.pendingWaitingStep?.runCommand?.commandLine ?? ""
                    let decision: InteractionDecision = (editableCommandLine != original && !editableCommandLine.isEmpty)
                        ? .allowWithModifiedCommand(editableCommandLine)
                        : .allowOnce
                    store.resolveWaitingStep(stepIndex: activeWaitingStepIndex, decision: decision)
                } label: {
                    Text("Allow Once")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                        .foregroundStyle(AntigravityTheme.inkLabel)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-allow-once")

                Button {
                    store.resolveWaitingStep(stepIndex: activeWaitingStepIndex, decision: .reject)
                } label: {
                    Text("Reject")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                        .foregroundStyle(AntigravityTheme.statusError)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-reject-permission")
            }
        }
    }

    // MARK: - 2. Ask Question Content (S05_ASK_QUESTION_MODAL)

    private var askQuestionContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundStyle(AntigravityTheme.accentSecondary)
                Text("Clarification Needed · ask_question")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.accentSecondary)
                Spacer()
            }

            Text("Which transport channel should be the default when pairing a new iOS device?")
                .font(AntigravityTheme.TypographyTier.reading.font)
                .foregroundStyle(AntigravityTheme.inkReading)

            ForEach(Array(questionOptions.enumerated()), id: \.offset) { idx, optionText in
                let isSelected = selectedQuestionOptions.contains(optionText)
                Button {
                    if isSelected && selectedQuestionOptions.count > 1 {
                        selectedQuestionOptions.remove(optionText)
                    } else {
                        selectedQuestionOptions.insert(optionText)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? AntigravityTheme.accentPrimary : AntigravityTheme.inkSecondary)
                        Text(optionText)
                            .font(AntigravityTheme.TypographyTier.evidence.font)
                            .foregroundStyle(AntigravityTheme.inkReading)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(
                    isSelected
                        ? AntigravityTheme.accentPrimary.opacity(0.22)
                        : AntigravityTheme.surfaceCard
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("option-card-\(idx)")
            }

            TextField("Or write a custom answer...", text: $customWriteInAnswer)
                .font(AntigravityTheme.TypographyTier.reading.font)
                .foregroundStyle(AntigravityTheme.inkReading)
                .padding(.horizontal, 14)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("input-custom-writein")

            Button {
                store.resolveWaitingStep(
                    stepIndex: activeWaitingStepIndex,
                    decision: .answerQuestion(
                        selectedOptions: Array(selectedQuestionOptions),
                        customWriteIn: customWriteInAnswer.isEmpty ? nil : customWriteInAnswer
                    )
                )
            } label: {
                Text("Submit Answer")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
            .background(AntigravityTheme.accentPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("btn-submit-answer")
        }
    }
}
