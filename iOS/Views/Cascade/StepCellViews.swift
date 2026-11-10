import SwiftUI
import AntigravityData

/// Renders a grouped card of consecutive file reads (`view_file`), searches (`grep_search`),
/// and file edits (`codeAction`) inside `CascadeChatViewController`.
public struct CascadeEvidenceGroupCardView: View {
    @Bindable public var store: AntigravitySessionStore
    public let groupId: String
    public let steps: [CascadeStep]

    public init(store: AntigravitySessionStore, groupId: String, steps: [CascadeStep]) {
        self.store = store
        self.groupId = groupId
        self.steps = steps
    }

    private var isExpanded: Bool {
        store.expandedEvidenceGroupIds.contains(groupId)
    }

    private var totalAdditions: Int {
        steps.compactMap(\.codeAction?.additions).reduce(0, +)
    }

    private var totalDeletions: Int {
        steps.compactMap(\.codeAction?.deletions).reduce(0, +)
    }

    private var primaryTitle: String {
        let editedFiles = steps.compactMap(\.codeAction?.fileName)
        let viewedFiles = steps.compactMap(\.viewFile?.fileName)
        if let firstEdit = editedFiles.first {
            return steps.count > 1
                ? "Edited \(firstEdit) & \(steps.count - 1) more file operations"
                : "Edited \(firstEdit)"
        } else if let firstView = viewedFiles.first {
            return "Inspected \(firstView) (\(steps.count) operations)"
        }
        return "Workspace Evidence (\(steps.count) steps)"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    store.toggleEvidenceGroupExpanded(groupId: groupId)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundStyle(AntigravityTheme.accentSecondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(primaryTitle)
                            .font(AntigravityTheme.TypographyTier.evidence.font)
                            .foregroundStyle(AntigravityTheme.inkLabel)
                        Text("Steps #\(steps.first?.stepIndex ?? 0)–#\(steps.last?.stepIndex ?? 0) · Tap to \(isExpanded ? "collapse" : "inspect")")
                            .font(AntigravityTheme.TypographyTier.process.font)
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                    }
                    Spacer()
                    if totalAdditions > 0 || totalDeletions > 0 {
                        Text("+\(totalAdditions) -\(totalDeletions)")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.statusDone)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                }
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .overlay(AntigravityTheme.glassHairline)

                ForEach(steps) { step in
                    if let ca = step.codeAction {
                        Button {
                            store.selectedDiffFilePath = ca.fileName
                            store.currentRoute = .turnDiffInspector
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "pencil.line")
                                        .foregroundStyle(AntigravityTheme.accentPrimary)
                                    Text(ca.fileName)
                                        .font(AntigravityTheme.TypographyTier.evidence.font)
                                        .foregroundStyle(AntigravityTheme.inkReading)
                                    Spacer()
                                    Text("+\(ca.additions) -\(ca.deletions)")
                                        .font(AntigravityTheme.TypographyTier.metadata.font)
                                        .foregroundStyle(AntigravityTheme.statusDone)
                                }
                                Text(ca.description)
                                    .font(AntigravityTheme.TypographyTier.process.font)
                                    .foregroundStyle(AntigravityTheme.inkSecondary)
                                if !ca.diffPreviewLines.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(ca.diffPreviewLines, id: \.self) { line in
                                            Text(line)
                                                .font(AntigravityTheme.TypographyTier.metadata.font)
                                                .foregroundStyle(AntigravityTheme.statusDone)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AntigravityTheme.surfaceObsidian)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    } else if let vf = step.viewFile {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                            Text("Viewed \(vf.fileName) (L\(vf.startLine)–\(vf.endLine))")
                                .font(AntigravityTheme.TypographyTier.process.font)
                                .foregroundStyle(AntigravityTheme.inkLabel)
                            Spacer()
                            Text("\(vf.totalLines) lines")
                                .font(AntigravityTheme.TypographyTier.metadata.font)
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(12)
        .background(AntigravityTheme.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("step-file-evidence-group")
    }
}

/// Renders individual `CascadeStep` items into native iOS cards following the 5-tier
/// typography hierarchy (Reading, Evidence, Process, Metadata, Chrome).
public struct CascadeStepCellView: View {
    @Bindable public var store: AntigravitySessionStore
    public let step: CascadeStep

    public init(store: AntigravitySessionStore, step: CascadeStep) {
        self.store = store
        self.step = step
    }

    public var body: some View {
        switch step.type {
        case .userInput:
            userInputBubble

        case .plannerResponse:
            plannerResponseSection

        case .codeAction:
            codeActionCard

        case .runCommand:
            terminalCommandCard

        case .taskBoundary:
            inlineTaskBoundaryMilestone

        default:
            EmptyView()
        }
    }

    // MARK: - 1. User Input Message Bubble

    private var userInputBubble: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !step.attachedMentions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(step.attachedMentions, id: \.self) { mention in
                        Text(mention)
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.accentSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AntigravityTheme.surfaceElevated)
                            .clipShape(Capsule())
                    }
                }
            }

            Text(step.userInput ?? "")
                .font(AntigravityTheme.TypographyTier.reading.font)
                .foregroundStyle(AntigravityTheme.inkReading)
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [
                            AntigravityTheme.accentPrimary.opacity(0.32),
                            AntigravityTheme.surfaceCard
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityIdentifier("step-user-input-\(step.stepIndex)")
    }

    // MARK: - 2. Planner Response + Collapsible Thinking Capsule

    private var plannerResponseSection: some View {
        let isThinkingOpen = store.expandedThinkingStepIds.contains(step.id)
        return VStack(alignment: .leading, spacing: 10) {
            if let thinking = step.plannerResponse?.thinking {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.toggleThinkingExpanded(stepId: step.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AntigravityTheme.accentSecondary)
                            Text("Thought for \(String(format: "%.1fs", step.plannerResponse?.thinkingDurationSeconds ?? 3.4)) · \(thinking)")
                                .font(AntigravityTheme.TypographyTier.process.font)
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                                .lineLimit(isThinkingOpen ? nil : 1)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: isThinkingOpen ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                        .background(AntigravityTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("step-thinking-capsule")
                }
            }

            Text(step.plannerResponse?.response ?? "")
                .font(AntigravityTheme.TypographyTier.reading.font)
                .foregroundStyle(AntigravityTheme.inkReading)
                .fixedSize(horizontal: false, vertical: true)

            if let refs = step.plannerResponse?.referencedFiles, !refs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(refs, id: \.self) { refPath in
                            Button {
                                store.selectedDiffFilePath = refPath
                                store.currentRoute = .turnDiffInspector
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 11))
                                    Text((refPath as NSString).lastPathComponent)
                                        .font(AntigravityTheme.TypographyTier.metadata.font)
                                }
                                .foregroundStyle(AntigravityTheme.accentSecondary)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 34)
                                .background(AntigravityTheme.surfaceElevated)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 3. Standalone Code Action Card

    private var codeActionCard: some View {
        Group {
            if let ca = step.codeAction {
                Button {
                    store.selectedDiffFilePath = ca.fileName
                    store.currentRoute = .turnDiffInspector
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ca.fileName)
                                .font(AntigravityTheme.TypographyTier.evidence.font)
                                .foregroundStyle(AntigravityTheme.inkLabel)
                            Text(ca.description)
                                .font(AntigravityTheme.TypographyTier.process.font)
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("+\(ca.additions) -\(ca.deletions)")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.statusDone)
                    }
                    .padding(12)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(AntigravityTheme.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("step-file-evidence-group")
            }
        }
    }

    // MARK: - 4. Native Terminal Card + Inline WAITING Permission Gate

    private var terminalCommandCard: some View {
        Group {
            if let cmd = step.runCommand {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("$ \(cmd.commandLine)")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.inkLabel)
                            .lineLimit(2)
                        Spacer()
                        Text(step.status == .waiting ? "WAITING" : "EXIT \(cmd.exitCode ?? 0)")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(
                                step.status == .waiting
                                    ? AntigravityTheme.statusWaiting
                                    : AntigravityTheme.statusDone
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (step.status == .waiting
                                    ? AntigravityTheme.statusWaiting
                                    : AntigravityTheme.statusDone).opacity(0.16)
                            )
                            .clipShape(Capsule())
                    }

                    if let output = cmd.outputPreview {
                        Text(output)
                            .font(AntigravityTheme.TypographyTier.process.font)
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AntigravityTheme.surfaceObsidian)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Inline WAITING Permission Gate controls directly inside the terminal step card
                    if step.status == .waiting {
                        HStack(spacing: 8) {
                            Button {
                                store.resolveWaitingStep(stepIndex: step.stepIndex, decision: .alwaysAllowInTurn)
                            } label: {
                                Text("Always Allow in Turn")
                                    .font(AntigravityTheme.TypographyTier.chrome.font)
                                    .foregroundStyle(AntigravityTheme.inkReading)
                                    .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                                    .background(AntigravityTheme.accentPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("inline-btn-allow-turn")

                            Button {
                                store.resolveWaitingStep(stepIndex: step.stepIndex, decision: .allowOnce)
                            } label: {
                                Text("Allow Once")
                                    .font(AntigravityTheme.TypographyTier.chrome.font)
                                    .foregroundStyle(AntigravityTheme.inkLabel)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                                    .background(AntigravityTheme.surfaceCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("inline-btn-allow-once")

                            Button {
                                store.resolveWaitingStep(stepIndex: step.stepIndex, decision: .reject)
                            } label: {
                                Text("Reject")
                                    .font(AntigravityTheme.TypographyTier.chrome.font)
                                    .foregroundStyle(AntigravityTheme.statusError)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                                    .background(AntigravityTheme.surfaceCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("inline-btn-reject")
                        }
                    }
                }
                .padding(12)
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("step-terminal-card")
            }
        }
    }

    // MARK: - 5. Inline TaskBoundary Milestone

    private var inlineTaskBoundaryMilestone: some View {
        Group {
            if let tb = step.taskBoundary {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AntigravityTheme.accentPrimary)
                    Text(tb.taskName)
                        .font(AntigravityTheme.TypographyTier.process.font)
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
    }
}
