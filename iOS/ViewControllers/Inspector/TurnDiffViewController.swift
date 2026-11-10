import SwiftUI
import AntigravityData

/// State `S07_TURN_DIFF_INSPECTOR`: Renders word-level Unified/Split Turn Diffs
/// from `GetTurnDiff` and `GetPatchAndCodeChange`, supporting multi-file switching,
/// inline line-level review annotations (`DiffLineComment`), and Accept / Revert Patch actions.
public struct TurnDiffViewController: View {
    @Bindable public var store: AntigravitySessionStore
    @State private var commentingLineNumber: Int? = nil
    @State private var draftCommentText: String = ""

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    private var activePatch: FilePatchDiff? {
        store.activeTurnDiffs.first(where: { $0.filePath.hasSuffix(store.selectedDiffFilePath) || $0.filePath == store.selectedDiffFilePath })
            ?? store.activeTurnDiffs.first
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Top Navigation & File Switcher Tabs
            HStack(spacing: 10) {
                Button {
                    store.currentRoute = .cascadeChat
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Chat")
                    }
                    .font(AntigravityTheme.TypographyTier.chrome.font)
                    .foregroundStyle(AntigravityTheme.inkLabel)
                    .padding(.horizontal, 12)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(AntigravityTheme.surfaceCard)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.activeTurnDiffs) { patch in
                            let fileName = (patch.filePath as NSString).lastPathComponent
                            let isSelected = patch.filePath == activePatch?.filePath
                            Button {
                                store.selectedDiffFilePath = patch.filePath
                            } label: {
                                HStack(spacing: 6) {
                                    Text(fileName)
                                        .font(AntigravityTheme.TypographyTier.evidence.font)
                                        .foregroundStyle(isSelected ? AntigravityTheme.inkReading : AntigravityTheme.inkLabel)
                                    Text("+\(patch.additions) -\(patch.deletions)")
                                        .font(AntigravityTheme.TypographyTier.metadata.font)
                                        .foregroundStyle(AntigravityTheme.statusDone)
                                }
                                .padding(.horizontal, 12)
                                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                                .background(isSelected ? AntigravityTheme.surfaceElevated : AntigravityTheme.surfaceCard)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .accessibilityIdentifier("diff-file-tabs")

            // 2. Unified Diff Code Surface with Tap-to-Comment on Any Line
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if let patch = activePatch {
                        ForEach(patch.lines) { line in
                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    let targetLine = line.newLineNumber ?? line.oldLineNumber ?? line.id
                                    commentingLineNumber = (commentingLineNumber == targetLine) ? nil : targetLine
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(lineNumberLabel(for: line))
                                            .font(AntigravityTheme.TypographyTier.metadata.font)
                                            .foregroundStyle(AntigravityTheme.inkSecondary)
                                            .frame(width: 44, alignment: .trailing)

                                        Text(line.text)
                                            .font(AntigravityTheme.TypographyTier.metadata.font)
                                            .foregroundStyle(lineForeground(for: line.kind))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 8)
                                    .background(lineBackground(for: line.kind))
                                }
                                .buttonStyle(.plain)

                                // Existing comments on this line
                                let lineNum = line.newLineNumber ?? line.oldLineNumber ?? line.id
                                ForEach(store.diffComments.filter { $0.filePath == patch.filePath && $0.lineNumber == lineNum }) { comment in
                                    HStack(spacing: 8) {
                                        Image(systemName: "text.bubble.fill")
                                            .foregroundStyle(AntigravityTheme.accentSecondary)
                                        Text("\(comment.author): \(comment.commentText)")
                                            .font(AntigravityTheme.TypographyTier.process.font)
                                            .foregroundStyle(AntigravityTheme.inkReading)
                                    }
                                    .padding(8)
                                    .background(AntigravityTheme.surfaceCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .padding(.leading, 48)
                                }

                                // Inline Comment Composer
                                if commentingLineNumber == lineNum {
                                    HStack(spacing: 8) {
                                        TextField("Add inline review note on L\(lineNum)...", text: $draftCommentText)
                                            .font(AntigravityTheme.TypographyTier.process.font)
                                            .foregroundStyle(AntigravityTheme.inkReading)
                                            .padding(.horizontal, 10)
                                            .frame(minHeight: 38)
                                            .background(AntigravityTheme.surfaceObsidian)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                        Button {
                                            store.addDiffComment(
                                                filePath: patch.filePath,
                                                lineNumber: lineNum,
                                                text: draftCommentText
                                            )
                                            draftCommentText = ""
                                            commentingLineNumber = nil
                                        } label: {
                                            Text("Add")
                                                .font(AntigravityTheme.TypographyTier.chrome.font)
                                                .foregroundStyle(AntigravityTheme.inkReading)
                                                .padding(.horizontal, 12)
                                                .frame(minHeight: 38)
                                                .background(AntigravityTheme.accentPrimary)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.leading, 48)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(AntigravityTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("diff-code-surface")
            }

            // 3. Bottom Action Bar (Accept Patch / Revert Hunk)
            HStack(spacing: 12) {
                Button {
                    if let path = activePatch?.filePath {
                        store.acceptPatchFile(path)
                    }
                } label: {
                    Text("Accept Patch")
                        .font(AntigravityTheme.TypographyTier.evidence.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
                .background(AntigravityTheme.statusDone)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-accept-patch")

                Button {
                    if let path = activePatch?.filePath {
                        store.composerDraftText = "Please revert the changes in `\((path as NSString).lastPathComponent)`."
                        store.sendCurrentDraft()
                        store.currentRoute = .cascadeChat
                    }
                } label: {
                    Text("Revert Hunk")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                        .foregroundStyle(AntigravityTheme.statusError)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-revert-patch")
            }
        }
        .padding(16)
        .background(AntigravityTheme.canvasObsidian)
    }

    private func lineNumberLabel(for line: DiffLine) -> String {
        if line.kind == .hunkHeader { return "@@" }
        let oldStr = line.oldLineNumber.map(String.init) ?? ""
        let newStr = line.newLineNumber.map(String.init) ?? ""
        return "\(oldStr) \(newStr)"
    }

    private func lineForeground(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .addition: return AntigravityTheme.statusDone
        case .deletion: return AntigravityTheme.statusError
        case .hunkHeader: return AntigravityTheme.accentSecondary
        case .context: return AntigravityTheme.inkLabel
        }
    }

    private func lineBackground(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .addition: return AntigravityTheme.statusDone.opacity(0.12)
        case .deletion: return AntigravityTheme.statusError.opacity(0.12)
        case .hunkHeader: return AntigravityTheme.surfaceCard
        case .context: return Color.clear
        }
    }
}
