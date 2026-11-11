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

echo "=== [1/4] Swift 6 Package Compilation & XCTest Suite (AntigravityData) ==="
swift --version
swift test --package-path Packages/AntigravityData

echo ""
echo "=== [2/4] Live Antigravity Desktop Companion Bridge & Connect-RPC Handshake ==="
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

python3 verification/verify-live-rpc-flow.py --url "http://127.0.0.1:${BRIDGE_PORT}" --csrf "$BRIDGE_CSRF"

echo ""
echo "=== [3/4] Generating Xcode Project & Building Antigravity.app (Simulator) ==="
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

SIM_INFO="$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys

data = json.load(sys.stdin).get("devices", {})

def runtime_sort_key(rt: str):
    nums = [int(x) for x in re.findall(r"\d+", rt)]
    return tuple(nums) if nums else (0,)

ios_runtimes = sorted(
    [rt for rt in data.keys() if "iOS" in rt],
    key=runtime_sort_key,
    reverse=True,
)

# 1. Prefer an already Booted iPhone Simulator first (instant attach)
for rt in ios_runtimes:
    for dev in data.get(rt, []):
        if dev.get("isAvailable") and dev.get("state") == "Booted" and "iPhone" in dev.get("name", ""):
            print(f"{dev[\"udid\"]}|{dev[\"name\"]}|{rt}")
            sys.exit(0)

# 2. Prefer modern Pro / standard iPhone models on newest iOS runtime
preferred = ["iPhone 17 Pro", "iPhone 16 Pro", "iPhone 17", "iPhone 16", "iPhone 15 Pro", "iPhone 15"]
for target_name in preferred:
    for rt in ios_runtimes:
        for dev in data.get(rt, []):
            if dev.get("isAvailable") and dev.get("name") == target_name:
                print(f"{dev[\"udid\"]}|{dev[\"name\"]}|{rt}")
                sys.exit(0)

# 3. Fallback to any available non-SE iPhone, then any iPhone
for exclude_se in (True, False):
    for rt in ios_runtimes:
        for dev in data.get(rt, []):
            name = dev.get("name", "")
            if dev.get("isAvailable") and "iPhone" in name and (not exclude_se or "SE" not in name):
                print(f"{dev[\"udid\"]}|{name}|{rt}")
                sys.exit(0)
')"

if [[ -z "$SIM_INFO" ]]; then
  echo "[!] No available iPhone Simulator runtime found in Xcode."
  echo "    Install one via: xcodebuild -downloadPlatform iOS"
  exit 1
fi

IFS='|' read -r SIM_UDID SIM_NAME SIM_RUNTIME <<< "$SIM_INFO"
echo "[*] Selected Simulator: ${SIM_NAME} (${SIM_RUNTIME}, UDID=${SIM_UDID})"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"

xcodebuild \
  -project iOSAntigravity.xcodeproj \
  -scheme Antigravity \
  -sdk iphonesimulator \
  -destination "id=${SIM_UDID}" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo ""
echo "=== [4/4] Booting Simulator, Installing Antigravity.app & Connecting Live ==="
xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator || true
xcrun simctl bootstatus "$SIM_UDID" -b

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "Antigravity.app" | head -n 1)"
xcrun simctl install "$SIM_UDID" "$APP_PATH"
xcrun simctl terminate "$SIM_UDID" dev.antigravity.ios.app >/dev/null 2>&1 || true

SIMCTL_CHILD_NO_PROXY="127.0.0.1,localhost,::1" \
SIMCTL_CHILD_ANTIGRAVITY_BACKEND_URL="http://127.0.0.1:${BRIDGE_PORT}" \
SIMCTL_CHILD_ANTIGRAVITY_CSRF_TOKEN="$BRIDGE_CSRF" \
SIMCTL_CHILD_ANTIGRAVITY_HOST_NAME="$(scutil --get ComputerName 2>/dev/null || hostname)" \
  xcrun simctl launch "$SIM_UDID" dev.antigravity.ios.app

sleep 2.5
mkdir -p verification/output/real-simulator
xcrun simctl io "$SIM_UDID" screenshot "verification/output/real-simulator/LIVE_CONNECTED_HOME.png"
echo "[PASS] Real Simulator screenshot saved to verification/output/real-simulator/LIVE_CONNECTED_HOME.png"
echo ""
echo "Simulator (${SIM_NAME}) is now running Antigravity.app connected to http://127.0.0.1:${BRIDGE_PORT}."
echo "Press Ctrl+C when finished interacting to stop the background Companion Bridge."
wait "$BRIDGE_PID"
