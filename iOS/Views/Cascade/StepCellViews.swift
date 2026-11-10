import SwiftUI
import AntigravityData

/// Renders individual `CascadeStep` items into native iOS cards following the 5-tier
/// typography hierarchy (Reading, Evidence, Process, Metadata, Chrome).
public struct CascadeStepCellView: View {
    public let step: CascadeStep

    public init(step: CascadeStep) {
        self.step = step
    }

    public var body: some View {
        switch step.type {
        case .userInput:
            Text(step.userInput ?? "")
                .font(AntigravityTheme.TypographyTier.reading.font)
                .foregroundStyle(AntigravityTheme.inkReading)
                .padding(14)
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        case .plannerResponse:
            VStack(alignment: .leading, spacing: 10) {
                if let thinking = step.plannerResponse?.thinking {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AntigravityTheme.accentSecondary)
                        Text("Thought for \(String(format: "%.1fs", step.plannerResponse?.thinkingDurationSeconds ?? 3.4)) · \(thinking)")
                            .font(AntigravityTheme.TypographyTier.process.font)
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(AntigravityTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("step-thinking-capsule")
                }

                Text(step.plannerResponse?.response ?? "")
                    .font(AntigravityTheme.TypographyTier.reading.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
            }

        case .codeAction:
            if let ca = step.codeAction {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(URL(string: ca.targetFileUri)?.lastPathComponent ?? ca.targetFileUri)
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
                .accessibilityIdentifier("step-file-evidence-group")
            }

        case .runCommand:
            if let cmd = step.runCommand {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("$ \(cmd.commandLine)")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.inkLabel)
                        Spacer()
                        Text(step.status == .waiting ? "WAITING" : "EXIT 0")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(
                                step.status == .waiting
                                    ? AntigravityTheme.statusWaiting
                                    : AntigravityTheme.statusDone
                            )
                    }
                    if let output = cmd.outputPreview {
                        Text(output)
                            .font(AntigravityTheme.TypographyTier.process.font)
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                    }
                }
                .padding(12)
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("step-terminal-card")
            }

        default:
            EmptyView()
        }
    }
}
