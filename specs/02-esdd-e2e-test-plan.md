# ESDD End-to-End Functional & UE Visual Acceptance Test Plan (v2.0)

## 1. Verification Philosophy

Every requirement from the 13 official UE screens (`UE01` .. `UE13`) is verified end-to-end across **4 automated gates**:

1. **Gate 1 — Mechanical Spec-DAG & Swift 6 Source Contract Check**:
   - Verifies all 13 states (`UE01_AGENTS_HOME` .. `UE13_LIVE_ACTIVITY_SPEC`), 13 navigation transitions (`E01` .. `E13`), 13 claims (`CLAIM-01` .. `CLAIM-13`), balanced syntax/AST structure across all Swift files, and 100% `accessibilityIdentifier` / `data-testid` parity.
2. **Gate 2 — Connect-RPC & Binary Protobuf Live Server E2E (`mock_language_server.py`)**:
   - Tests 5-byte Connect streaming frames (`JetboxSubscribeToSummaries`), >600-step binary `application/proto` trajectory decoding (`GetCascadeTrajectorySteps`), Face ID-signed `HandleCascadeUserInteraction` (`runCommand`, `askQuestion`, `filePermission`), Project creation (`CreateProjectWorkspace`), and Automation triggering (`TriggerAutomationNow`).
3. **Gate 3 — Interactive User-Journey E2E Tests in Headless Mobile Viewport (`TC-01` .. `TC-16`)**:
   - Executes real click, text-entry, filter, checkbox, comment, and approval interactions inside a `393×852pt @3x` mobile viewport and asserts DOM/state transitions.
4. **Gate 4 — 1:1 Side-by-Side Reference UE vs Implemented `@3x` Visual Comparison**:
   - Renders all 13 screens at `@3x` (`1179×2556px`), audits HIG geometry (`minTouchTarget >= 44pt`, `overflowPx == 0`), generates side-by-side comparison pairs (`CMP_UE01.png` .. `CMP_UE13.png`) against the user's 13 uploaded UE PNGs, and builds a full master comparison overview sheet.

---

## 2. Executable Test Case Matrix (`TC-01` .. `TC-16`)

| Test ID | Target Screen(s) | Test Scenario & User Action | Expected Functional & UE Acceptance Outcome |
| :--- | :--- | :--- | :--- |
| **`TC-01`** | `UE01_AGENTS_HOME` | Launch Agents Home; inspect Host switcher (`MacBook Pro`), Pinned section, `ledger-svc` & `web-console` groups, and tap `Needs you 1` filter pill | Shows online green dot, filters list to `Fix flaky TestSettlementBatch` (`Needs review · Implementation plan ready`), Floating Tab Bar + Periwinkle FAB intact (`overflowPx == 0`) |
| **`TC-02`** | `UE02_DISPLAY_OPTIONS` | Open Display Options sheet; inspect `Sort Conversations` popover (`Last Updated` / `Newest First`), toggle `Auto Pin`, tap `Mark All as Read` | Unread count drops from `3 unread` to `0 unread`; `Reset` restores defaults |
| **`TC-03`** | `UE03_CONTEXT_MENU_PIN` | Long-press `Fix flaky TestSettlementBatch` and swipe left on `Upgrade to Go 1.25` | Renders rich preview card with `Implementation Plan` + `Awaiting review` pills, 6 context menu actions, and swipe `Pin` (`#8EB4FF`) + `Archive` buttons |
| **`TC-04`** | `UE04_PROJECT_DETAIL` | Navigate into `ledger-svc` project page; switch `Active 3` / `Archived 2` / `Automations 1` tabs; tap `New Conversation in Project` | Displays `~/code/ledger-svc`, metadata pills, `THIS PROJECT` tools (`Nightly dependency audit`, `Reveal in Finder on Mac`, `Project rules & skills 4`), and opens new chat |
| **`TC-05`** | `UE05_CREATE_PROJECT` | Open `New Project` sheet; select `Cloud` runtime + `GitHub repository`, pick `acme/ledger-svc`, set `ledger-svc-cloud`, tap `Create Project` | Dispatches `CreateProjectWorkspace` RPC and adds `ledger-svc-cloud` project group |
| **`TC-06`** | `UE06_AUTOMATIONS` | Switch to `Automations` tab; enter NL prompt + tap `Create`; tap `▶` on `Nightly dependency audit`; tap `Resume` on `Bundle size watch` | Creates new scheduled automation, triggers immediate run via RPC, and moves paused item to active |
| **`TC-07`** | `UE07_CHAT_AND_COMPOSER` | Open `Add rate limiter to /transfers`; inspect `+128 -14` badge, `Thought for 14s ›`, `Implementation Plan` card, and `Task · 4 of 7 done` 7-segment progress bar | 4 blue + 1 amber + 2 dark segments rendered accurately; tapping `Thought for 14s ›` expands reasoning |
| **`TC-08`** | `UE07_CHAT_AND_COMPOSER` | Tap `[Face ID] Allow` on `vegeta attack -rate=2000/s` command card; also test Composer text entry + `[↑]` Send | Sends `HandleCascadeUserInteraction` (`runCommand.confirm = true`), updates step status from `Waiting` to `Running/Done`; sending draft appends turn & clears `@ratelimit.go` chip |
| **`TC-09`** | `UE08_ADD_CONTEXT` | Tap `+` in Composer -> `Add Context`; filter by `Skills` / `Files`, select `ratelimit.go`, `Idempotency keys for payouts`, `go-testing` (`3 selected`), tap `Add to message` | Injects all 3 context chips into `ChatComposerView` |
| **`TC-10`** | `UE09_MODEL_AND_MODE` | Tap `Gemini 3.1 Pro ⌄` pill -> `Model & Mode`; toggle `Planning` vs `Fast`, select `Claude Opus 5.5 [Thinking]`, select `go-reviewer` agent pill, tap `Done` | Updates Composer pills to `Planning` + `Claude Opus 5.5` and active persona to `go-reviewer` |
| **`TC-11`** | `UE10_STRUCTURED_QUESTION` | On `Audit log for admin actions`, toggle multi-select options (`Account freeze / unfreeze`, `Limit changes`, `Manual ledger adjustments`), type in `Something else...`, tap `Next` -> `3 Retention` -> `Submit` | Advances stepper from `2 Actions` to `3 Retention` and dispatches `HandleCascadeUserInteraction` (`askQuestion` payload) |
| **`TC-12`** | `UE11_PLAN_REVIEW` | Open `Implementation Plan` (`v2`); inspect amber paused banner, pending comment (`WL You`), select text -> tap `Comment`, then tap `Send 2 comments` | Appends inline review comment, increments `[💬 2]` badge, and sends structured plan feedback to agent |
| **`TC-13`** | `UE12_TURN_DIFF_REVIEW` | Open `Review changes` (`Turn 3 · latest`, `middleware/ratelimit.go`); tap line `29`, enter comment, tap `Send to agent` / `Accept file` | Renders word-level `+96 -4` diff, attaches line-29 review comment, toggles `Viewed`, and accepts patch |
| **`TC-14`** | `UE13_LIVE_ACTIVITY_SPEC` | Render and audit all 7 Dynamic Island & Lock Screen Live Activity states | Verifies Compact Running (`4/7`), Compact Waiting (`Approve`), Minimal Ring, Compact Done (`+128 -14`), Expanded Running, Expanded Waiting (Face ID `Allow`), and Lock Screen Multi-Agent card |
| **`TC-15`** | **Connect-RPC Binary Ceiling** | Request `GetCascadeTrajectorySteps` for 605-step trajectory over `application/proto` | Decodes all 605 binary Protobuf steps without hitting the 600-step JSON serializer limit |
| **`TC-16`** | **Global HIG & Visual Parity** | Run `@3x` bounding-box & side-by-side UE visual audit across all 13 screens | `scrollWidth <= viewportWidth` (`0px` overflow), interactive controls meet touch-target invariants, and 13/13 side-by-side comparison sheets generated |
