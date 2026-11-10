import SwiftUI
import AntigravityData

/// State `S06_ARTIFACT_PLAN_REVIEW`: Renders Antigravity `implementation_plan.md` and `walkthrough.md`
/// artifacts with file switcher tabs, GitHub alerts, architecture diagrams, feedback input, and
/// `RequestFeedback` approval bar (`Proceed with Plan` / `Request Changes`).
public struct ArtifactReviewViewController: View {
    @Bindable public var store: AntigravitySessionStore
    @State private var isEditingFeedback: Bool = false
    @State private var feedbackText: String = ""

    public init(store: AntigravitySessionStore) {
        self.store = store
    }

    private var currentArtifact: ArtifactSnapshot {
        store.activeArtifacts.first(where: { $0.artifactPath == store.selectedArtifactPath })
            ?? store.activeArtifacts.first
            ?? ArtifactSnapshot(
                artifactPath: "/brain/implementation_plan.md",
                title: "implementation_plan.md",
                summary: "Architecture plan for Native iOS Antigravity Client over Connect-RPC",
                kind: .implementationPlan,
                content: "# iOSAntigravity Native Architecture Plan",
                requestFeedback: true,
                userFacing: true,
                version: 3
            )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Top Navigation & Artifact Tabs
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

                Text("\(currentArtifact.title) · v\(currentArtifact.version)")
                    .font(AntigravityTheme.TypographyTier.evidence.font)
                    .foregroundStyle(AntigravityTheme.inkReading)
                    .lineLimit(1)

                Spacer()

                if currentArtifact.requestFeedback {
                    Text("RequestFeedback")
                        .font(AntigravityTheme.TypographyTier.metadata.font)
                        .foregroundStyle(AntigravityTheme.statusWaiting)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AntigravityTheme.statusWaiting.opacity(0.16))
                        .clipShape(Capsule())
                }
            }
            .accessibilityIdentifier("artifact-header")

            // 2. Artifact Switcher Strip
            if store.activeArtifacts.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.activeArtifacts) { artifact in
                            let selected = artifact.artifactPath == currentArtifact.artifactPath
                            Button {
                                store.selectedArtifactPath = artifact.artifactPath
                            } label: {
                                Text(artifact.title)
                                    .font(AntigravityTheme.TypographyTier.metadata.font)
                                    .foregroundStyle(selected ? AntigravityTheme.inkReading : AntigravityTheme.inkSecondary)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: AntigravityTheme.minTouchTargetPt)
                                    .background(selected ? AntigravityTheme.accentPrimary.opacity(0.28) : AntigravityTheme.surfaceCard)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // 3. Artifact Body ScrollView
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // GitHub Alert [!IMPORTANT]
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(AntigravityTheme.accentSecondary)
                            Text("IMPORTANT")
                                .font(AntigravityTheme.TypographyTier.metadata.font)
                                .foregroundStyle(AntigravityTheme.accentSecondary)
                        }
                        Text("Direct Connect-RPC over /connect-websocket preserves 100% of Antigravity IDE trajectories, binary Protobuf steps (>600 ceiling), and Artifacts.")
                            .font(AntigravityTheme.TypographyTier.reading.font)
                            .foregroundStyle(AntigravityTheme.inkLabel)
                    }
                    .padding(14)
                    .background(AntigravityTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("artifact-alert-important")

                    // Architecture Diagram Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ARCHITECTURE TOPOLOGY")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.inkSecondary)
                        Text("iOS 18 App (Swift 6) ──[Connect-RPC 5B Frame]──▶ LanguageServerService (lt74xt6l0m-golden-star)")
                            .font(AntigravityTheme.TypographyTier.metadata.font)
                            .foregroundStyle(AntigravityTheme.accentSecondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AntigravityTheme.surfaceObsidian)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(14)
                    .background(AntigravityTheme.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(currentArtifact.content)
                        .font(AntigravityTheme.TypographyTier.reading.font)
                        .foregroundStyle(AntigravityTheme.inkReading)

                    if isEditingFeedback {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("REVISION FEEDBACK")
                                .font(AntigravityTheme.TypographyTier.metadata.font)
                                .foregroundStyle(AntigravityTheme.inkSecondary)
                            TextField("Describe changes requested on this plan...", text: $feedbackText, axis: .vertical)
                                .lineLimit(2...5)
                                .padding(12)
                                .background(AntigravityTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }

            // 4. Bottom Action Bar (Proceed with Plan / Request Changes)
            HStack(spacing: 12) {
                Button {
                    store.approveArtifactPlan(artifactPath: currentArtifact.artifactPath)
                } label: {
                    Text("Proceed with Plan")
                        .font(AntigravityTheme.TypographyTier.evidence.font)
                        .foregroundStyle(AntigravityTheme.inkReading)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
                .background(AntigravityTheme.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-proceed-plan")

                Button {
                    if isEditingFeedback && !feedbackText.trimmingCharacters(in: .whitespaces).isEmpty {
                        store.composerDraftText = "Plan Feedback (\(currentArtifact.title)): \(feedbackText)"
                        store.sendCurrentDraft()
                        store.currentRoute = .cascadeChat
                    } else {
                        isEditingFeedback.toggle()
                    }
                } label: {
                    Text(isEditingFeedback ? "Send Feedback" : "Request Changes")
                        .font(AntigravityTheme.TypographyTier.chrome.font)
                        .foregroundStyle(AntigravityTheme.inkLabel)
                        .frame(maxWidth: .infinity, minHeight: AntigravityTheme.minTouchTargetPt)
                }
                .buttonStyle(.plain)
                .background(AntigravityTheme.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("btn-edit-plan")
            }
        }
        .padding(16)
        .background(AntigravityTheme.canvasObsidian)
    }
}
