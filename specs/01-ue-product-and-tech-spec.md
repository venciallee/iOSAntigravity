# Antigravity iOS App — Product Requirements & Native Swift 6 Technical Architecture (v2.0 UE Aligned)

## 1. Product Overview & Design System Alignment

Based on the 13 official Antigravity iOS UE specifications, **Antigravity iOS** provides a zero-compromise native mobile experience synchronized seamlessly across **Local Desktop Hosts (`MacBook Pro` via Remote Control Connect-RPC)** and **Cloud VMs (`Cloud` autonomous sandboxes)**.

### 1.1 Visual & Interaction Design Tokens
- **Canvas & Surfaces**:
  - Background Canvas: `#090A0D` (Pure OLED Matte Obsidian)
  - Grouped Card Surface: `#141519` (`18pt` continuous corner radius, `1px` `rgba(255,255,255,0.08)` border)
  - Elevated Sheet / Context Menu: `#1D1F26` / `#25272F` (`28pt` sheet corner radius with top grabber)
- **Brand & Semantic Colors**:
  - **Primary Brand CTA (`accentPeriwinkle`)**: `#8EB4FF` with `#0A0E17` dark bold label ink (used for primary buttons, active borders, selected checkboxes, and detached bottom-right `56×56pt` circular FABs)
  - **Active Filter / Stepper Pill**: Pure White `#FFFFFF` fill with `#090A0D` bold text
  - **Running (`运行中`)**: `#7DA7FF` (spinning progress arc or dot)
  - **Needs You / Awaiting Approval (`等你处理`)**: `#EBB365` Warm Amber (pulsing halo dot, amber-tinted approval card, and solid `#EBB365` Face ID `Allow` CTA)
  - **Done / Additions (`完成`)**: `#57C88A` Emerald (`+128`, `42 passed`, `NEW`)
  - **Deletions / Destructive**: `#F07167` Coral (`-14`, `Delete`)
- **Global Bottom Navigation Chrome**:
  - Floating Liquid Glass 3-tab capsule (`Agents` | `Automations` | `Settings`) on the left + detached `56×56pt` Periwinkle `#8EB4FF` circular action FAB (`✏️` on Agents, `+` on Automations) on the right.

---

## 2. Functional Requirements Across All 13 UE Screens

| Screen ID | UE Screen Name | Core Product Requirements | Connect-RPC / Data Binding |
| :--- | :--- | :--- | :--- |
| **`UE01`** | **Agents 首页** | Host switcher (`MacBook Pro` / `Cloud`), Display Options button, New Project button, Search bar, Filter pills (`All`, `Running 2`, `Needs you 1`, `Unread 3`), `PINNED` section, collapsible Project groups (`ledger-svc`, `web-console`), Floating Tab Bar + Compose FAB | `JetboxSubscribeToSummaries` + `GetWorkspaceInfos` + `LocalProjectionStore` |
| **`UE02`** | **Display Options** | `Reset` / `Done` header, `Group By` (`Project`/`Host`/`None`), `Sort Conversations` (`Last Updated`/`Date Created`/`Title` + `Newest First`/`Oldest First` pull-down menu), `Sort Projects`, `Filter`, `Display`, `Auto Pin` toggle, `Archived Only` toggle, `Mark All as Read (3 unread)` | Persisted `AgentDisplayOptions` state driving `AntigravitySessionStore` sorting/grouping |
| **`UE03`** | **长按菜单 & Pin** | Rich Long-Press preview card (`Fix flaky TestSettlementBatch`, full message summary, `Implementation Plan` + `Awaiting review` chips), Context Menu (`Pin`, `Mark as Unread`, `Rename`, `Move to Project`, `Archive`, `Delete`), and left-swipe `Pin` + `Archive` actions | `PinCascade`, `RenameCascade`, `MoveCascadeToWorkspace`, `ArchiveCascade`, `DeleteCascade` |
| **`UE04`** | **项目页 (`ledger-svc`)** | `< Agents` back nav, `~/code/ledger-svc` path, metadata pills (`Local · MacBook Pro`, `main`, `5 conversations`), `New Conversation in Project` CTA, `Active 3 / Archived 2 / Automations 1` underline tabs, conversation list, and `THIS PROJECT` (`Nightly dependency audit`, `Reveal in Finder on Mac`, `Project rules & skills (4)`) | `StartCascade` scoped to `workspaceUri` + `OpenWorkspaceInFinder` RPC |
| **`UE05`** | **Create New Project** | `RUNS ON` segmented picker (`MacBook Pro` vs `Cloud`), `SOURCE` cards (`GitHub repository` vs `Drive folder`), repo search + list (`acme/ledger-svc`, `acme/web-console`, `acme/design-tokens`), `Branch & worktree` (`main · New worktree`), `Name` (`ledger-svc-cloud`), `Create Project` CTA | `CreateProjectWorkspace` (local worktree or cloud VM provisioning) |
| **`UE06`** | **Automations** | NL quick-create bar (`Every weekday at 9, summarize` + `Create`), `SCHEDULED · 2` cards (`Nightly dependency audit`, `Weekly flaky-test report`) with `▶` Run Now & `NEXT RUN` / `LAST RUN` stat boxes, `ALWAYS ON · 1` (`Triage new pull requests`), `PAUSED · 1` (`Bundle size watch` + `Resume`), Floating Tab Bar + `+` FAB | `ListAutomations`, `CreateAutomation`, `TriggerAutomationNow`, `SetAutomationPaused` |
| **`UE07`** | **消息列表与输入框** | Top bar with `<`, title + `ledger-svc · main · MacBook Pro`, `+128 -14` diff pill; `Thought for 14s ›` collapsible row; Embedded `Implementation Plan` card; `Task · 4 of 7 done` (`2m 41s`) 7-segment progress card with checklist; Inline amber `Run this command?` card (`vegeta attack...`) with `Deny` and biometric Face ID (`LAContext`) `Allow`; Status bar `Waiting for your approval · Step 5 of 7` + `Stop`; Composer with `@ratelimit.go ×` chip, multi-line text, `+`, `Planning ⌄`, `Gemini 3.1 Pro ⌄`, `🎤`, and `↑` Send | `GetCascadeTrajectorySteps` (5-byte Connect stream + binary Protobuf >600 steps), `HandleCascadeUserInteraction` (`runCommand` + Face ID), `SendUserCascadeMessage`, `CancelCascadeInvocation` |
| **`UE08`** | **Add Context** | Search bar, 5 category tiles (`Files`, `Folder`, `Mentions`, `Actions`, `Skills`), `FILES & FOLDERS` (`ratelimit.go`, `load/`), `MENTIONS` (`Idempotency keys for payouts`, `Terminal · last test run`), `ACTIONS & SKILLS` (`/boost`, `go-testing`), bottom `3 selected` + `Add to message` CTA | Attaches structured `ContextItem` chips to `ChatComposerView` |
| **`UE09`** | **Model & Mode** | `Planning` vs `Fast` cards, `MODEL` picker (`Gemini 3.1 Pro`, `Gemini 3.8 Flash`, `Claude Opus 5.5 [Thinking]`, `Claude Sonnet 5.5 [Thinking]`), and `AGENT` persona pills (`Default`, `go-reviewer`, `release-captain`) | Updates `CascadeModelConfig` (`modelId`, `mode`, `agentPersona`) for next turn |
| **`UE10`** | **结构化多选问答** | Multi-question stepper pills (`✓ 1 Storage`, `2 Actions`, `3 Retention`), `Question 2 of 3 · Select all that apply`, checkbox cards (`Account freeze / unfreeze`, `Limit changes`, `Manual ledger adjustments`, `Role & permission changes`), dashed `Something else...` write-in, `Back` / `Next` buttons, and bottom `Reply in your own words` composer | `HandleCascadeUserInteraction` (`askQuestion` oneof with multi-step answers or freeform text) |
| **`UE11`** | **Implementation Plan 审阅** | `[💬 2]` badge, amber paused banner (`Agent is paused until you review. Long-press any text to comment.`), rendered Markdown with `MODIFY`/`NEW` badges, inline pending comment card (`WL You Pending`), text-selection `[💬 Comment | Copy]` callout, and `Proceed` / `Send 2 comments` bar | `GetArtifactSnapshots` + `HandleCascadeUserInteraction` (`filePermission` / plan review comments) |
| **`UE12`** | **Turn Diff 行级审查** | `Accept all` button, `Turn 1` / `Turn 2` / `Turn 3 · latest` / `All` selector pills, `middleware/ratelimit.go (File 1 of 4 · +96 -4)` pager, `Revert hunk`, syntax-highlighted diff with word-level emphasis, selected Line 29 inline comment composer (`Add to review` / `Send to agent`), and `Viewed` checkbox + `Revert file` + `Accept file` | `GetTurnDiff` + `RevertDiffHunk` + `SendDiffReviewComments` |
| **`UE13`** | **灵动岛 & Live Activity** | 7 WidgetKit states: Compact Running (`4/7`), Compact Waiting (`Approve`), Minimal Ring, Compact Done (`+128 -14`), Expanded Running (`Stop`/`Open`), Expanded Waiting (`Deny` + Face ID `Allow`), and Lock Screen Multi-Agent aggregation card (`2 running · 1 needs you`) | `ActivityKit` + `ApproveWaitingStepIntent` (`AppIntent` + `LAContext` Face ID signature) |

---

## 3. Normative Swift 6 Public API Contract (Shared Across Modules)

To enable parallel engineering across `Packages/AntigravityData`, `iOS/`, `Shared/`, and `Extensions/`, all modules adhere to the following public types in `AntigravityData`:

1. **Top-Level Navigation & Scene Enumeration**:
   - `public enum PrimaryTab: String, CaseIterable, Sendable { case agents, automations, settings }`
   - `public enum ESDDVerifySceneCase: String, CaseIterable, Sendable`:
     - `.agentsHome = "UE01_AGENTS_HOME"`
     - `.displayOptions = "UE02_DISPLAY_OPTIONS"`
     - `.contextMenuPin = "UE03_CONTEXT_MENU_PIN"`
     - `.projectDetail = "UE04_PROJECT_DETAIL"`
     - `.createProject = "UE05_CREATE_PROJECT"`
     - `.automations = "UE06_AUTOMATIONS"`
     - `.chatAndComposer = "UE07_CHAT_AND_COMPOSER"`
     - `.addContext = "UE08_ADD_CONTEXT"`
     - `.modelAndMode = "UE09_MODEL_AND_MODE"`
     - `.structuredQuestion = "UE10_STRUCTURED_QUESTION"`
     - `.planReview = "UE11_PLAN_REVIEW"`
     - `.turnDiffReview = "UE12_TURN_DIFF_REVIEW"`
     - `.liveActivitySpec = "UE13_LIVE_ACTIVITY_SPEC"`
2. **Core Domain Models (`Packages/AntigravityData/Sources/AntigravityData/Models/`)**:
   - `RemoteHostInstance`, `ProjectWorkspace`, `NewProjectDraft` (`runsOn: ProjectRuntimeTarget`, `source: ProjectSourceKind`, `selectedRepo: GitHubRepoItem?`, `branchWorktree: String`, `projectName: String`)
   - `AgentDisplayOptions` (`groupBy`, `sortBy`, `sortAscending`, `autoPinOnMessage`, `archivedOnly`)
   - `AutomationItem` (`id`, `title`, `projectSlug`, `scheduleLabel`, `modelBadge`, `category: AutomationCategory`, `nextRunLabel`, `lastRunLabel`, `needsReview`)
   - `ContextCandidateItem` (`id`, `category: ContextCategory`, `title`, `subtitle`, `isSelected`)
   - `CascadeModelConfig` (`modelId`, `displayName`, `subtitle`, `supportsThinkingBadge`, `requiresProBadge`, `mode: CascadeExecutionMode`, `agentPersona: String`)
   - `StructuredQuestionStep` & `StructuredQuestionWizard` (multi-step `1 Storage`, `2 Actions`, `3 Retention` with `selectedOptions: Set<String>` and `customWriteIn: String`)
   - `PlanInlineComment` & `DiffLineReviewComment`
3. **Central Coordinator (`AntigravitySessionStore`)**:
   - `@MainActor @Observable public final class AntigravitySessionStore` exposing state and mutation methods for all 13 UE screens and deterministic `makeESDDVerificationStore()` fixture matching the exact UE sample data (`ledger-svc`, `web-console`, `Add rate limiter to /transfers`, `Fix flaky TestSettlementBatch`, `Upgrade to Go 1.25`, `Nightly dependency audit`, `vegeta attack`, `middleware/ratelimit.go`, etc.).
