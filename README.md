# iOSAntigravity — Native Swift 6 iOS Client for Antigravity Remote Control

`iOSAntigravity` is a native **Swift 6 + UIKit / SwiftUI** iOS client that connects directly to Google DeepMind's **Antigravity IDE & CLI Remote Control (`exa.language_server_pb.LanguageServerService`)**, delivering 100% real-time conversation & trajectory synchronization with a pure iOS Human Interface Guidelines (HIG) experience.

---

## 1. Architecture Overview (Path A: Direct Connect-RPC)

Unlike generic ACP wrappers that spawn an isolated headless agent and lose desktop IDE session continuity, `iOSAntigravity` connects directly to the active Antigravity Hub `language_server --standalone --subclient_type hub` process:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ iOSAntigravity App (Swift 6 · iOS 18+ · iPhone 16 Pro & iPad Adaptive Split) │
│                                                                              │
│  ├─ Extensions/LiveActivity : Dynamic Island, Lock Screen & AppIntent Approve│
│  ├─ Extensions/Share        : Credential-free App Group Share Sheet          │
│  ├─ iOS/Views & Controllers : 120fps CoreText Streaming, Diff & Plan Review  │
│  └─ Packages/AntigravityData:                                                │
│       ├─ AntigravityRPCClient (Connect-RPC + /connect-websocket)             │
│       ├─ ConnectEnvelope      (5-byte [flags:1B][length:4B BE] parser)       │
│       ├─ ProtobufStepCodec    (Binary application/proto >600 step decoder)   │
│       ├─ InteractionBuilder   (Field 56 RequestedInteraction oneof matcher)  │
│       └─ LocalProjectionStore (<10ms SQLite cold start + Durable Outbox)     │
└──────────────────────┬───────────────────────────────────────┬───────────────┘
                       │ Channel A: QR Zero-Config             │ Channel B: Direct
                       ▼                                       ▼
        ┌──────────────────────────────┐        ┌──────────────────────────────┐
        │ Google Cloud Relay           │        │ LAN / Tailscale / Sidecar    │
        │ antigravity.google.com/r/<id>│        │ Zstd Compression + APNs Push │
        └──────────────┬───────────────┘        └──────────────┬───────────────┘
                       └───────────────────┬───────────────────┘
                                           ▼
        ┌──────────────────────────────────────────────────────────────────────┐
        │ Host Machine: language_server --standalone --subclient_type hub      │
        │ Jetbox SQLite (conversation_summaries.db) & Cortex/Cascade Engine    │
        └──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Antigravity Obsidian & Liquid Glass Design System

Defined normatively in [`specs/01-antigravity-design-system.md`](file:///home/antigravity/venciallee/iOSAntigravity/specs/01-antigravity-design-system.md) and [`AntigravityTheme.swift`](file:///home/antigravity/venciallee/iOSAntigravity/Shared/DesignSystem/AntigravityTheme.swift):

- **Surface Hierarchy**:
  - **Obsidian Canvas (`#090B10`)**: True deep-space background blending into the iPhone 16 Pro Dynamic Island.
  - **Elevated Surface (`#111520`)** & **Interactive Card (`#161B29`)** with `1px` specular hairline borders (`rgba(255,255,255,0.08)`).
  - **Liquid Glass Chrome**: `UIBlurEffect.Style.systemChromeMaterialDark` for navigation headers and the floating `ChatComposerView`.
- **5-Tier Semantic Typography Hierarchy**:
  1. **Reading (`16pt / 400 / #F8FAFC`)**: User prompts and Agent prose answers.
  2. **Evidence (`14pt / 500 / #E2E8F0`)**: Modified filenames, Artifacts (`implementation_plan.md`), and diff stats.
  3. **Process (`13pt / 400 / #94A3B8`)**: Collapsible Thinking capsules, tool calls, and terminal logs.
  4. **Metadata (`11pt / 400 / #64748B`)**: Step indices, RTT latency, and Git worktree badges.
  5. **Chrome (`13pt / 500 / #94A3B8`)**: Navigation pills, model/effort selectors, and action buttons.

---

## 3. ESDD (Executable Spec Driven Development) End-to-End Verification

Every feature and UE requirement is governed by our **ESDD** pipeline in [`specs/esdd-ir.json`](file:///home/antigravity/venciallee/iOSAntigravity/specs/esdd-ir.json) and [`verification/esdd-verify.py`](file:///home/antigravity/venciallee/iOSAntigravity/verification/esdd-verify.py):

```bash
python3 verification/esdd-verify.py
```

The runner executes 4 automated verification stages:
1. **Spec-DAG & Swift Contract Inspection ([`esdd_inspector.py`](file:///home/antigravity/venciallee/iOSAntigravity/verification/esdd_inspector.py))**: Verifies complete reachability across all 8 states (`S01`..`S08`) and 9 events (`E01`..`E09`), and checks that all 15 Swift 6 protocol/UI symbols exist in the codebase.
2. **Live Connect-RPC E2E Tests ([`mock_language_server.py`](file:///home/antigravity/venciallee/iOSAntigravity/verification/mock_language_server.py))**: Tests real 5-byte Connect streaming envelopes (`JetboxSubscribeToSummaries`), 605-step binary Protobuf decoding (`GetCascadeTrajectorySteps`), and authoritative oneof matching (`HandleCascadeUserInteraction`).
3. **Pixel-Accurate `@3x` (`1179×2556px`) iPhone 16 Pro Rendering & HIG Audit ([`ui_renderer.py`](file:///home/antigravity/venciallee/iOSAntigravity/verification/ui_renderer.py))**: Renders all 8 states and asserts `>= 44pt` touch targets, safe area clearance, and zero horizontal overflow.
4. **Evidence Packaging**: Outputs [`verification/output/report.md`](file:///home/antigravity/venciallee/iOSAntigravity/verification/output/report.md), [`verification/output/results.json`](file:///home/antigravity/venciallee/iOSAntigravity/verification/output/results.json), and `@3x` screenshots in `verification/output/screenshots/`.
