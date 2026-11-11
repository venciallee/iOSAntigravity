#!/usr/bin/env python3
"""macOS Xcode + iPhone Simulator Real Native E2E & 13-Screen Capture Runner (`ios-simulator-runner.py`).

When executed on macOS with Xcode 16+ installed:
1. Runs `xcodegen generate` from `project.yml`.
2. Compiles `Antigravity.app` (including `AntigravityLiveActivity` & `AntigravityShare`) for `iphonesimulator` under Swift 6.
3. Boots a real `iPhone 16 Pro` / `iPhone 16` (`393×852pt @3x`) Simulator and overrides the status bar (`9:41`).
4. Spins up `scripts/mac-companion-bridge.py`, launches `Antigravity.app` with live `ANTIGRAVITY_BACKEND_URL` + `ANTIGRAVITY_CSRF_TOKEN`,
   verifies real Connect-RPC requests hit the backend from the Simulator app, and captures `LIVE_CONNECTED_HOME.png`.
5. Iterates through all 13 `UE01`..`UE13` native SwiftUI scenes (`--ui-verify <STATE_ID>`), captures native
   `xcrun simctl io <udid> screenshot` PNGs into `verification/output/real-simulator/`, and renders a 13-screen overview board.
"""
import importlib.util
import json
import os
import platform
import secrets
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path


PREFERRED_IPHONES = [
    "iPhone 16 Pro",
    "iPhone 16",
    "iPhone 15 Pro",
    "iPhone 15",
]


def select_iphone_simulator() -> tuple[str, str, str]:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"], text=True
    )
    devices = json.loads(raw)["devices"]
    runtimes = [r for r in sorted(devices.keys(), reverse=True) if "iOS" in r]

    for preferred in PREFERRED_IPHONES:
        for runtime in runtimes:
            for dev in devices[runtime]:
                if dev.get("isAvailable") and dev.get("name") == preferred:
                    return dev["udid"], dev["name"], runtime

    for runtime in runtimes:
        for dev in devices[runtime]:
            name = dev.get("name", "")
            if dev.get("isAvailable") and "iPhone" in name and "SE" not in name:
                return dev["udid"], name, runtime

    for runtime in runtimes:
        for dev in devices[runtime]:
            if dev.get("isAvailable") and "iPhone" in dev.get("name", ""):
                return dev["udid"], dev["name"], runtime

    raise RuntimeError("No available iPhone Simulator found in Xcode.")


def build_overview_sheet(out_dir: Path, state_ids: list[str], device_label: str):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("[!] Pillow not installed; skipping composite overview generation.")
        return

    cols = 4
    rows = (len(state_ids) + cols - 1) // cols
    thumb_w, thumb_h = 360, 780
    pad_x, pad_y = 32, 72
    header_h = 110
    canvas_w = pad_x + cols * (thumb_w + pad_x)
    canvas_h = header_h + pad_y + rows * (thumb_h + pad_y)

    board = Image.new("RGB", (canvas_w, canvas_h), (9, 10, 13))
    draw = ImageDraw.Draw(board)
    draw.text(
        (pad_x, 28),
        f"iOSAntigravity — Real Xcode iOS Simulator Native SwiftUI Captures ({device_label})",
        fill=(245, 247, 250),
    )
    draw.text(
        (pad_x, 60),
        "Compiled via xcodebuild (-swift-version 6) & captured via `xcrun simctl io screenshot` across UE01..UE13",
        fill=(142, 180, 255),
    )

    for idx, sid in enumerate(state_ids):
        p = out_dir / f"{sid}.png"
        if not p.exists():
            continue
        r = idx // cols
        c = idx % cols
        x = pad_x + c * (thumb_w + pad_x)
        y = header_h + r * (thumb_h + pad_y)
        img = Image.open(p).convert("RGB")
        img.thumbnail((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        ox = x + (thumb_w - img.width) // 2
        oy = y + 28
        draw.text((x, y), sid, fill=(213, 216, 226))
        board.paste(img, (ox, oy))

    overview_path = out_dir / "REAL_SIMULATOR_13_SCREENS_OVERVIEW.png"
    board.save(overview_path, format="PNG")
    print(f"  [OVERVIEW] {overview_path}")


def main():
    repo_root = Path(__file__).resolve().parents[1]
    if platform.system() != "Darwin":
        print("Note: macOS / xcrun not detected; delegating to cross-platform esdd-verify.py")
        subprocess.run([sys.executable, str(repo_root / "verification" / "esdd-verify.py")], check=True)
        return

    ir = json.loads((repo_root / "specs" / "esdd-ir.json").read_text(encoding="utf-8"))
    out_dir = repo_root / "verification" / "output" / "real-simulator"
    out_dir.mkdir(parents=True, exist_ok=True)

    print("=== [1/5] Generating Xcode Project via XcodeGen ===")
    subprocess.run(["xcodegen", "generate"], cwd=repo_root, check=True)

    udid, sim_name, sim_runtime = select_iphone_simulator()
    print(f"=== [2/5] Booting Simulator {sim_name} ({sim_runtime}, UDID={udid}) ===")
    subprocess.run(["xcrun", "simctl", "boot", udid], check=False)
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True)
    subprocess.run(
        [
            "xcrun",
            "simctl",
            "status_bar",
            udid,
            "override",
            "--time",
            "9:41",
            "--batteryState",
            "charged",
            "--batteryLevel",
            "100",
            "--wifiBars",
            "3",
            "--cellularMode",
            "active",
            "--cellularBars",
            "4",
        ],
        check=False,
    )

    print(f"=== [3/5] Building Antigravity.app & Running Real XCUITest Tap Suite (AntigravityUITests) on {sim_name} ===")
    derived = repo_root / ".build" / "DerivedData"
    xcresult_path = out_dir / "AntigravityUITests.xcresult"
    shutil.rmtree(xcresult_path, ignore_errors=True)
    uitest_log_path = out_dir / "uitests.log"
    uitest_cmd = [
        "xcodebuild",
        "test",
        "-project",
        "iOSAntigravity.xcodeproj",
        "-scheme",
        "Antigravity",
        "-sdk",
        "iphonesimulator",
        "-destination",
        f"id={udid}",
        "-derivedDataPath",
        str(derived),
        "-only-testing:AntigravityUITests",
        "-resultBundlePath",
        str(xcresult_path),
        "CODE_SIGN_IDENTITY=-",
        "CODE_SIGNING_REQUIRED=NO",
        "AD_HOC_CODE_SIGNING_ALLOWED=YES",
    ]
    with uitest_log_path.open("w", encoding="utf-8") as log_fp:
        proc = subprocess.Popen(
            uitest_cmd,
            cwd=repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        assert proc.stdout is not None
        for line in proc.stdout:
            sys.stdout.write(line)
            log_fp.write(line)
        ret = proc.wait()
        if ret != 0:
            raise subprocess.CalledProcessError(ret, uitest_cmd)
    print("  [PASS] Real XCUITest Interactive UI Tap Suite (AntigravityUITests) succeeded.")

    print(f"=== [4/5] Verifying Live Connect-RPC App Handshake on {sim_name} ===")
    app_path = next((derived / "Build" / "Products" / "Debug-iphonesimulator").glob("Antigravity.app"))
    subprocess.run(["xcrun", "simctl", "install", udid, str(app_path)], check=True)

    # Spin up real Connect-RPC companion bridge in-process and verify the compiled iOS app connects over HTTP!
    spec = importlib.util.spec_from_file_location("bridge", repo_root / "scripts" / "mac-companion-bridge.py")
    bridge_mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bridge_mod)

    rpc_hits = []
    csrf_token = f"sim-live-{secrets.token_hex(8)}"
    bridge_srv = bridge_mod.create_bridge_server(
        bind_host="127.0.0.1",
        bind_port=0,
        bridge_csrf=csrf_token,
        workspace_root=str(repo_root),
    )
    orig_do_post = bridge_srv.RequestHandlerClass.do_POST

    def tracked_do_post(self):
        rpc_hits.append(self.path)
        return orig_do_post(self)

    bridge_srv.RequestHandlerClass.do_POST = tracked_do_post
    bridge_port = bridge_srv.server_port
    threading.Thread(target=bridge_srv.serve_forever, daemon=True).start()

    try:
        subprocess.run(["xcrun", "simctl", "terminate", udid, "dev.antigravity.ios.app"], check=False)
        launch_env = os.environ.copy()
        launch_env["SIMCTL_CHILD_NO_PROXY"] = "127.0.0.1,localhost,::1"
        launch_env["SIMCTL_CHILD_ANTIGRAVITY_BACKEND_URL"] = f"http://127.0.0.1:{bridge_port}"
        launch_env["SIMCTL_CHILD_ANTIGRAVITY_CSRF_TOKEN"] = csrf_token
        launch_env["SIMCTL_CHILD_ANTIGRAVITY_HOST_NAME"] = "Cloud Mac Runner"
        subprocess.run(
            ["xcrun", "simctl", "launch", udid, "dev.antigravity.ios.app"],
            env=launch_env,
            check=True,
        )
        # Wait up to 10 seconds for SwiftUI WindowGroup `.task` to perform live Connect-RPC handshake
        for _ in range(20):
            if any("GetWorkspaceInfos" in p for p in rpc_hits) and any("GetAllCascadeTrajectories" in p for p in rpc_hits):
                break
            time.sleep(0.5)
        time.sleep(1.5)

        live_shot = out_dir / "LIVE_CONNECTED_HOME.png"
        subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(live_shot)], check=True)
        (out_dir / "live_rpc_hits.json").write_text(json.dumps(rpc_hits, indent=2), encoding="utf-8")
        print(f"  [LIVE RPC] App-to-Backend Connect-RPC hits from Simulator: {rpc_hits}")
        assert any("GetWorkspaceInfos" in p for p in rpc_hits), (
            f"Expected compiled Antigravity.app to call GetWorkspaceInfos over Connect-RPC, got: {rpc_hits}"
        )
        assert any("GetAllCascadeTrajectories" in p for p in rpc_hits), (
            f"Expected compiled Antigravity.app to call GetAllCascadeTrajectories over Connect-RPC, got: {rpc_hits}"
        )
    finally:
        bridge_srv.shutdown()
        bridge_srv.server_close()

    print("=== [5/5] Capturing All 13 Native SwiftUI UE Screens (UE01 .. UE13) on iOS Simulator ===")
    state_ids = []
    for state in ir["states"]:
        state_id = state["id"]
        state_ids.append(state_id)
        subprocess.run(
            ["xcrun", "simctl", "terminate", udid, "dev.antigravity.ios.app"],
            check=False,
        )
        clean_env = {k: v for k, v in os.environ.items() if not k.startswith("SIMCTL_CHILD_ANTIGRAVITY_")}
        subprocess.run(
            [
                "xcrun",
                "simctl",
                "launch",
                udid,
                "dev.antigravity.ios.app",
                "--ui-verify",
                state_id,
            ],
            env=clean_env,
            check=True,
        )
        time.sleep(1.8)
        shot_path = out_dir / f"{state_id}.png"
        subprocess.run(
            ["xcrun", "simctl", "io", udid, "screenshot", str(shot_path)],
            check=True,
        )
        print(f"  [CAPTURED] {state_id} -> {shot_path}")

    build_overview_sheet(out_dir, state_ids, f"{sim_name} · {sim_runtime}")
    manifest = {
        "simulatorName": sim_name,
        "simulatorRuntime": sim_runtime,
        "simulatorUDID": udid,
        "uiTestsPassed": True,
        "liveConnectRPCHits": rpc_hits,
        "capturedStates": state_ids,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("\nALL REAL XCUITEST UI TAPS + 13 IOS SIMULATOR SCREENS + LIVE CONNECT-RPC HANDSHAKE VERIFIED.")


if __name__ == "__main__":
    main()
