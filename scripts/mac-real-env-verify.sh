#!/usr/bin/env bash
# ==============================================================================
# iOSAntigravity — Real macOS + Xcode + Antigravity Desktop E2E Verifier
# Run on your Mac:
#   bash scripts/mac-real-env-verify.sh
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export NO_PROXY="127.0.0.1,localhost,::1${NO_PROXY:+,$NO_PROXY}"
export no_proxy="127.0.0.1,localhost,::1${no_proxy:+,$no_proxy}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[!] macOS not detected ($(uname -s)). Running cross-platform live RPC + ESDD suite instead..."
  python3 verification/verify-live-rpc-flow.py
  python3 verification/esdd-verify.py
  exit 0
fi

echo "=== [1/5] Swift 6 Package Compilation & XCTest Suite (AntigravityData) ==="
swift --version
swift test --package-path Packages/AntigravityData

echo ""
echo "=== [2/5] Live Antigravity Desktop Companion Bridge & Connect-RPC Handshake ==="
pkill -f "scripts/mac-companion-bridge.py" >/dev/null 2>&1 || true
sleep 0.3
BRIDGE_CSRF="agy-mac-verify-$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -d'-' -f1)"
BRIDGE_PORT="$(python3 -c '
import socket
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        s.bind(("127.0.0.1", 8787))
        print(8787)
    except OSError:
        s.bind(("127.0.0.1", 0))
        print(s.getsockname()[1])
')"

rm -f /tmp/antigravity-bridge.log
PYTHONUNBUFFERED=1 python3 -u scripts/mac-companion-bridge.py \
  --port "$BRIDGE_PORT" \
  --csrf "$BRIDGE_CSRF" >/tmp/antigravity-bridge.log 2>&1 &
BRIDGE_PID=$!
trap 'kill "$BRIDGE_PID" >/dev/null 2>&1 || true' EXIT

echo "[*] Waiting for Companion Bridge (PID ${BRIDGE_PID}) on http://127.0.0.1:${BRIDGE_PORT}/health ..."
BRIDGE_READY=0
for _ in $(seq 1 60); do
  if ! kill -0 "$BRIDGE_PID" >/dev/null 2>&1; then
    echo "[!] Companion Bridge exited unexpectedly during startup. Log:"
    cat /tmp/antigravity-bridge.log || true
    exit 1
  fi
  if curl -fsS --noproxy '*' --max-time 1 "http://127.0.0.1:${BRIDGE_PORT}/health" >/dev/null 2>&1; then
    BRIDGE_READY=1
    break
  fi
  sleep 0.25
done

cat /tmp/antigravity-bridge.log || true

if [[ "$BRIDGE_READY" -ne 1 ]]; then
  echo "[!] Timed out waiting 15s for Companion Bridge to listen on port ${BRIDGE_PORT}."
  exit 1
fi

HEALTH_JSON="$(curl -fsS --noproxy '*' --max-time 2 "http://127.0.0.1:${BRIDGE_PORT}/health" 2>/dev/null || echo '{}')"
if echo "$HEALTH_JSON" | grep -q '"upstream_proxy"'; then
  python3 verification/verify-live-rpc-flow.py --url "http://127.0.0.1:${BRIDGE_PORT}" --csrf "$BRIDGE_CSRF" --read-only
else
  python3 verification/verify-live-rpc-flow.py --url "http://127.0.0.1:${BRIDGE_PORT}" --csrf "$BRIDGE_CSRF"
fi

echo ""
echo "=== [3/5] Generating Xcode Project & Booting Simulator ==="
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "[*] Installing xcodegen via Homebrew..."
    brew install xcodegen
  else
    echo "[!] xcodegen not found. Install via 'brew install xcodegen' and re-run."
    exit 1
  fi
fi

xcodegen generate

SIM_INFO_FILE="$(mktemp "${TMPDIR:-/tmp}/agy-sim-info.XXXXXX")"
TAIL_PID=""
trap 'rm -f "$SIM_INFO_FILE"; [[ -n "$TAIL_PID" ]] && kill "$TAIL_PID" >/dev/null 2>&1 || true; kill "$BRIDGE_PID" >/dev/null 2>&1 || true' EXIT

python3 - >"$SIM_INFO_FILE" <<'PY'
import json
import re
import subprocess
import sys
import time

data = {}
for _ in range(4):
    try:
        raw = subprocess.check_output(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            text=True,
        )
        data = json.loads(raw).get("devices", {})
        if any("iOS" in rt and data.get(rt) for rt in data.keys()):
            break
    except Exception:
        pass
    time.sleep(1.0)

def runtime_sort_key(rt: str):
    nums = [int(x) for x in re.findall(r"\d+", rt)]
    return tuple(nums) if nums else (0,)

ios_runtimes = sorted(
    [rt for rt in data.keys() if "iOS" in rt],
    key=runtime_sort_key,
    reverse=True,
)

def emit(dev: dict, rt: str):
    print("|".join([str(dev.get("udid", "")), str(dev.get("name", "")), rt]))
    sys.exit(0)

# 1. Prefer an already Booted iPhone Simulator first (instant attach)
for rt in ios_runtimes:
    for dev in data.get(rt, []):
        if dev.get("isAvailable") and dev.get("state") == "Booted" and "iPhone" in dev.get("name", ""):
            emit(dev, rt)

# 2. Prefer modern Pro / standard iPhone models on newest iOS runtime
preferred = ["iPhone 17 Pro", "iPhone 16 Pro", "iPhone 17", "iPhone 16", "iPhone 15 Pro", "iPhone 15"]
for target_name in preferred:
    for rt in ios_runtimes:
        for dev in data.get(rt, []):
            if dev.get("isAvailable") and dev.get("name") == target_name:
                emit(dev, rt)

# 3. Fallback to any available non-SE iPhone, then any iPhone
for exclude_se in (True, False):
    for rt in ios_runtimes:
        for dev in data.get(rt, []):
            name = dev.get("name", "")
            if dev.get("isAvailable") and "iPhone" in name and (not exclude_se or "SE" not in name):
                emit(dev, rt)
PY

SIM_INFO="$(tr -d '\r\n' < "$SIM_INFO_FILE")"

if [[ -z "$SIM_INFO" ]]; then
  echo "[!] No available iPhone Simulator runtime found in Xcode."
  echo "    Install one via: xcodebuild -downloadPlatform iOS"
  exit 1
fi

IFS='|' read -r SIM_UDID SIM_NAME SIM_RUNTIME <<< "$SIM_INFO"
echo "[*] Selected Simulator: ${SIM_NAME} (${SIM_RUNTIME}, UDID=${SIM_UDID})"

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
DEV_DIR="$(xcode-select -p)"
DEVICE_HUB_APP="$(dirname "$DEV_DIR")/Applications/DeviceHub.app"
LEGACY_SIM_APP="$DEV_DIR/Applications/Simulator.app"
if [[ -d "$DEVICE_HUB_APP" ]]; then
  open "$DEVICE_HUB_APP" >/dev/null 2>&1 || open -b com.apple.dt.Devices >/dev/null 2>&1 || true
elif [[ -d "$LEGACY_SIM_APP" ]]; then
  open "$LEGACY_SIM_APP" --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || open -b com.apple.iphonesimulator >/dev/null 2>&1 || true
fi
xcrun simctl bootstatus "$SIM_UDID" -b
if [[ -d "$DEVICE_HUB_APP" ]]; then
  open "devices://device/open?id=${SIM_UDID}" >/dev/null 2>&1 || true
fi

echo ""
echo "=== [4/5] Compiling Antigravity.app & Running Real XCUITest UI Tap Suite (AntigravityUITests) ==="
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
mkdir -p verification/output/real-simulator
rm -rf verification/output/real-simulator/AntigravityUITests.xcresult

xcodebuild test \
  -project iOSAntigravity.xcodeproj \
  -scheme Antigravity \
  -sdk iphonesimulator \
  -destination "id=${SIM_UDID}" \
  -derivedDataPath "$DERIVED_DATA" \
  -only-testing:AntigravityUITests \
  -resultBundlePath "verification/output/real-simulator/AntigravityUITests.xcresult" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  AD_HOC_CODE_SIGNING_ALLOWED=YES
echo "[PASS] Real Simulator XCUITest UI Tap Suite (row tap -> detail -> project -> compose/send) passed on ${SIM_NAME}"

echo ""
echo "=== [5/5] Installing & Connecting Antigravity.app Live to Your Antigravity Desktop ==="
APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "Antigravity.app" | head -n 1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "[!] Built Antigravity.app bundle not found under $DERIVED_DATA/Build/Products/Debug-iphonesimulator"
  exit 1
fi
xcrun simctl install "$SIM_UDID" "$APP_PATH"
xcrun simctl terminate "$SIM_UDID" dev.antigravity.ios.app >/dev/null 2>&1 || true

SIMCTL_CHILD_NO_PROXY="127.0.0.1,localhost,::1" \
SIMCTL_CHILD_ANTIGRAVITY_BACKEND_URL="http://127.0.0.1:${BRIDGE_PORT}" \
SIMCTL_CHILD_ANTIGRAVITY_CSRF_TOKEN="$BRIDGE_CSRF" \
SIMCTL_CHILD_ANTIGRAVITY_HOST_NAME="$(scutil --get ComputerName 2>/dev/null || hostname)" \
  xcrun simctl launch "$SIM_UDID" dev.antigravity.ios.app

sleep 2.5
xcrun simctl io "$SIM_UDID" screenshot "verification/output/real-simulator/LIVE_CONNECTED_HOME.png"
echo "[PASS] Real Simulator screenshot saved to verification/output/real-simulator/LIVE_CONNECTED_HOME.png"
echo ""
echo "Simulator (${SIM_NAME}) is now running Antigravity.app connected to http://127.0.0.1:${BRIDGE_PORT}."
echo "Tap any conversation row or project group in the Simulator window to inspect live sessions!"
echo "Press Ctrl+C when finished interacting to stop the background Companion Bridge."
tail -n 6 -f /tmp/antigravity-bridge.log &
TAIL_PID=$!
wait "$BRIDGE_PID"
