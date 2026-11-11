#!/usr/bin/env python3
"""macOS Xcode Simulator 13-Screen Capture Runner (`ios-simulator-runner.py`).

When executed on macOS with Xcode 16+ installed:
1. Runs `xcodegen generate` from `project.yml`.
2. Builds `Antigravity.app` for `iphonesimulator`.
3. Boots the simulator, installs `Antigravity.app`, and iterates through all 13
   `antigravity://verify/<case>` deep links declared in `specs/esdd-ir.json` (`UE01`..`UE13`).
4. Captures native `xcrun simctl io <udid> screenshot` PNGs into `verification/output/real-simulator/`.
"""
import json
import platform
import subprocess
import sys
import time
from pathlib import Path


def select_iphone_udid() -> str:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"], text=True
    )
    devices = json.loads(raw)["devices"]
    for runtime in sorted(devices.keys(), reverse=True):
        if "iOS" not in runtime:
            continue
        for dev in devices[runtime]:
            if dev.get("isAvailable") and "iPhone" in dev.get("name", ""):
                return dev["udid"]
    raise RuntimeError("No available iPhone Simulator found in Xcode.")


def main():
    repo_root = Path(__file__).resolve().parents[1]
    if platform.system() != "Darwin":
        print("Note: macOS / xcrun not detected; delegating to cross-platform esdd-verify.py")
        subprocess.run([sys.executable, str(repo_root / "verification" / "esdd-verify.py")], check=True)
        return

    ir = json.loads((repo_root / "specs" / "esdd-ir.json").read_text(encoding="utf-8"))
    subprocess.run(["xcodegen", "generate"], cwd=repo_root, check=True)

    udid = select_iphone_udid()
    derived = repo_root / ".build" / "DerivedData"
    subprocess.run(
        [
            "xcodebuild",
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
            "CODE_SIGNING_ALLOWED=NO",
            "build",
        ],
        cwd=repo_root,
        check=True,
    )

    subprocess.run(["xcrun", "simctl", "boot", udid], check=False)
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True)

    app_path = next((derived / "Build" / "Products" / "Debug-iphonesimulator").glob("Antigravity.app"))
    subprocess.run(["xcrun", "simctl", "install", udid, str(app_path)], check=True)

    out_dir = repo_root / "verification" / "output" / "real-simulator"
    out_dir.mkdir(parents=True, exist_ok=True)

    for state in ir["states"]:
        state_id = state["id"]
        subprocess.run(
            ["xcrun", "simctl", "terminate", udid, "dev.antigravity.ios.app"],
            check=False,
        )
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
            check=True,
        )
        time.sleep(1.2)
        shot_path = out_dir / f"{state_id}.png"
        subprocess.run(
            ["xcrun", "simctl", "io", udid, "screenshot", str(shot_path)],
            check=True,
        )
        print(f"  [CAPTURED] {state_id} -> {shot_path}")


if __name__ == "__main__":
    main()
