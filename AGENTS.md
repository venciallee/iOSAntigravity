# iOSAntigravity Engineering & ESDD Guidelines

1. **Architecture**:
   - `Packages/AntigravityData` is a pure Swift 6 package containing the Connect-RPC client (`exa.language_server_pb.LanguageServerService`), 5-byte streaming envelope parser (`ConnectEnvelope`), binary protobuf step decoder (`ProtobufStepDecoder`), SQLite display projection (`LocalProjectionStore`), Durable Outbox, and Keychain store. It never imports `UIKit`.
   - `iOS/` owns the native UIKit + SwiftUI views, adaptive split navigation (`AntigravityShellController`), 120fps `CoreText` streaming chat (`CascadeChatViewController`), native permission gate (`InteractionGateSheetController`), Artifact reader (`ArtifactReviewViewController`), and word-level Turn Diff inspector (`TurnDiffViewController`).
   - `Shared/` owns `AntigravityTheme`, `AntigravityGlass`, and `AntigravityActivityAttributes` shared across the App, `AntigravityLiveActivity`, and `AntigravityShare` extensions.

2. **ESDD (Executable Spec Driven Development) Verification**:
   - Every state, event transition, design token, and UE acceptance claim is declared in `specs/esdd-ir.json`.
   - Offline deterministic fixtures are registered in `iOS/Application/DebugSceneFactory.swift` and routable via `antigravity://verify/<case>` with `--ui-verify`.
   - Run `python3 verification/esdd-verify.py` to execute the full E2E check:
     1. Mechanical Spec IR & State×Event Matrix completeness validation.
     2. Connect-RPC 5-byte envelope & Binary Protobuf E2E tests against `verification/mock_language_server.py`.
     3. Pixel-accurate `@3x` iPhone 16 Pro (`393×852pt`) screenshot rendering & Accessibility/HIG geometry audit (`>= 44pt` touch targets, safe areas, zero overlaps).
