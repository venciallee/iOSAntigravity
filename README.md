# iOSAntigravity — Native Swift 6 iOS App for Antigravity (v2.0 UE Complete)

`iOSAntigravity` is a native **Swift 6 + UIKit / SwiftUI** iOS 18 application connecting directly to **Antigravity Desktop Remote Control (`exa.language_server_pb.LanguageServerService`)** and **Antigravity Cloud VMs**, implementing all **13 official UE screens (`UE01` .. `UE13`)** and verified end-to-end via **ESDD (`TC-01` .. `TC-16`)**.

---

## 1. Architecture & 13 Official UE Screens

- **Design System (`Shared/DesignSystem/`)**:
  - Pure OLED Matte Obsidian (`#090A0D`), Grouped Cards (`#141519`), Periwinkle Soft Blue Primary CTA (`#8EB4FF` with `#0A0E17` dark ink), Active White Filter Pills (`#FFFFFF`), Running Blue (`#7DA7FF`), Face ID Warm Amber (`#EBB365`), Emerald Diff `+` (`#57C88A`), and Coral Diff `-` (`#F07167`).
  - Signature **Floating Liquid Glass 3-Tab Capsule (`Agents` | `Automations` | `Settings`) + Detached `56×56pt` Periwinkle FAB**.
- **Native View Hierarchy (`iOS/` & `Extensions/`)**:
  1. **`UE01` [`AgentsHomeViewController.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Home/AgentsHomeViewController.swift)**: Host switcher (`MacBook Pro` / `Cloud`), search, filter pills (`All`, `Running 2`, `Needs you 1`, `Unread 3`), `PINNED` card, collapsible project groups (`ledger-svc`, `web-console`).
  2. **`UE02` [`DisplayOptionsSheetView.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Home/DisplayOptionsSheetView.swift)**: `Group By`, `Sort Conversations` popover menu, `Auto Pin`, `Archived Only`, and `Mark All as Read`.
  3. **`UE03` [`ConversationContextPreviewMenu.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Home/ConversationContextPreviewMenu.swift)**: Long-press rich preview card (`Implementation Plan` + `Awaiting review` chips), 6-action menu, and left-swipe `Pin` + `Archive`.
  4. **`UE04` [`ProjectDetailViewController.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Projects/ProjectDetailViewController.swift)**: `ledger-svc` hero header, `New Conversation in Project` CTA, `Active / Archived / Automations` tabs, and `THIS PROJECT` tools.
  5. **`UE05` [`CreateProjectSheetView.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Projects/CreateProjectSheetView.swift)**: `MacBook Pro` vs `Cloud` VM runtime, `GitHub repository` vs `Drive folder` source, repo search, and worktree setup.
  6. **`UE06` [`AutomationsViewController.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Automations/AutomationsViewController.swift)**: Natural-language automation creator, `SCHEDULED` (`Next Run` / `Last Run` + `▶`), `ALWAYS ON`, and `PAUSED` (`Resume`).
  7. **`UE07` [`CascadeChatViewController.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Cascade/CascadeChatViewController.swift) + [`ChatComposerView.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/Views/Composer/ChatComposerView.swift)**: `+128 -14` diff pill, `Thought for 14s ›`, embedded Plan card, 7-segment `Task · 4 of 7 done` progress card, Face ID (`LAContext`) `Allow` / `Deny` command approval card, and Liquid Glass Composer (`@ratelimit.go ×`, `+`, `Planning ⌄`, `Gemini 3.1 Pro ⌄`, `🎤`, `↑`).
  8. **`UE08` [`AddContextSheetView.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/Views/Composer/AddContextSheetView.swift)**: 5 category tiles (`Files`, `Folder`, `Mentions`, `Actions`, `Skills`), multi-select list, and `Add to message`.
  9. **`UE09` [`ModelAndModeSheetView.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/Views/Composer/ModelAndModeSheetView.swift)**: `Planning` / `Fast` cards, `Gemini 3.1 Pro` / `Gemini 3.8 Flash` / `Claude Opus 5.5` / `Claude Sonnet 5.5`, and `Default` / `go-reviewer` / `release-captain` agent personas.
  10. **`UE10` [`StructuredQuestionCardView.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Cascade/StructuredQuestionCardView.swift)**: 3-step stepper (`1 Storage` / `2 Actions` / `3 Retention`), multi-select checkboxes, `Something else...`, `Back` / `Next`, and freeform reply bar.
  11. **`UE11` [`ImplementationPlanReviewViewController.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Inspector/ImplementationPlanReviewViewController.swift)**: Paused amber banner, `MODIFY` / `NEW` file badges, inline pending comment card, text-selection `[Comment | Copy]` callout, and `Proceed` / `Send 2 comments`.
  12. **`UE12` [`TurnDiffReviewViewController.swift`](file:///home/antigravity/venciallee/iOSAntigravity/iOS/ViewControllers/Inspector/TurnDiffReviewViewController.swift)**: `Turn 1..3 / All` selector, `File 1 of 4` pager, `Revert hunk`, word-level diff, Line 29 inline comment composer (`Add to review` / `Send to agent`), and `Viewed` + `Revert file` + `Accept file`.
  13. **`UE13` [`AntigravityLiveActivityWidget.swift`](file:///home/antigravity/venciallee/iOSAntigravity/Extensions/LiveActivity/AntigravityLiveActivityWidget.swift)**: All 7 Dynamic Island (Compact Running/Waiting/Done, Minimal Ring, Expanded Running/Waiting with Face ID) & Lock Screen Multi-Agent states.

---

## 2. Running End-to-End ESDD Verification

```bash
# Run all 4 ESDD E2E verification gates + 13-screen @3x Side-by-Side UE comparison
python3 verification/esdd-verify.py

# On macOS with Xcode 16+: run XCTest suite & native iOS Simulator capture
cd Packages/AntigravityData && swift test
cd ../.. && python3 verification/ios-simulator-runner.py
```
