# iOSAntigravity — Native Swift 6 iOS App for Antigravity (v2.0 UE + Live Connect-RPC)

`iOSAntigravity` is a native **Swift 6 + SwiftUI / UIKit** iOS 18 application connecting directly to **Antigravity Desktop (`exa.language_server_pb.LanguageServerService`)** and **Antigravity Cloud VMs**, implementing all **13 official UE screens (`UE01` .. `UE13`)**, live **Connect-RPC session creation & streaming**, and a **4-gate ESDD E2E verification suite (`TC-01` .. `TC-16`)**.

---

## 1. Repository Structure & Normative Specs

| Directory / File | Responsibility |
| :--- | :--- |
| [`specs/01-ue-product-and-tech-spec.md`](specs/01-ue-product-and-tech-spec.md) | v2.0 Product Requirements & Native Swift 6 Technical Architecture across all 13 UE screens |
| [`specs/02-esdd-e2e-test-plan.md`](specs/02-esdd-e2e-test-plan.md) | Executable Spec Driven Development (ESDD) E2E Test Plan (`TC-01` .. `TC-16`, `CLAIM-01` .. `CLAIM-13`) |
| [`specs/esdd-ir.json`](specs/esdd-ir.json) | Machine-verifiable ESDD Intermediate Representation (`13` states, `13` transitions, `114` selectors) |
| [`Packages/AntigravityData/`](Packages/AntigravityData/) | Pure Swift 6 data & protocol package (`ConnectEnvelope` 5B framing, `ProtobufStepDecoder` `>600` steps, `AntigravityRPCClient`, `KeychainStore`, `LocalProjectionStore`, `AntigravitySessionStore`) |
| [`iOS/`](iOS/) & [`Shared/`](Shared/) & [`Extensions/`](Extensions/) | Native Matte Obsidian (`#090A0D`) & Liquid Glass (`#8EB4FF` Periwinkle CTA, `#EBB365` Face ID Amber) controllers & Live Activity extension |
| [`scripts/mac-companion-bridge.py`](scripts/mac-companion-bridge.py) | Zero-dependency macOS Companion Bridge auto-discovering local `language_server` port & `--csrf_token` for LAN / Tailscale iPhone pairing |
| [`verification/`](verification/) | 4-gate ESDD verifier (`esdd-verify.py`), live Connect-RPC lifecycle verifier (`verify-live-rpc-flow.py`), and `@3x` comparison generator |

---

## 2. Connecting to Live Backend (Official Remote Control QR & Connect-RPC)

### Option A (Recommended) — Scan Official Antigravity Remote Control QR (Zero Bridge / Any Network)

No companion script, LAN IP, or Tailscale setup is required — works seamlessly over both Wi-Fi and 5G cellular:

1. On your Mac or PC, open **Antigravity Desktop** and click **Remote Control** to display the official QR code (`https://antigravity.google.com/r/<instance-id>`).
2. On your iPhone, open the **`Settings`** tab ([`RemotePairingViewController.swift`](iOS/ViewControllers/Pairing/RemotePairingViewController.swift)) and tap **Scan Remote Control QR Code** ([`RemoteControlQRScannerSheet.swift`](iOS/ViewControllers/Pairing/RemoteControlQRScannerSheet.swift)) — or pick a QR screenshot / paste the `/r/<id>` link.
3. Sign in once with your Google account in [`CloudRelaySignInSheet.swift`](iOS/ViewControllers/Pairing/CloudRelaySignInSheet.swift). `iOSAntigravity` securely stores the session in iOS Keychain ([`KeychainStore.swift`](Packages/AntigravityData/Sources/AntigravityData/Store/KeychainStore.swift)), computes `SAPISIDHASH` ([`CloudRelayProtocol.swift`](Packages/AntigravityData/Sources/AntigravityData/Protocol/CloudRelayProtocol.swift)), resolves your online Desktop UUID via `ApiService/ListInstances` (auto-probing multi-account `X-Goog-AuthUser`), and tunnels all unary & streaming `LanguageServerService` RPCs through `ApiService/ProxyCommand` & `StreamProxyCommand`.

### Option B (Optional Local Fallback) — Direct LAN / Tailscale via Mac Companion Bridge

If you prefer offline local-only LAN / Tailscale routing without Google Cloud Relay:

1. Run `python3 scripts/mac-companion-bridge.py` on macOS to auto-discover the local `language_server` port & `--csrf_token` and expose `http://<Mac-LAN-IP>:8787`.
2. In **`Settings`** → **Direct LAN / Bridge**, enter `http://<Mac-LAN-IP>:8787` + `x-codeium-csrf-token` (or set `ANTIGRAVITY_BACKEND_URL` / `ANTIGRAVITY_CSRF_TOKEN` in Xcode Simulator).

### Step 3 — Create Sessions & Send Streaming Messages

- **Create Session (`StartCascade`)**: Tap the detached `#8EB4FF` Periwinkle compose FAB (`fab-compose`) on `Agents` Home or **New Conversation in Project** in Project Detail -> [`AntigravitySessionStore.createConversationInProject`](Packages/AntigravityData/Sources/AntigravityData/Store/AntigravitySessionStore.swift) calls `POST /exa.language_server_pb.LanguageServerService/StartCascade` and binds the returned `cascadeId`.
- **Send Message & Stream Steps (`SendUserCascadeMessage` + `GetCascadeTrajectorySteps`)**: Attach `@file` / Skill chips via `+` ([`AddContextSheetView.swift`](iOS/Views/Composer/AddContextSheetView.swift)), pick `Planning / Fast` & model ([`ModelAndModeSheetView.swift`](iOS/Views/Composer/ModelAndModeSheetView.swift)), and tap Send in [`ChatComposerView.swift`](iOS/Views/Composer/ChatComposerView.swift). Outgoing prompts queue in `LocalProjectionStore`'s Durable Outbox, dispatch `SendUserCascadeMessage`, and live-sync trajectory steps (`JSON` for `<600` steps, `application/proto` binary Protobuf for `>=600` steps).

---

## 3. Running E2E Verification

```bash
# 1. Verify live Connect-RPC Login (401->200) + StartCascade + SendUserCascadeMessage + Face ID Gate + Protobuf >600 steps
python3 verification/verify-live-rpc-flow.py

# 2. Verify against a running Mac Companion Bridge
python3 verification/verify-live-rpc-flow.py --url http://<Mac-LAN-IP>:8787 --csrf <token>

# 3. Run full 4-Gate ESDD Verification Suite (Spec-DAG + 16 E2E Journeys + 13 @3x Visual Comparisons)
python3 verification/esdd-verify.py

# 4. Run Swift 6 XCTest protocol & store unit tests (macOS / Swift 6 toolchain)
cd Packages/AntigravityData && swift test
```

---

## 4. 13 Official UE Screens — 1:1 Side-by-Side Verification Gallery (`@3x`)

| UE ID | Screen & Swift Controller | Reference UE (Left) vs Implemented `@3x` Render (Right) |
| :--- | :--- | :--- |
| **`UE01`** | **Agents Home** ([`AgentsHomeViewController.swift`](iOS/ViewControllers/Home/AgentsHomeViewController.swift)) | ![CMP_UE01](verification/output/comparisons/CMP_UE01.png) |
| **`UE02`** | **Display Options & Sort Popover** ([`DisplayOptionsSheetView.swift`](iOS/ViewControllers/Home/DisplayOptionsSheetView.swift)) | ![CMP_UE02](verification/output/comparisons/CMP_UE02.png) |
| **`UE03`** | **Long-Press Preview & Swipe Pin** ([`ConversationContextPreviewMenu.swift`](iOS/ViewControllers/Home/ConversationContextPreviewMenu.swift)) | ![CMP_UE03](verification/output/comparisons/CMP_UE03.png) |
| **`UE04`** | **Project Detail (`ledger-svc`)** ([`ProjectDetailViewController.swift`](iOS/ViewControllers/Projects/ProjectDetailViewController.swift)) | ![CMP_UE04](verification/output/comparisons/CMP_UE04.png) |
| **`UE05`** | **Create New Project** ([`CreateProjectSheetView.swift`](iOS/ViewControllers/Projects/CreateProjectSheetView.swift)) | ![CMP_UE05](verification/output/comparisons/CMP_UE05.png) |
| **`UE06`** | **Automations Hub** ([`AutomationsViewController.swift`](iOS/ViewControllers/Automations/AutomationsViewController.swift)) | ![CMP_UE06](verification/output/comparisons/CMP_UE06.png) |
| **`UE07`** | **Chat Stream, 7-Seg Task, Face ID Gate & Composer** ([`CascadeChatViewController.swift`](iOS/ViewControllers/Cascade/CascadeChatViewController.swift)) | ![CMP_UE07](verification/output/comparisons/CMP_UE07.png) |
| **`UE08`** | **Add Context Sheet** ([`AddContextSheetView.swift`](iOS/Views/Composer/AddContextSheetView.swift)) | ![CMP_UE08](verification/output/comparisons/CMP_UE08.png) |
| **`UE09`** | **Model, Mode & Agent Persona** ([`ModelAndModeSheetView.swift`](iOS/Views/Composer/ModelAndModeSheetView.swift)) | ![CMP_UE09](verification/output/comparisons/CMP_UE09.png) |
| **`UE10`** | **Structured Multi-Step Question** ([`StructuredQuestionCardView.swift`](iOS/ViewControllers/Cascade/StructuredQuestionCardView.swift)) | ![CMP_UE10](verification/output/comparisons/CMP_UE10.png) |
| **`UE11`** | **Implementation Plan Review** ([`ImplementationPlanReviewViewController.swift`](iOS/ViewControllers/Inspector/ImplementationPlanReviewViewController.swift)) | ![CMP_UE11](verification/output/comparisons/CMP_UE11.png) |
| **`UE12`** | **Turn Diff Line-Level Review** ([`TurnDiffReviewViewController.swift`](iOS/ViewControllers/Inspector/TurnDiffReviewViewController.swift)) | ![CMP_UE12](verification/output/comparisons/CMP_UE12.png) |
| **`UE13`** | **Dynamic Island & Lock Screen Live Activity** ([`AntigravityLiveActivityWidget.swift`](Extensions/LiveActivity/AntigravityLiveActivityWidget.swift)) | ![CMP_UE13](verification/output/comparisons/CMP_UE13.png) |

---

## 5. Original App Icon & App Store 5.2.2 Trademark Compliance (原创图标与商标声明)

### Original Independent App Icon (`AG Orbit` · `AppIcon.appiconset`)
- Uses a **100% original** 7-segment Periwinkle (`#8EB4FF`) + Warm Amber (`#EBB365`) Orbital Terminal icon ([`scripts/assets/ag-orbit-original-icon.svg`](scripts/assets/ag-orbit-original-icon.svg)) rendered across iOS 18+ **Light**, **Dark**, and **Tinted** `1024×1024` opaque sRGB slots in [`iOS/Resources/Assets.xcassets/AppIcon.appiconset/`](iOS/Resources/Assets.xcassets/AppIcon.appiconset/) via [`scripts/render-brand-icons.py`](scripts/render-brand-icons.py).
- Contains **zero** official Google logo/icon files, fully satisfying **Apple App Store Review Guideline 5.2.2 & 4.1**.
- Uses companion display naming (`CFBundleDisplayName = "AG Orbit"` / *"AG Orbit — Companion for Antigravity"*) across the main app, Live Activity, and Share Extension in [`project.yml`](project.yml).

### Copyright & Trademark Disclaimer
- **Original App Icon & Client Code**: **© 2026 iOSAntigravity Contributors. All rights reserved.**
- **Trademark Notice**: `AG Orbit` is an independent, unofficial third-party companion client and is **not** affiliated with, endorsed by, or sponsored by **Google LLC**. *"Google"* and *"Antigravity"* are trademarks of Google LLC, referenced solely for nominative compatibility description (see [`NOTICE`](NOTICE) and in-app **Settings -> About & Copyright**).
