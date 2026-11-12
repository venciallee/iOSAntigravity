import SwiftUI
import AntigravityData
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - UE07 Native Chat Stream Cards (`StepCellViews.swift`)

private enum StepCardPalette {
    static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    static let warmAmber = Color(red: 0xEB / 255.0, green: 0xB3 / 255.0, blue: 0x65 / 255.0) // #EBB365
    static let emeraldDone = Color(red: 0x57 / 255.0, green: 0xC8 / 255.0, blue: 0x8A / 255.0) // #57C88A
    static let coralError = Color(red: 0xF0 / 255.0, green: 0x71 / 255.0, blue: 0x67 / 255.0) // #F07167
    static let softViolet = Color(red: 0xA7 / 255.0, green: 0x8B / 255.0, blue: 0xFA / 255.0) // #A78BFA
    static let inlineCodeInk = Color(red: 0xDC / 255.0, green: 0xE6 / 255.0, blue: 0xFF / 255.0)
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
                    AntigravityMarkdownView(markdown: promptText, variant: .userBubble)
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

/// Collapsible `👁 Thought for 14s ›` reasoning row (`row-thought-14s`) with live streaming timer & reasoning preview.
public struct CollapsibleThoughtRowView: View {
    public let durationSeconds: Int
    public let reasoningSummary: String
    public let isStreaming: Bool
    public let startedAt: Date?
    @State private var isExpanded: Bool = false
    @State private var userCollapsedDuringStream: Bool = false

    public init(
        durationSeconds: Int = 14,
        reasoningSummary: String = "Inspected internal/middleware router chain, verified token-bucket concurrency lock contention, and prepared vegeta load profile.",
        isStreaming: Bool = false,
        startedAt: Date? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.reasoningSummary = reasoningSummary
        self.isStreaming = isStreaming
        self.startedAt = startedAt
    }

    private var effectiveExpanded: Bool {
        if isStreaming {
            return !userCollapsedDuringStream
        }
        return isExpanded
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if isStreaming {
                        userCollapsedDuringStream.toggle()
                    } else {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isStreaming {
                        AntigravityRunningArcIndicatorView(isAnimated: true)
                        TimelineView(.periodic(from: .now, by: 1.0)) { context in
                            let elapsed = Int(max(Double(durationSeconds), context.date.timeIntervalSince(startedAt ?? context.date)))
                            Text("Thinking · \(max(1, elapsed))s…")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(StepCardPalette.periwinkle)
                        }
                    } else {
                        Image(systemName: "eye")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                        Text("Thought for \(durationSeconds)s")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                    }
                    Image(systemName: effectiveExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isStreaming ? StepCardPalette.periwinkle : AntigravityTheme.inkSecondary)
                    Spacer()
                }
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("row-thought-14s")

            if effectiveExpanded {
                let trimmed = reasoningSummary.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    AntigravityMarkdownView(markdown: reasoningSummary, variant: .thought)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(StepCardPalette.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if isStreaming {
                    Text("Analyzing workspace context and planning next steps…")
                        .font(.system(size: 13.5))
                        .foregroundStyle(AntigravityTheme.inkSecondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(StepCardPalette.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
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

    private var isActivelyRunning: Bool {
        (!store.isVerificationMode || store.isLiveBackendConnected)
            && steps.contains(where: { $0.status == .inProgress || $0.status == .pending })
    }

    private var summaryTitle: String {
        let editCount = steps.filter { $0.codeAction != nil }.count
        if isActivelyRunning {
            if editCount == steps.count && editCount > 0 {
                return "Editing \(editCount) workspace file\(editCount == 1 ? "" : "s")…"
            } else if editCount > 0 {
                return "Inspecting & editing \(steps.count) workspace items…"
            } else {
                return "Inspecting \(steps.count) workspace file\(steps.count == 1 ? "" : "s")…"
            }
        }
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
                    if isActivelyRunning {
                        AntigravityRunningArcIndicatorView(isAnimated: true)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(StepCardPalette.periwinkle)
                    }
                    Text(summaryTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isActivelyRunning ? StepCardPalette.periwinkle : AntigravityTheme.inkReading)
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

    private var shouldAnimateLive: Bool {
        !store.isVerificationMode || store.isLiveBackendConnected
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
            let stepIsActive = (step.status == .inProgress || step.status == .pending)
            let thinking = step.plannerResponse?.thinking ?? ""
            let prose = step.plannerResponse?.response ?? ""
            let isStreamingThought = stepIsActive
                && prose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && shouldAnimateLive

            VStack(alignment: .leading, spacing: 8) {
                if !thinking.isEmpty || isStreamingThought {
                    CollapsibleThoughtRowView(
                        durationSeconds: max(1, Int(step.plannerResponse?.thinkingDurationSeconds ?? 1)),
                        reasoningSummary: thinking,
                        isStreaming: isStreamingThought,
                        startedAt: step.createdAt
                    )
                }
                if !prose.isEmpty {
                    AntigravityMarkdownView(markdown: prose, variant: .assistant)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("step-prose-\(step.stepIndex)")

                    if stepIsActive && shouldAnimateLive {
                        HStack(spacing: 7) {
                            AntigravityFourDotLoadingView(
                                isAnimated: true,
                                dotSize: 4.0,
                                spacing: 3.0,
                                tint: StepCardPalette.periwinkle
                            )
                            Text("Generating…")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(StepCardPalette.periwinkle)
                        }
                        .padding(.top, 2)
                    }
                }
                if !store.isVerificationMode,
                   let refs = step.plannerResponse?.referencedFiles,
                   !refs.isEmpty {
                    ReferencedFilePillsRow(paths: refs) { tappedPath in
                        if tappedPath.lowercased().contains("plan") {
                            store.currentRoute = .planReview
                        } else {
                            MarkdownClipboardHelper.copyText(MarkdownLinkFormatting.cleanDisplayPath(tappedPath))
                        }
                    }
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
                            } else if (step.status == .inProgress || step.status == .pending) && shouldAnimateLive {
                                HStack(spacing: 5) {
                                    AntigravityRunningArcIndicatorView(isAnimated: true)
                                        .scaleEffect(0.82)
                                    Text("running")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(StepCardPalette.periwinkle)
                                }
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
                AntigravityMarkdownView(markdown: prose, variant: .assistant)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("step-prose-\(step.stepIndex)")
            }
        }
    }
}

// MARK: - Referenced Artifact / File Pills

private struct ReferencedFilePillsRow: View {
    let paths: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(paths, id: \.self) { rawPath in
                    Button {
                        onTap(rawPath)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: rawPath.lowercased().hasSuffix(".md") ? "doc.richtext" : "doc.text")
                                .font(.system(size: 11, weight: .semibold))
                            Text(MarkdownLinkFormatting.shortFileBadge(rawPath))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                        }
                        .foregroundStyle(StepCardPalette.periwinkle)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(StepCardPalette.periwinkle.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(StepCardPalette.periwinkle.opacity(0.26), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Native Matte Obsidian GitHub-Flavored Markdown Renderer (`AntigravityMarkdownView`)

public enum MarkdownRenderVariant: Sendable, Equatable {
    case assistant
    case userBubble
    case thought
    case blockquote

    var baseFontSize: CGFloat {
        switch self {
        case .assistant: return 15.5
        case .userBubble: return 15.0
        case .thought: return 13.0
        case .blockquote: return 14.5
        }
    }

    var textColor: Color {
        switch self {
        case .assistant, .userBubble:
            return AntigravityTheme.inkReading
        case .thought:
            return AntigravityTheme.inkSecondary
        case .blockquote:
            return AntigravityTheme.inkLabel
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .assistant: return 3.5
        case .userBubble: return 2.5
        case .thought: return 2.5
        case .blockquote: return 3.0
        }
    }

    var blockSpacing: CGFloat {
        switch self {
        case .assistant: return 8.0
        case .userBubble: return 6.0
        case .thought: return 6.0
        case .blockquote: return 6.0
        }
    }
}

public struct AntigravityMarkdownView: View {
    public let markdown: String
    public let variant: MarkdownRenderVariant

    @State private var copiedRefLabel: String? = nil
    @State private var copyGeneration: Int = 0

    public init(markdown: String, variant: MarkdownRenderVariant = .assistant) {
        self.markdown = markdown
        self.variant = variant
    }

    public var body: some View {
        let blocks = AntigravityMarkdownParser.parse(markdown)
        VStack(alignment: .leading, spacing: 6) {
            if blocks.isEmpty {
                Text(markdown)
                    .font(.system(size: variant.baseFontSize))
                    .foregroundStyle(variant.textColor)
                    .lineSpacing(variant.lineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } else {
                AntigravityMarkdownBlocksView(blocks: blocks, variant: variant)
            }

            if let copiedRefLabel {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(StepCardPalette.emeraldDone)
                    Text("Copied \(copiedRefLabel)")
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AntigravityTheme.inkLabel)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AntigravityTheme.surfaceElevated)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .clipShape(Capsule())
                .transition(.opacity)
            }
        }
        .tint(StepCardPalette.periwinkle)
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "antigravity-ref" {
                let targetRef = MarkdownLinkFormatting.extractCopiedReference(from: url)
                let shortBadge = MarkdownLinkFormatting.shortFileBadge(targetRef)
                Task { @MainActor in
                    MarkdownClipboardHelper.copyText(targetRef)
                    copyGeneration += 1
                    let currentGen = copyGeneration
                    withAnimation(.easeInOut(duration: 0.16)) {
                        copiedRefLabel = shortBadge
                    }
                    try? await Task.sleep(for: .seconds(1.8))
                    if copyGeneration == currentGen {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            copiedRefLabel = nil
                        }
                    }
                }
                return .handled
            }
            return .systemAction
        })
    }
}

private struct AntigravityMarkdownBlocksView: View {
    let blocks: [MarkdownBlock]
    let variant: MarkdownRenderVariant

    var body: some View {
        VStack(alignment: .leading, spacing: variant.blockSpacing) {
            ForEach(blocks) { block in
                blockView(for: block)
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(_, let level, let inlines):
            let size = headingFontSize(for: level)
            let weight: Font.Weight = level <= 2 ? .bold : .semibold
            let color = level <= 4 ? AntigravityTheme.inkReading : AntigravityTheme.inkLabel
            Text(
                MarkdownInlineBuilder.build(
                    inlines,
                    baseSize: size,
                    baseWeight: weight,
                    defaultColor: color
                )
            )
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .padding(.top, level <= 2 ? 4 : 2)

        case .paragraph(_, let inlines):
            Text(
                MarkdownInlineBuilder.build(
                    inlines,
                    baseSize: variant.baseFontSize,
                    baseWeight: .regular,
                    defaultColor: variant.textColor
                )
            )
            .lineSpacing(variant.lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)

        case .listItem(_, let indentLevel, let marker, let inlines):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                listMarkerView(marker: marker, indentLevel: indentLevel)
                Text(
                    MarkdownInlineBuilder.build(
                        inlines,
                        baseSize: variant.baseFontSize,
                        baseWeight: .regular,
                        defaultColor: isCompletedTask(marker) ? AntigravityTheme.inkSecondary : variant.textColor
                    )
                )
                .lineSpacing(variant.lineSpacing - 0.5)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            }
            .padding(.leading, CGFloat(indentLevel) * 16)

        case .codeBlock(_, let language, let code):
            MarkdownCodeBlockCardView(language: language, code: code)

        case .blockquote(_, let alert, let innerBlocks):
            MarkdownBlockquoteCardView(alert: alert, innerBlocks: innerBlocks)

        case .table(_, let headers, let alignments, let rows):
            MarkdownTableCardView(headers: headers, alignments: alignments, rows: rows)

        case .thematicBreak:
            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(height: 1)
                .padding(.vertical, 4)

        case .mathBlock(_, let latex):
            MarkdownMathBlockCardView(latex: latex)
        }
    }

    private func headingFontSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return variant == .thought ? 15.5 : 19.5
        case 2: return variant == .thought ? 14.5 : 17.5
        case 3: return variant == .thought ? 14.0 : 16.0
        case 4: return variant == .thought ? 13.5 : 15.2
        default: return variant == .thought ? 13.0 : 14.5
        }
    }

    private func isCompletedTask(_ marker: MarkdownListMarker) -> Bool {
        if case .task(let checked) = marker {
            return checked
        }
        return false
    }

    @ViewBuilder
    private func listMarkerView(marker: MarkdownListMarker, indentLevel: Int) -> some View {
        switch marker {
        case .bullet:
            let symbol = indentLevel == 0 ? "•" : (indentLevel == 1 ? "◦" : "▪")
            Text(symbol)
                .font(.system(size: variant.baseFontSize, weight: .bold))
                .foregroundStyle(indentLevel == 0 ? StepCardPalette.periwinkle : AntigravityTheme.inkSecondary)
                .frame(minWidth: 12, alignment: .center)

        case .ordered(let number):
            Text("\(number).")
                .font(.system(size: max(12.5, variant.baseFontSize - 1.0), weight: .semibold, design: .monospaced))
                .foregroundStyle(StepCardPalette.periwinkle)
                .frame(minWidth: 20, alignment: .trailing)

        case .task(let checked):
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(.system(size: max(13.0, variant.baseFontSize - 1.5), weight: .medium))
                .foregroundStyle(checked ? StepCardPalette.emeraldDone : AntigravityTheme.inkSecondary)
                .frame(minWidth: 16, alignment: .center)
        }
    }
}

// MARK: - Fenced Code Block Card (Horizontal Scroll + Copy + Diff Coloring)

private struct MarkdownCodeBlockCardView: View {
    let language: String?
    let code: String
    @State private var didCopy: Bool = false

    private var normalizedLanguage: String {
        let trimmed = (language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "code" : trimmed.lowercased()
    }

    private var isDiffBlock: Bool {
        normalizedLanguage == "diff" || normalizedLanguage == "patch"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(normalizedLanguage)
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(AntigravityTheme.inkSecondary)

                Spacer()

                Button {
                    MarkdownClipboardHelper.copyText(code)
                    withAnimation(.easeInOut(duration: 0.15)) {
                        didCopy = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.easeInOut(duration: 0.15)) {
                            didCopy = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(didCopy ? "Copied" : "Copy")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(didCopy ? StepCardPalette.emeraldDone : StepCardPalette.periwinkle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.03))

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                if isDiffBlock {
                    diffColoredCodeBody
                        .padding(12)
                } else {
                    Text(code.isEmpty ? " " : code)
                        .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .lineSpacing(2.5)
                        .textSelection(.enabled)
                        .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StepCardPalette.codeBlockBg)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var diffColoredCodeBody: some View {
        let lines = code.components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(diffLineColor(line))
                    .textSelection(.enabled)
            }
        }
    }

    private func diffLineColor(_ line: String) -> Color {
        if line.hasPrefix("+++") || line.hasPrefix("---") {
            return AntigravityTheme.inkSecondary
        } else if line.hasPrefix("+") {
            return StepCardPalette.emeraldDone
        } else if line.hasPrefix("-") {
            return StepCardPalette.coralError
        } else if line.hasPrefix("@@") {
            return StepCardPalette.periwinkle
        }
        return AntigravityTheme.inkReading
    }
}

// MARK: - Blockquote & GitHub Alert Callout Card (`[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`)

private struct MarkdownBlockquoteCardView: View {
    let alert: MarkdownAlertKind?
    let innerBlocks: [MarkdownBlock]

    var body: some View {
        if let alert {
            let accent = alertAccent(for: alert)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: alert.sfSymbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(alert.displayTitle)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(accent)
                }

                if !innerBlocks.isEmpty {
                    AnyView(AntigravityMarkdownBlocksView(blocks: innerBlocks, variant: .blockquote))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.08))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 3)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.24), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(StepCardPalette.periwinkle.opacity(0.55))
                    .frame(width: 3)

                AnyView(AntigravityMarkdownBlocksView(blocks: innerBlocks, variant: .blockquote))
                    .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func alertAccent(for kind: MarkdownAlertKind) -> Color {
        switch kind {
        case .note: return StepCardPalette.periwinkle
        case .tip: return StepCardPalette.emeraldDone
        case .important: return StepCardPalette.softViolet
        case .warning: return StepCardPalette.warmAmber
        case .caution: return StepCardPalette.coralError
        }
    }
}

// MARK: - GFM Pipe Table Card (Horizontal Scroll + Column Alignment)

private struct MarkdownTableCardView: View {
    let headers: [[MarkdownInline]]
    let alignments: [MarkdownTableAlignment]
    let rows: [[[MarkdownInline]]]

    private var columnCount: Int {
        headers.count
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { colIdx in
                        Text(
                            MarkdownInlineBuilder.build(
                                headers[colIdx],
                                baseSize: 13.0,
                                baseWeight: .semibold,
                                defaultColor: AntigravityTheme.inkReading
                            )
                        )
                        .multilineTextAlignment(textAlignment(for: colIdx))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .gridColumnAlignment(horizontalAlignment(for: colIdx))
                    }
                }
                .background(Color.white.opacity(0.05))

                Rectangle()
                    .fill(Color.white.opacity(0.09))
                    .frame(height: 1)

                ForEach(0..<rows.count, id: \.self) { rowIdx in
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { colIdx in
                            let cellInlines: [MarkdownInline] = colIdx < rows[rowIdx].count ? rows[rowIdx][colIdx] : []
                            Text(
                                MarkdownInlineBuilder.build(
                                    cellInlines,
                                    baseSize: 13.0,
                                    baseWeight: .regular,
                                    defaultColor: AntigravityTheme.inkLabel
                                )
                            )
                            .multilineTextAlignment(textAlignment(for: colIdx))
                            .textSelection(.enabled)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        }
                    }
                    .background(rowIdx.isMultiple(of: 2) ? Color.clear : Color.white.opacity(0.02))

                    if rowIdx + 1 < rows.count {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StepCardPalette.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func horizontalAlignment(for colIdx: Int) -> HorizontalAlignment {
        guard colIdx < alignments.count else { return .leading }
        switch alignments[colIdx] {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private func textAlignment(for colIdx: Int) -> TextAlignment {
        guard colIdx < alignments.count else { return .leading }
        switch alignments[colIdx] {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

// MARK: - Display Math Block Card (`$$ ... $$`)

private struct MarkdownMathBlockCardView: View {
    let latex: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(MarkdownMathNormalizer.prettify(latex))
                .font(.system(size: 13.5, weight: .regular, design: .serif).italic())
                .foregroundStyle(StepCardPalette.inlineCodeInk)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StepCardPalette.codeBlockBg)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Rich Inline `AttributedString` Builder

private enum MarkdownInlineBuilder {
    struct StyleState {
        var isBold: Bool = false
        var isItalic: Bool = false
        var isStrikethrough: Bool = false
        var isCode: Bool = false
        var isMath: Bool = false
        var baseWeight: Font.Weight = .regular
        var linkDestination: String? = nil

        func resolvedFont(baseSize: CGFloat) -> Font {
            if isCode {
                let codeSize = max(11.5, baseSize - 1.5)
                let codeWeight: Font.Weight = isBold ? .semibold : .medium
                return Font.system(size: codeSize, weight: codeWeight, design: .monospaced)
            }
            if isMath {
                let mathFont = Font.system(size: max(12.5, baseSize - 0.5), weight: isBold ? .semibold : .regular, design: .serif)
                return mathFont.italic()
            }
            let weight: Font.Weight = isBold ? .bold : baseWeight
            let font = Font.system(size: baseSize, weight: weight, design: .default)
            return isItalic ? font.italic() : font
        }

        func resolvedForeground(defaultColor: Color) -> Color {
            if linkDestination != nil {
                return StepCardPalette.periwinkle
            }
            if isCode || isMath {
                return StepCardPalette.inlineCodeInk
            }
            return defaultColor
        }

        var resolvedBackground: Color? {
            if isCode {
                if linkDestination != nil {
                    return StepCardPalette.periwinkle.opacity(0.14)
                }
                return Color.white.opacity(0.09)
            }
            return nil
        }

        var resolvedLinkURL: URL? {
            guard let dest = linkDestination else { return nil }
            return MarkdownLinkFormatting.resolvedActionURL(for: dest)
        }
    }

    static func build(
        _ nodes: [MarkdownInline],
        baseSize: CGFloat,
        baseWeight: Font.Weight,
        defaultColor: Color
    ) -> AttributedString {
        var output = AttributedString()
        let initial = StyleState(baseWeight: baseWeight)
        appendNodes(nodes, style: initial, baseSize: baseSize, defaultColor: defaultColor, into: &output)
        return output
    }

    private static func appendNodes(
        _ nodes: [MarkdownInline],
        style: StyleState,
        baseSize: CGFloat,
        defaultColor: Color,
        into output: inout AttributedString
    ) {
        for node in nodes {
            switch node {
            case .text(let s):
                output.append(makeSegment(s, style: style, baseSize: baseSize, defaultColor: defaultColor))

            case .softBreak:
                output.append(makeSegment("\n", style: style, baseSize: baseSize, defaultColor: defaultColor))

            case .code(let codeText):
                var codeStyle = style
                codeStyle.isCode = true
                let padded = "\u{200A}\(codeText)\u{200A}"
                output.append(makeSegment(padded, style: codeStyle, baseSize: baseSize, defaultColor: defaultColor))

            case .strong(let children):
                var boldStyle = style
                boldStyle.isBold = true
                appendNodes(children, style: boldStyle, baseSize: baseSize, defaultColor: defaultColor, into: &output)

            case .emphasis(let children):
                var italicStyle = style
                italicStyle.isItalic = true
                appendNodes(children, style: italicStyle, baseSize: baseSize, defaultColor: defaultColor, into: &output)

            case .strikethrough(let children):
                var strikeStyle = style
                strikeStyle.isStrikethrough = true
                appendNodes(children, style: strikeStyle, baseSize: baseSize, defaultColor: defaultColor, into: &output)

            case .link(let labelNodes, let destination):
                var linkStyle = style
                linkStyle.linkDestination = destination
                appendNodes(labelNodes, style: linkStyle, baseSize: baseSize, defaultColor: defaultColor, into: &output)

            case .inlineMath(let latex):
                var mathStyle = style
                mathStyle.isMath = true
                let rendered = MarkdownMathNormalizer.prettify(latex)
                output.append(makeSegment(rendered, style: mathStyle, baseSize: baseSize, defaultColor: defaultColor))
            }
        }
    }

    private static func makeSegment(
        _ string: String,
        style: StyleState,
        baseSize: CGFloat,
        defaultColor: Color
    ) -> AttributedString {
        var seg = AttributedString(string)
        seg.swiftUI.font = style.resolvedFont(baseSize: baseSize)
        seg.swiftUI.foregroundColor = style.resolvedForeground(defaultColor: defaultColor)
        if let bg = style.resolvedBackground {
            seg.swiftUI.backgroundColor = bg
        }
        if style.isStrikethrough {
            seg.swiftUI.strikethroughStyle = Text.LineStyle.single
        }
        if let url = style.resolvedLinkURL {
            seg.link = url
        }
        return seg
    }
}

// MARK: - Link & Clipboard Helpers

private enum MarkdownLinkFormatting {
    static func resolvedActionURL(for rawDestination: String) -> URL? {
        let trimmed = rawDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("https://") || lower.hasPrefix("http://") || lower.hasPrefix("mailto:") || lower.hasPrefix("antigravity://") {
            if let direct = URL(string: trimmed) {
                return direct
            }
        }
        // Encode `file://`, `conversation://`, or relative workspace references into a copyable action URL
        var comps = URLComponents()
        comps.scheme = "antigravity-ref"
        comps.host = "copy"
        comps.queryItems = [URLQueryItem(name: "ref", value: cleanDisplayPath(trimmed))]
        return comps.url
    }

    static func extractCopiedReference(from url: URL) -> String {
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let ref = comps.queryItems?.first(where: { $0.name == "ref" })?.value,
           !ref.isEmpty {
            return ref
        }
        return url.absoluteString
    }

    static func cleanDisplayPath(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("file://") {
            s = String(s.dropFirst("file://".count))
        }
        if let decoded = s.removingPercentEncoding {
            s = decoded
        }
        return s
    }

    static func shortFileBadge(_ raw: String) -> String {
        let cleaned = cleanDisplayPath(raw)
        let parts = cleaned.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let pathPart = String(parts[0])
        let fragmentSuffix: String
        if parts.count > 1 && !parts[1].isEmpty {
            fragmentSuffix = "#\(parts[1])"
        } else {
            fragmentSuffix = ""
        }
        let base = (pathPart as NSString).lastPathComponent
        let chosen = base.isEmpty ? pathPart : base
        return chosen + fragmentSuffix
    }
}

private enum MarkdownClipboardHelper {
    @MainActor
    static func copyText(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

private enum MarkdownMathNormalizer {
    private static let replacements: [(String, String)] = [
        ("\\times", "×"),
        ("\\cdot", "·"),
        ("\\div", "÷"),
        ("\\pm", "±"),
        ("\\leq", "≤"),
        ("\\le", "≤"),
        ("\\geq", "≥"),
        ("\\ge", "≥"),
        ("\\neq", "≠"),
        ("\\ne", "≠"),
        ("\\approx", "≈"),
        ("\\rightarrow", "→"),
        ("\\to", "→"),
        ("\\leftarrow", "←"),
        ("\\Rightarrow", "⇒"),
        ("\\infty", "∞"),
        ("\\sum", "∑"),
        ("\\prod", "∏"),
        ("\\sqrt", "√"),
        ("\\alpha", "α"),
        ("\\beta", "β"),
        ("\\gamma", "γ"),
        ("\\delta", "δ"),
        ("\\lambda", "λ"),
        ("\\pi", "π"),
        ("\\sigma", "σ"),
        ("\\omega", "ω"),
    ]

    static func prettify(_ raw: String) -> String {
        var out = raw
        for (token, symbol) in replacements {
            out = out.replacingOccurrences(of: token, with: symbol)
        }
        return out
    }
}

