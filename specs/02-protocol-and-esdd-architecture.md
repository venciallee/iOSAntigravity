# Spec 02: Connect-RPC Protocol & ESDD End-to-End Verification Architecture

Status: Approved (Normative ESDD Spec)

## 1. Pure Swift Connect-RPC Architecture (Path A)

Unlike multi-agent wrappers that lose IDE session continuity, `iOSAntigravity` connects directly to the host's `language_server --standalone --subclient_type hub` process via `exa.language_server_pb.LanguageServerService`:

1. **Dual-Channel Transport (`AntigravityRPCClient.swift`)**:
   - **Channel A (Official Cloud Relay)**: Scans the QR code from Antigravity Desktop `Settings → Application → Remote Control` (`https://antigravity.google.com/r/<instance-id>`), authenticates via `ASWebAuthenticationSession`, and opens `/connect-websocket` directly—bypassing the 9MB desktop React web bundle.
   - **Channel B (Direct LAN / Tailscale / Sidecar)**: Connects directly to `https://<host>:<port>` with `x-codeium-csrf-token` and negotiates `permessage-deflate` / Zlib compression.

2. **Connect 5-Byte Streaming Envelope (`ConnectEnvelope.swift`)**:
   - Server-streaming RPCs (`JetboxSubscribeToSummaries`, `StreamCascadeReactiveUpdates`, `StreamAgentStateUpdates`, `ProjectUpdatesStream`) frame each message with a 5-byte prefix:
     - Byte 0: `flags` (`0x00` = uncompressed message, `0x01` = compressed message, `0x02` = EndStream trailer).
     - Bytes 1..4: `uint32` big-endian payload length.

3. **Binary Protobuf Trajectory Decoding (`ProtobufStepDecoder.swift`)**:
   - `GetCascadeTrajectorySteps` in JSON mode truncates trajectories above 600 steps.
   - `ProtobufStepDecoder` encodes `cascadeId` (field 1), `startIndex` (field 2), `endIndex` (field 3) as raw protobuf wire bytes (`Content-Type: application/proto`) and decodes all 21 `CORTEX_STEP_TYPE_*` variants, 8 `CORTEX_STEP_STATUS_*` states, and field 56 `requestedInteraction` (`exa.cortex_pb.RequestedInteraction` oneof with 17 members).

4. **Authoritative Interaction Dispatch (`InteractionBuilder.swift`)**:
   - When a step enters `CORTEX_STEP_STATUS_WAITING (9)`, `InteractionBuilder` inspects `step.requestedInteraction` and constructs the exact matching oneof member for `HandleCascadeUserInteraction`:
     - `permission` (field 21): `{ allow: true, turnGrants: { allow: ["action(pattern)"], deny: [] } }`
     - `filePermission` (field 19): `{ allow: true, scope: "PERMISSION_SCOPE_ONCE", absolutePathUri }`
     - `runCommand` (field 3): `{ confirm: true, proposedCommandLine, submittedCommandLine }`
     - `askQuestion` (field 22): `{ selectedOptions, customResponse }`

## 2. ESDD (Executable Spec Driven Development) Verification Loop

Our ESDD pipeline ensures zero drift between specification, Swift implementation, protocol behavior, and visual UE:

```
┌───────────────────────────┐
│ 1. specs/esdd-ir.json     │  Normative State×Event Matrix, Design Tokens, & Claims
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│ 2. esdd_inspector.py      │  Validates State×Event completeness & Swift source symbols
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│ 3. mock_language_server.py│  Tests real 5-byte Connect-RPC & Binary Protobuf E2E flows
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│ 4. ui_renderer.py         │  Renders all 8 iOS states at 393×852pt @3x (1179×2556 PNG)
│    + AX Geometry Audit    │  Asserts >=44pt touch targets, safe areas, zero overlaps
└─────────────┬─────────────┘
              ▼
┌───────────────────────────┐
│ 5. Visual Screenshot Gate │  Immutable report.md + results.json + @3x PNG inspection
└───────────────────────────┘
```
