import SwiftUI
import AntigravityData
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

// MARK: - UE07 Native Chat Stream Cards (`StepCellViews.swift`)

private enum StepCardPalette {
    static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    static let warmAmber = Color(red: 0xEB / 255.0, green: 0xB3 / 255.0, blue: 0x65 / 255.0) // #EBB365
    static let emeraldDone = Color(red: 0x57 / 255.0, green: 0xC8 / 255.0, blue: 0x8A / 255.0) // #57C88A
    static let inkOnCTA = Color(red: 0x0A / 255.0, green: 0x0E / 255.0, blue: 0x17 / 255.0) // #0A0E17
    static let cardSurface = Color(red: 0x14 / 255.0, green: 0x15 / 255.0, blue: 0x19 / 255.0) // #141519
    static let amberCardSurface = Color(red: 0x1A / 255.0, green: 0x16 / 255.0, blue: 0x0E / 255.0)
    static let codeBlockBg = Color(red: 0x0C / 255.0, green: 0x0D / 255.0, blue: 0x10 / 255.0)
    static let neutralButtonBg = Color(red: 0x24 / 255.0, green: 0x24 / 255.0, blue: 0x28 / 255.0)
    static let darkTrack = Color(red: 0x26 / 255.0, green: 0x29 / 255.0, blue: 0x32 / 255.0)
}

/// Previous user prompt bubble with context chips `[@transfers.go]` `[Skill · go-testing]`.
public struct UserPromptContextBubbleView: View {
    public let promptText: String?
    public let contextChips: [String]

    public init(
        promptText: String? = nil,
        contextChips: [String] = ["@transfers.go", "Skill · go-testing"]
    ) {
        self.promptText = promptText
        self.contextChips = contextChips
    }

    public var body: some View {
        HStack {
            Spacer(minLength: 36)
            VStack(alignment: .leading, spacing: 6) {
                if let promptText, !promptText.isEmpty {
                    Text(promptText)
                        .font(.system(size: 14.5))
                        .foregroundStyle(AntigravityTheme.inkReading)
                }

                if !contextChips.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(contextChips, id: \.self) { chip in
                            Text(chip)
                                .font(.system(size: 12, weight: .medium, design: chip.hasPrefix("@") ? .monospaced : .default))
                                .foregroundStyle(AntigravityTheme.inkLabel)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AntigravityTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

/// Collapsible `👁 Thought for 14s ›` reasoning row (`row-thought-14s`).
public struct CollapsibleThoughtRowView: View {
    public let durationSeconds: Int
    public let reasoningSummary: String
    @State private var isExpanded: Bool = false

    public init(
        durationSeconds: Int = 14,
        reasoningSummary: String = "Inspected internal/middleware router chain, verified token-bucket concurrency lock contention, and prepared vegeta load profile."
    ) {
        self.durationSeconds = durationSeconds
        self.reasoningSummary = reasoningSummary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                    Text("Thought for \(durationSeconds)s")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                    Spacer()
                }
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("row-thought-14s")

            if isExpanded {
                Text(reasoningSummary)
                    .font(.system(size: 13))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(StepCardPalette.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

/// Embedded **Implementation Plan** artifact card (`card-artifact-plan`), navigating to `.planReview`.
public struct EmbeddedImplementationPlanCardView: View {
    public let title: String
    public let statusSubtitle: String
    public let onTap: () -> Void

    public init(
        title: String = "Implementation Plan",
        statusSubtitle: String = "Approved · 2 comments addressed",
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.statusSubtitle = statusSubtitle
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(StepCardPalette.periwinkle.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: "doc.text")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(StepCardPalette.periwinkle)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                    Text(statusSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .background(StepCardPalette.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("card-artifact-plan")
    }
}

/// **7-Segment `Task · 4 of 7 done` (`2m 41s`) Progress Card** (`card-task-progress-7seg`):
/// 4 periwinkle segments, 1 warm amber segment, 2 dark segments + checklist.
public struct SevenSegmentTaskProgressCardView: View {
    public let completedCount: Int
    public let totalCount: Int
    public let elapsedLabel: String

    public init(
        completedCount: Int = 4,
        totalCount: Int = 7,
        elapsedLabel: String = "2m 41s"
    ) {
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.elapsedLabel = elapsedLabel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Task · \(completedCount) of \(totalCount) done")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                Spacer()
                Text(elapsedLabel)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
            }

            // 7-Segment Capsule Bar: 4 Periwinkle + 1 Warm Amber + 2 Dark
            HStack(spacing: 5) {
                ForEach(0..<totalCount, id: \.self) { index in
                    Capsule()
                        .fill(segmentColor(at: index))
                        .frame(height: 4)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                // Row 1: ✓ Wire limiter into router
                HStack(spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(StepCardPalette.emeraldDone)
                        .frame(width: 12)
                    Text("Wire limiter into router")
                        .font(.system(size: 13.5))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                    Spacer()
                }

                // Row 2: ✓ go test ./internal/...    42 passed
                HStack(spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(StepCardPalette.emeraldDone)
                        .frame(width: 12)
                    Text("go test ./internal/...")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                    Spacer()
                    Text("42 passed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(StepCardPalette.emeraldDone)
                }

                // Row 3: 🟠 Load test with vegeta
                HStack(spacing: 9) {
                    Circle()
                        .fill(StepCardPalette.warmAmber)
                        .frame(width: 8, height: 8)
                        .frame(width: 12)
                    Text("Load test with vegeta")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(StepCardPalette.warmAmber)
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(StepCardPalette.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card-task-progress-7seg")
    }

    private func segmentColor(at index: Int) -> Color {
        if index < completedCount {
            return StepCardPalette.periwinkle
        }
        if index == completedCount {
            return StepCardPalette.warmAmber
        }
        return StepCardPalette.darkTrack
    }
}

/// **Inline `Run this command?` Amber Approval Card** (`card-command-approval`):
/// Displays monospaced `vegeta attack` command with left `Deny` (`btn-command-deny`)
/// and right warm amber `#EBB365` Face ID `Allow` (`btn-command-allow-faceid`).
public struct InlineCommandApprovalCardView: View {
    @Bindable public var store: AntigravitySessionStore
    public let commandLine: String
    @State private var resolutionState: String? = nil

    public init(
        store: AntigravitySessionStore,
        commandLine: String = "vegeta attack -rate=2000/s -duration=30s \\\n  -targets=load/transfers.txt | vegeta\nreport"
    ) {
        self.store = store
        self.commandLine = commandLine
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StepCardPalette.warmAmber)
                Text(resolutionState ?? "Run this command?")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(StepCardPalette.warmAmber)
                Spacer()
            }

            Text(commandLine)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(AntigravityTheme.inkReading)
                .lineSpacing(2)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StepCardPalette.codeBlockBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    resolutionState = "Command denied"
                    if let waiting = store.pendingWaitingStep {
                        store.resolveWaitingStep(stepIndex: waiting.stepIndex, decision: .reject)
                    }
                } label: {
                    Text("Deny")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(StepCardPalette.neutralButtonBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-command-deny")

                Button {
                    authenticateWithFaceIDAndApprove()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "faceid")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Allow")
                            .font(.system(size: 14.5, weight: .bold))
                    }
                    .foregroundStyle(StepCardPalette.inkOnCTA)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(StepCardPalette.warmAmber)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn-command-allow-faceid")
            }
        }
        .padding(14)
        .background(StepCardPalette.amberCardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(StepCardPalette.warmAmber.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card-command-approval")
    }

    private func authenticateWithFaceIDAndApprove() {
        Task {
            let outcome = await StepBiometricGate.evaluate(
                reason: "Approve vegeta load-test command on MacBook Pro",
                cancelTitle: "Cancel"
            )
            if outcome == .verified || outcome == .unavailable {
                commitFaceIDApproval()
            }
        }
    }

    private func commitFaceIDApproval() {
        resolutionState = "Approved with Face ID"
        store.approveWaitingCommandWithFaceID()
    }
}

private enum StepBiometricGate {
    enum Outcome: Sendable {
        case verified
        case unavailable
        case failedOrCancelled
    }

    static func evaluate(reason: String, cancelTitle: String? = nil) async -> Outcome {
        #if canImport(LocalAuthentication)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
            let context = LAContext()
            if let cancelTitle {
                context.localizedCancelTitle = cancelTitle
            }
            var authError: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
                continuation.resume(returning: .unavailable)
                return
            }
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, _ in
                continuation.resume(returning: success ? .verified : .failedOrCancelled)
            }
        }
        #else
        return .unavailable
        #endif
    }
}

// MARK: - Live Trajectory Step Cell Views (Preserved for Streaming Steps)

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

    private var summaryTitle: String {
        let editCount = steps.filter { $0.codeAction != nil }.count
        if editCount == steps.count && editCount > 0 {
            return "Edited \(editCount) workspace file\(editCount == 1 ? "" : "s")"
        } else if editCount > 0 {
            return "Inspected & edited \(steps.count) workspace items"
        } else {
            return "Inspected \(steps.count) workspace file\(steps.count == 1 ? "" : "s")"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    store.toggleEvidenceGroupExpanded(groupId: groupId)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(StepCardPalette.periwinkle)
                    Text(summaryTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AntigravityTheme.inkReading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                }
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(steps) { step in
                    if let ca = step.codeAction {
                        Button {
                            store.selectedDiffFilePath = ca.fileName
                            store.currentRoute = .turnDiffReview
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(StepCardPalette.periwinkle)
                                Text(ca.fileName)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(AntigravityTheme.inkReading)
                                    .lineLimit(1)
                                Spacer()
                                if ca.additions > 0 || ca.deletions > 0 {
                                    Text("+\(ca.additions) -\(ca.deletions)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(StepCardPalette.emeraldDone)
                                }
                            }
                            .frame(minHeight: 34)
                        }
                        .buttonStyle(.plain)
                    } else if let vf = step.viewFile {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 11.5))
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                            Text(vf.fileName)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(AntigravityTheme.inkReading)
                                .lineLimit(1)
                            Spacer()
                            Text("L\(vf.startLine)–\(vf.endLine)")
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                        }
                        .frame(minHeight: 30)
                    } else if let sc = step.search {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11.5))
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                            Text(sc.query)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(AntigravityTheme.inkReading)
                                .lineLimit(1)
                            Spacer()
                            if sc.matchCount > 0 {
                                Text("\(sc.matchCount) matches")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(AntigravityTheme.inkSecondary)
                            }
                        }
                        .frame(minHeight: 30)
                    }
                }
            }
        }
        .padding(12)
        .background(StepCardPalette.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

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
            UserPromptContextBubbleView(
                promptText: step.userInput,
                contextChips: step.attachedMentions
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("step-user-\(step.stepIndex)")
        case .plannerResponse, .notifyUser:
            VStack(alignment: .leading, spacing: 8) {
                if let thinking = step.plannerResponse?.thinking, !thinking.isEmpty {
                    CollapsibleThoughtRowView(
                        durationSeconds: max(1, Int(step.plannerResponse?.thinkingDurationSeconds ?? 4)),
                        reasoningSummary: thinking
                    )
                }
                if let prose = step.plannerResponse?.response, !prose.isEmpty {
                    Text(prose)
                        .font(.system(size: 15.5))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("step-prose-\(step.stepIndex)")
                }
            }
        case .taskBoundary:
            if let tb = step.taskBoundary {
                SevenSegmentTaskProgressCardView(
                    completedCount: tb.completedCount,
                    totalCount: max(1, tb.totalCount),
                    elapsedLabel: tb.elapsedLabel
                )
            }
        case .runCommand:
            if let cmd = step.runCommand {
                if step.status == .waiting {
                    InlineCommandApprovalCardView(store: store, commandLine: cmd.commandLine)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(StepCardPalette.periwinkle)
                            Text(cmd.commandLine)
                                .font(.system(size: 12.5, design: .monospaced))
                                .foregroundStyle(AntigravityTheme.inkReading)
                                .lineLimit(2)
                            Spacer()
                            if let code = cmd.exitCode {
                                Text(code == 0 ? "exit 0" : "exit \(code)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(code == 0 ? StepCardPalette.emeraldDone : AntigravityTheme.statusError)
                            }
                        }
                        if let out = cmd.outputPreview, !out.isEmpty {
                            Text(out)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                                .lineLimit(4)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(StepCardPalette.codeBlockBg)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(11)
                    .background(StepCardPalette.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        case .codeAction:
            if let ca = step.codeAction {
                HStack(spacing: 10) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(StepCardPalette.periwinkle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ca.fileName)
                            .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AntigravityTheme.inkReading)
                        Text(ca.description)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if ca.additions > 0 || ca.deletions > 0 {
                        Text("+\(ca.additions) -\(ca.deletions)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(StepCardPalette.emeraldDone)
                    }
                }
                .padding(12)
                .background(StepCardPalette.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        default:
            if let prose = step.plannerResponse?.response, !prose.isEmpty {
                Text(prose)
                    .font(.system(size: 15.5))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .lineSpacing(3)
            }
        }
    }
}
