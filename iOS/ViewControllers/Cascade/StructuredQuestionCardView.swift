import SwiftUI
import AntigravityData

/// State `UE10_STRUCTURED_QUESTION`: Interactive Multi-Step Multi-Select Question Card (`iOS · 结构化多选问答（可交互）`).
/// Features:
/// - Header `Audit log for admin actions` (`ledger-svc · Planning · Gemini 3.1 Pro`)
/// - Assistant intro (`Before I draft the plan I need three decisions. Tap to answer — you can also reply in your own words.`)
/// - Interactive card with 3-step pills (`✓ 1 Storage`, `2 Actions` active white pill, `3 Retention`)
/// - `Question 2 of 3 · Select all that apply`, **Which admin actions should be audited?**
/// - 4 checkbox cards (`Account freeze / unfreeze ✓`, `Limit changes ✓`, `Manual ledger adjustments ✓`, `Role & permission changes`)
/// - Dashed `✏️ Something else...` write-in input (`q-input-something-else`)
/// - `Back` (`q-btn-back`) + Periwinkle `Next` (`q-btn-next`) buttons
/// - Bottom `Reply in your own words` + mic bar (`composer-freeform-reply`).
public struct StructuredQuestionCardView: View {
    private struct QuestionStepModel: Identifiable {
        let index: Int
        let pillLabel: String
        let pillTestId: String
        let prompt: String
        let options: [(title: String, testId: String)]

        var id: Int { index }
    }

    @Bindable public var store: AntigravitySessionStore

    @State private var currentStepIndex: Int = 1 // Default to `2 Actions` (0-based index 1)
    @State private var completedSteps: Set<Int> = [0]
    @State private var selectedByStep: [Int: Set<String>] = [
        0: ["Dedicated audit_events table (PostgreSQL)"],
        1: [
            "Account freeze / unfreeze",
            "Limit changes",
            "Manual ledger adjustments"
        ],
        2: ["7 years (SOC2 + financial compliance)"]
    ]
    @State private var somethingElseText: String = ""
    @State private var freeformReplyText: String = ""

    private static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    private static let emeraldDone = Color(red: 0x57 / 255.0, green: 0xC8 / 255.0, blue: 0x8A / 255.0) // #57C88A
    private static let inkOnCTA = Color(red: 0x0A / 255.0, green: 0x0E / 255.0, blue: 0x17 / 255.0) // #0A0E17
    private static let cardSurface = Color(red: 0x14 / 255.0, green: 0x15 / 255.0, blue: 0x19 / 255.0) // #141519
    private static let optionUnselectedBg = Color(red: 0x1B / 255.0, green: 0x1C / 255.0, blue: 0x22 / 255.0)
    private static let optionSelectedBg = Color(red: 0x19 / 255.0, green: 0x20 / 255.0, blue: 0x2F / 255.0)
    private static let pillBg = Color(red: 0x20 / 255.0, green: 0x22 / 255.0, blue: 0x2A / 255.0)

    private let steps: [QuestionStepModel] = [
        QuestionStepModel(
            index: 0,
            pillLabel: "1 Storage",
            pillTestId: "q-step-1-storage",
            prompt: "Where should immutable admin audit events be stored?",
            options: [
                ("Dedicated audit_events table (PostgreSQL)", "q-opt-storage-pg"),
                ("Append-only Kafka topic + S3 sink", "q-opt-storage-kafka"),
                ("Both transactional DB outbox and S3 archive", "q-opt-storage-both")
            ]
        ),
        QuestionStepModel(
            index: 1,
            pillLabel: "2 Actions",
            pillTestId: "q-step-2-actions",
            prompt: "Which admin actions should be audited?",
            options: [
                ("Account freeze / unfreeze", "q-opt-freeze"),
                ("Limit changes", "q-opt-limit"),
                ("Manual ledger adjustments", "q-opt-ledger"),
                ("Role & permission changes", "q-opt-role")
            ]
        ),
        QuestionStepModel(
            index: 2,
            pillLabel: "3 Retention",
            pillTestId: "q-step-3-retention",
            prompt: "How long should audit records be retained online?",
            options: [
                ("90 days hot + glacier archive", "q-opt-ret-90d"),
                ("1 year hot queryable", "q-opt-ret-1y"),
                ("7 years (SOC2 + financial compliance)", "q-opt-ret-7y")
            ]
        )
    ]

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    private var activeStep: QuestionStepModel {
        steps[min(max(0, currentStepIndex), steps.count - 1)]
    }

    public var body: some View {
        VStack(spacing: 0) {
            topNavigationBar

            Divider()
                .overlay(Color.white.opacity(0.06))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Assistant Intro
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                            .padding(.top, 4)

                        Text("Before I draft the plan I need three decisions. Tap to answer — you can also reply in your own words.")
                            .font(.system(size: 15))
                            .foregroundStyle(AntigravityTheme.inkReading)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Interactive Structured Question Card
                    questionWizardCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            // Bottom `Reply in your own words` + Mic Bar
            freeformComposerBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(AntigravityTheme.canvasObsidian)
    }

    // MARK: - Top Navigation Bar

    private var topNavigationBar: some View {
        HStack(spacing: 8) {
            Button {
                store.currentRoute = .chatAndComposer
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Self.periwinkle)
                    .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-back-from-question")

            VStack(alignment: .leading, spacing: 2) {
                Text("Audit log for admin actions")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .lineLimit(1)
                Text("ledger-svc · Planning · Gemini 3.1 Pro")
                    .font(.system(size: 12))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                store.currentRoute = .chatAndComposer
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    // MARK: - Interactive Question Wizard Card

    private var questionWizardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 3-Step Pills (`✓ 1 Storage`, `2 Actions`, `3 Retention`)
            HStack(spacing: 8) {
                ForEach(steps) { step in
                    let isActive = step.index == currentStepIndex
                    let isDone = completedSteps.contains(step.index) && !isActive
                    Button {
                        currentStepIndex = step.index
                    } label: {
                        HStack(spacing: 5) {
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Self.emeraldDone)
                            }
                            Text(step.pillLabel)
                                .font(.system(size: 12.5, weight: isActive ? .bold : .medium))
                                .foregroundStyle(
                                    isActive
                                        ? Color(red: 0.04, green: 0.04, blue: 0.05)
                                        : AntigravityTheme.inkSecondary
                                )
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                        .background(isActive ? Color.white : Self.pillBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(step.pillTestId)
                }
            }

            // Question Metadata & Heading
            VStack(alignment: .leading, spacing: 4) {
                Text("Question \(currentStepIndex + 1) of \(steps.count) · Select all that apply")
                    .font(.system(size: 13))
                    .foregroundStyle(AntigravityTheme.inkSecondary)

                Text(activeStep.prompt)
                    .font(.system(size: 18.5, weight: .bold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Multi-Select Option Cards
            VStack(spacing: 9) {
                ForEach(activeStep.options, id: \.title) { option in
                    optionCheckboxRow(title: option.title, testId: option.testId)
                }
            }

            // Dashed `✏️ Something else...` Input
            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AntigravityTheme.inkSecondary)

                TextField("Something else...", text: $somethingElseText)
                    .font(.system(size: 15))
                    .foregroundStyle(AntigravityTheme.inkReading)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
            .accessibilityIdentifier("q-input-something-else")

            // Footer `Back` + Periwinkle `Next`
            HStack(spacing: 10) {
                Button {
                    if currentStepIndex > 0 {
                        currentStepIndex -= 1
                    }
                } label: {
                    Text("Back")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .padding(.horizontal, 22)
                        .frame(minWidth: 88, minHeight: 48)
                        .background(Self.pillBg)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("q-btn-back")

                Button {
                    completedSteps.insert(currentStepIndex)
                    if currentStepIndex < steps.count - 1 {
                        currentStepIndex += 1
                    } else {
                        submitStructuredAnswers()
                    }
                } label: {
                    Text(currentStepIndex < steps.count - 1 ? "Next" : "Submit")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Self.inkOnCTA)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Self.periwinkle)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("q-btn-next")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(Self.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func optionCheckboxRow(title: String, testId: String) -> some View {
        let stepSelections = selectedByStep[currentStepIndex] ?? []
        let isSelected = stepSelections.contains(title)

        return Button {
            var updated = selectedByStep[currentStepIndex] ?? []
            if isSelected {
                updated.remove(title)
            } else {
                updated.insert(title)
            }
            selectedByStep[currentStepIndex] = updated
        } label: {
            HStack(spacing: 12) {
                if isSelected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Self.periwinkle)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Self.inkOnCTA)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }

                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(isSelected ? Self.optionSelectedBg : Self.optionUnselectedBg)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Self.periwinkle : Color.white.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(testId)
    }

    // MARK: - Bottom Freeform Composer Bar

    private var freeformComposerBar: some View {
        HStack(spacing: 10) {
            TextField("Reply in your own words", text: $freeformReplyText)
                .font(.system(size: 15))
                .foregroundStyle(AntigravityTheme.inkReading)
                .onSubmit {
                    submitFreeformReply()
                }

            Button {
                submitFreeformReply()
            } label: {
                ZStack {
                    Circle()
                        .fill(Self.pillBg)
                        .frame(width: 36, height: 36)
                    Image(systemName: "mic")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AntigravityTheme.inkLabel)
                }
                .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: 50)
        .background(Self.cardSurface)
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(Capsule())
        .accessibilityIdentifier("composer-freeform-reply")
    }

    private func submitStructuredAnswers() {
        let answers = selectedByStep[currentStepIndex].map(Array.init) ?? []
        if let waiting = store.pendingWaitingStep {
            store.resolveWaitingStep(
                stepIndex: waiting.stepIndex,
                decision: .answerQuestion(
                    selectedOptions: answers,
                    customWriteIn: somethingElseText.isEmpty ? nil : somethingElseText
                )
            )
        }
        store.currentRoute = .chatAndComposer
    }

    private func submitFreeformReply() {
        let trimmed = freeformReplyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.composerDraftText = trimmed
        store.sendCurrentDraft()
        freeformReplyText = ""
        store.currentRoute = .chatAndComposer
    }
}
