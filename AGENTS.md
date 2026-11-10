# iOSAntigravity Engineering & ESDD Guidelines (v2.0 UE Aligned)

1. **Architecture**:
   - `Packages/AntigravityData` is a pure Swift 6 package containing the Connect-RPC client (`exa.language_server_pb.LanguageServerService`), 5-byte streaming envelope parser (`ConnectEnvelope`), binary protobuf step decoder (`ProtobufStepDecoder`), local display projection (`LocalProjectionStore`), Durable Outbox, Keychain store, and central `AntigravitySessionStore`. It never imports `UIKit`.
   - `iOS/` owns all 13 native UE controllers & sheets: `AntigravityShellController` (Floating Liquid Glass 3-Tab Capsule + detached `#8EB4FF` Periwinkle FAB), `AgentsHomeViewController` (`UE01`), `DisplayOptionsSheetView` (`UE02`), `ConversationContextPreviewMenu` (`UE03`), `ProjectDetailViewController` (`UE04`), `CreateProjectSheetView` (`UE05`), `AutomationsViewController` (`UE06`), `CascadeChatViewController` + `ChatComposerView` (`UE07`), `AddContextSheetView` (`UE08`), `ModelAndModeSheetView` (`UE09`), `StructuredQuestionCardView` (`UE10`), `ImplementationPlanReviewViewController` (`UE11`), and `TurnDiffReviewViewController` (`UE12`).
   - `Shared/` & `Extensions/` own `AntigravityTheme` (`#090A0D` Matte Obsidian, `#8EB4FF` Periwinkle CTA, `#EBB365` Face ID Amber Approval), `AntigravityGlass`, `AntigravityActivityAttributes`, and `AntigravityLiveActivityWidget` (`UE13` 7-state Dynamic Island & Multi-Agent Lock Screen).

2. **ESDD (Executable Spec Driven Development) Verification**:
   - All 13 UE states (`UE01_AGENTS_HOME` .. `UE13_LIVE_ACTIVITY_SPEC`), 13 navigation transitions (`E01` .. `E13`), and 13 claims (`CLAIM-01` .. `CLAIM-13`) are declared in `specs/esdd-ir.json`, alongside 16 interactive E2E test cases (`TC-01` .. `TC-16`) in `specs/02-esdd-e2e-test-plan.md`.
   - Offline deterministic fixtures are registered in `iOS/Application/DebugSceneFactory.swift` and routable via `antigravity://verify/<case>` with `--ui-verify`.
   - Run `python3 verification/esdd-verify.py` to execute the full 4-gate E2E suite:
     1. Mechanical Spec-DAG & Swift 6 Source Contract completeness validation.
     2. Connect-RPC 5-byte envelope, >600-step Binary Protobuf, Face ID Interaction, Project, and Automation E2E tests against `verification/mock_language_server.py`.
     3. 16 Interactive E2E user-journey flows (`TC-01` .. `TC-16`) in headless `393×852pt @3x` viewport.
     4. Pixel-accurate `@3x` screenshot rendering, HIG geometry audit (`0px` horizontal overflow), and 1:1 Side-by-Side Reference UE vs Implemented comparison sheets (`verification/output/comparisons/CMP_UE01..CMP_UE13.png`).
