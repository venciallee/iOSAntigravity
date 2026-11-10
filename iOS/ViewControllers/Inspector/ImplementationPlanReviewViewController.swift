import SwiftUI
import AntigravityData

/// State `UE11_PLAN_REVIEW`: Implementation Plan Review & Inline Selection Commenting (`iOS · Implementation Plan 审阅`).
/// Features:
/// - Header `Implementation Plan` (`Fix flaky TestSettlementBatch · v2`) + `[💬 2]` badge (`plan-comments-badge`)
/// - Amber paused banner (`plan-paused-banner`: `Agent is paused until you review. Long-press any text to comment.`)
/// - H1 `Isolate the fake clock in settlement tests`
/// - `Proposed changes` with `MODIFY` (`settlement/batch.go` + amber highlight + `WL You Pending` comment card `plan-pending-comment-card`),
///   floating white `[💬 Comment | Copy]` callout (`selection-callout-comment`),
///   `MODIFY` (`settlement/settlement_test.go` + blue selection highlight),
///   `NEW` (`testutil/clock.go`), and `Verification`
/// - Sticky bottom `Proceed` (`btn-plan-proceed`) + Periwinkle `Send 2 comments` (`btn-plan-send-comments`) buttons.
public struct ImplementationPlanReviewViewController: View {
    @Bindable public var store: AntigravitySessionStore

    @State private var commentCount: Int = 2
    @State private var isAddingSelectionComment: Bool = false
    @State private var newSelectionCommentDraft: String = ""

    private static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    private static let warmAmber = Color(red: 0xEB / 255.0, green: 0xB3 / 255.0, blue: 0x65 / 255.0) // #EBB365
    private static let emeraldDone = Color(red: 0x57 / 255.0, green: 0xC8 / 255.0, blue: 0x8A / 255.0) // #57C88A
    private static let inkOnCTA = Color(red: 0x0A / 255.0, green: 0x0E / 255.0, blue: 0x17 / 255.0) // #0A0E17
    private static let cardSurface = Color(red: 0x16 / 255.0, green: 0x17 / 255.0, blue: 0x1D / 255.0)
    private static let amberBannerBg = Color(red: 0x22 / 255.0, green: 0x1B / 255.0, blue: 0x0F / 255.0)
    private static let pillBg = Color(red: 0x1B / 255.0, green: 0x1D / 255.0, blue: 0x24 / 255.0)

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            topHeaderBar

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Amber Paused Banner
                    pausedReviewBanner

                    // 2. H1 Plan Title & Problem Statement
                    Text("Isolate the fake clock in settlement tests")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .fixedSize(horizontal: false, vertical: true)

                    problemSummaryParagraph

                    // 3. Proposed Changes Section
                    Text("Proposed changes")
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .padding(.top, 2)

                    // Change 1: MODIFY settlement/batch.go + Amber Highlight + WL You Pending Card
                    batchChangeWithPendingComment

                    // Floating White `[💬 Comment | Copy]` Selection Callout + Change 2
                    selectionCalloutAndSettlementTestChange

                    if isAddingSelectionComment {
                        inlineSelectionCommentEditor
                    }

                    // Change 3: NEW testutil/clock.go
                    newClockHelperChange

                    // 4. Verification Section
                    Text("Verification")
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            // 5. Sticky Bottom Bar (`Proceed` + `Send 2 comments`)
            bottomDecisionBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .background(AntigravityTheme.canvasObsidian)
    }

    // MARK: - 1. Top Header Bar

    private var topHeaderBar: some View {
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
            .accessibilityIdentifier("btn-back-from-plan")

            VStack(alignment: .leading, spacing: 2) {
                Text("Implementation Plan")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .lineLimit(1)
                Text("Fix flaky TestSettlementBatch · v2")
                    .font(.system(size: 12))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // `[💬 2]` Comments Badge
            Button {
                isAddingSelectionComment.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(commentCount)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AntigravityTheme.inkReading)
                .padding(.horizontal, 12)
                .frame(minWidth: 52, minHeight: AntigravityTheme.minTouchTargetPt)
                .background(Self.pillBg)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plan-comments-badge")

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

    // MARK: - 2. Amber Paused Banner

    private var pausedReviewBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Self.warmAmber)
                .frame(width: 8, height: 8)

            Text("Agent is paused until you review. Long-press any text to comment.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Self.warmAmber)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Self.amberBannerBg)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Self.warmAmber.opacity(0.26), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("plan-paused-banner")
    }

    // MARK: - 3. Plan Content Blocks

    private var problemSummaryParagraph: some View {
        Text("TestSettlementBatch fails in ~3% of CI runs. Parallel subtests share one fake clock, so `Advance()` in one subtest moves time for the others.")
            .font(.system(size: 14.5))
            .foregroundStyle(AntigravityTheme.inkLabel)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var batchChangeWithPendingComment: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                changeKindBadge(label: "MODIFY", tint: Self.warmAmber)
                Text("settlement/batch.go")
                    .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(AntigravityTheme.inkReading)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Accept a `clock.Clock` through BatchOptions")
                    .font(.system(size: 14.5))
                    .foregroundStyle(AntigravityTheme.inkLabel)

                HStack(spacing: 0) {
                    Text("instead of calling time.Now() directly")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Self.warmAmber.opacity(0.22))
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Self.warmAmber)
                                .frame(height: 1.5)
                        }
                    Text(".")
                        .font(.system(size: 14.5))
                        .foregroundStyle(AntigravityTheme.inkLabel)
                }
            }

            // `WL You Pending` Comment Card (`plan-pending-comment-card`)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 24, height: 24)
                        Text("WL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AntigravityTheme.inkReading)
                    }

                    Text("You")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(AntigravityTheme.inkReading)

                    Text("Pending")
                        .font(.system(size: 13))
                        .foregroundStyle(AntigravityTheme.inkSecondary)

                    Spacer()
                }

                Text("Default to the real clock when Clock is nil, so existing callers don't break.")
                    .font(.system(size: 14))
                    .foregroundStyle(AntigravityTheme.inkLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Self.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.leading, 8)
            .accessibilityIdentifier("plan-pending-comment-card")
        }
    }

    private var selectionCalloutAndSettlementTestChange: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Floating White `[💬 Comment | Copy]` Callout Pill
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    Button {
                        isAddingSelectionComment = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Comment")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Self.inkOnCTA)
                        .padding(.horizontal, 14)
                        .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("selection-callout-comment")

                    Rectangle()
                        .fill(Color.black.opacity(0.14))
                        .frame(width: 1, height: 22)

                    Button {
                        isAddingSelectionComment = false
                    } label: {
                        Text("Copy")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Self.inkOnCTA)
                            .padding(.horizontal, 14)
                            .frame(minWidth: 60, minHeight: AntigravityTheme.minTouchTargetPt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("selection-callout-copy")
                }
                .background(Color(red: 0.96, green: 0.97, blue: 0.99))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
                Spacer()
            }

            HStack(spacing: 8) {
                changeKindBadge(label: "MODIFY", tint: Self.warmAmber)
                Text("settlement/settlement_test.go")
                    .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(AntigravityTheme.inkReading)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Create one clock per subtest;")
                        .font(.system(size: 14.5))
                        .foregroundStyle(AntigravityTheme.inkLabel)

                    Text("remove the package-")
                        .font(.system(size: 14.5))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .padding(.horizontal, 3)
                        .background(Self.periwinkle.opacity(0.28))
                }

                HStack(spacing: 0) {
                    Text("level clk variable")
                        .font(.system(size: 14.5))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .padding(.horizontal, 3)
                        .background(Self.periwinkle.opacity(0.28))
                    Text(".")
                        .font(.system(size: 14.5))
                        .foregroundStyle(AntigravityTheme.inkLabel)
                }
            }
        }
    }

    private var inlineSelectionCommentEditor: some View {
        HStack(spacing: 8) {
            TextField("Comment on selected span...", text: $newSelectionCommentDraft)
                .font(.system(size: 14))
                .foregroundStyle(AntigravityTheme.inkReading)
                .padding(.horizontal, 12)
                .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                .background(Self.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                if !newSelectionCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    commentCount += 1
                    newSelectionCommentDraft = ""
                }
                isAddingSelectionComment = false
            } label: {
                Text("Save")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Self.inkOnCTA)
                    .padding(.horizontal, 14)
                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                    .background(Self.periwinkle)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var newClockHelperChange: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                changeKindBadge(label: "NEW", tint: Self.emeraldDone)
                Text("testutil/clock.go")
                    .font(.system(size: 13.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(AntigravityTheme.inkReading)
            }

            Text("NewTestClock(t) helper, released with t.Cleanup.")
                .font(.system(size: 14.5))
                .foregroundStyle(AntigravityTheme.inkLabel)
        }
    }

    private func changeKindBadge(label: String, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    // MARK: - 4. Sticky Bottom Bar

    private var bottomDecisionBar: some View {
        HStack(spacing: 12) {
            Button {
                if let firstPath = store.activeArtifacts.first?.artifactPath {
                    store.approveArtifactPlan(artifactPath: firstPath)
                }
                store.currentRoute = .chatAndComposer
            } label: {
                Text("Proceed")
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Self.pillBg)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-plan-proceed")

            Button {
                store.composerDraftText = "Plan review: submitted \(commentCount) inline comments."
                store.sendCurrentDraft()
                store.currentRoute = .chatAndComposer
            } label: {
                Text("Send \(commentCount) comments")
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(Self.inkOnCTA)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Self.periwinkle)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-plan-send-comments")
        }
    }
}
