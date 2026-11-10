import SwiftUI
import AntigravityData

/// State `UE07_CHAT_AND_COMPOSER`: Official Message List, 7-Segment Task Card, Face ID Command Gate & Composer (`iOS · 消息列表与输入框`).
/// Features:
/// - Top navigation bar: `<` back button, `Add rate limiter to /tran...` + `ledger-svc · main · MacBook Pro`,
///   `+128 -14` diff pill (`chat-diff-pill` -> `.turnDiffReview`), and `•••` menu
/// - Message stream:
///   - Previous user message context chips `[@transfers.go]` `[Skill · go-testing]`
///   - Collapsible `👁 Thought for 14s ›` row (`row-thought-14s`)
///   - Assistant prose (`Plan approved with your 2 comments. Tests pass — next is a load test, which needs your OK.`)
///   - Embedded **Implementation Plan** card (`Approved · 2 comments addressed ›`, `card-artifact-plan` -> `.planReview`)
///   - **7-Segment `Task · 4 of 7 done` (`2m 41s`) Progress Card** (`card-task-progress-7seg`)
///   - **Inline `Run this command?` Amber Approval Card** (`card-command-approval`, `btn-command-deny`, `btn-command-allow-faceid`)
/// - Above-composer status strip: `🟠 Waiting for your approval · Step 5 of 7` + `[⏹ Stop]` pill (`btn-stop-turn`)
/// - Bottom `ChatComposerView`.
public struct CascadeChatViewController: View {
    @Bindable public var store: AntigravitySessionStore
    @State private var isTurnStopped: Bool = false

    private static let periwinkle = Color(red: 0x8E / 255.0, green: 0xB4 / 255.0, blue: 0xFF / 255.0) // #8EB4FF
    private static let warmAmber = Color(red: 0xEB / 255.0, green: 0xB3 / 255.0, blue: 0x65 / 255.0) // #EBB365
    private static let emeraldDone = Color(red: 0x57 / 255.0, green: 0xC8 / 255.0, blue: 0x8A / 255.0) // #57C88A
    private static let coralError = Color(red: 0xF0 / 255.0, green: 0x71 / 255.0, blue: 0x67 / 255.0) // #F07167
    private static let pillBg = Color(red: 0x1A / 255.0, green: 0x1C / 255.0, blue: 0x23 / 255.0)

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            chatTopNavigationBar

            Divider()
                .overlay(Color.white.opacity(0.06))

            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    // 1. Previous user message context chips bubble
                    UserPromptContextBubbleView(
                        promptText: nil,
                        contextChips: ["@transfers.go", "Skill · go-testing"]
                    )

                    // 2. Collapsible `👁 Thought for 14s ›` row
                    CollapsibleThoughtRowView(durationSeconds: 14)

                    // 3. Assistant prose
                    Text("Plan approved with your 2 comments. Tests pass — next is a load test, which needs your OK.")
                        .font(.system(size: 15))
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)

                    // 4. Embedded Implementation Plan artifact card
                    EmbeddedImplementationPlanCardView(
                        title: "Implementation Plan",
                        statusSubtitle: "Approved · 2 comments addressed"
                    ) {
                        store.currentRoute = .planReview
                    }

                    // 5. 7-Segment Task · 4 of 7 done Progress Card
                    SevenSegmentTaskProgressCardView(
                        completedCount: 4,
                        totalCount: 7,
                        elapsedLabel: "2m 41s"
                    )

                    // 6. Inline `Run this command?` Amber Approval Card with Face ID Allow
                    InlineCommandApprovalCardView(store: store)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            // Above-Composer Status Strip
            waitingStatusStrip
                .padding(.horizontal, 14)
                .padding(.top, 4)

            // Pinned Composer Card
            ChatComposerView(store: store)
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 6)
        }
        .background(AntigravityTheme.canvasObsidian)
    }

    // MARK: - Top Navigation Bar

    private var chatTopNavigationBar: some View {
        HStack(spacing: 8) {
            Button {
                store.currentRoute = .agentsHome
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Self.periwinkle)
                    .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-back-sessions")

            VStack(alignment: .leading, spacing: 2) {
                Text("Add rate limiter to /transfers")
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("ledger-svc · main · MacBook Pro")
                    .font(.system(size: 12))
                    .foregroundStyle(AntigravityTheme.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // `+128 -14` Diff Pill -> `.turnDiffReview`
            Button {
                store.currentRoute = .turnDiffReview
            } label: {
                HStack(spacing: 5) {
                    Text("+128")
                        .foregroundStyle(Self.emeraldDone)
                    Text("-14")
                        .foregroundStyle(Self.coralError)
                }
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 11)
                .frame(minWidth: AntigravityTheme.minTouchTargetPt, minHeight: AntigravityTheme.minTouchTargetPt)
                .background(Self.pillBg)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chat-diff-pill")

            // `•••` Overflow Menu
            Menu {
                Button("Open Implementation Plan") {
                    store.currentRoute = .planReview
                }
                Button("Review Turn Changes") {
                    store.currentRoute = .turnDiffReview
                }
                Button("Structured Question Demo") {
                    store.currentRoute = .structuredQuestion
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .frame(width: AntigravityTheme.minTouchTargetPt, height: AntigravityTheme.minTouchTargetPt)
            }
            .accessibilityIdentifier("btn-chat-more")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    // MARK: - Above-Composer Status Strip

    private var waitingStatusStrip: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isTurnStopped ? AntigravityTheme.inkSecondary : Self.warmAmber)
                .frame(width: 8, height: 8)

            Text(
                isTurnStopped
                    ? "Turn stopped · Step 5 of 7"
                    : "Waiting for your approval · Step 5 of 7"
            )
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isTurnStopped ? AntigravityTheme.inkSecondary : Self.warmAmber)
            .lineLimit(1)

            Spacer()

            Button {
                isTurnStopped = true
                store.stopActiveCascadeStreaming()
            } label: {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 9, height: 9)
                    Text("Stop")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AntigravityTheme.inkReading)
                }
                .padding(.horizontal, 14)
                .frame(minWidth: AntigravityTheme.minTouchTargetPt, minHeight: AntigravityTheme.minTouchTargetPt)
                .background(Self.pillBg)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btn-stop-turn")
        }
    }
}
