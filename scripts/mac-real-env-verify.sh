#!/usr/bin/env bash
# ==============================================================================
# iOSAntigravity — Real macOS + Xcode + Antigravity Desktop E2E Verifier
# Run on your Mac:
#   bash scripts/mac-real-env-verify.sh
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

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
BRIDGE_PORT=8787
python3 scripts/mac-companion-bridge.py --port "$BRIDGE_PORT" --csrf "$BRIDGE_CSRF" >/tmp/antigravity-bridge.log 2>&1 &
BRIDGE_PID=$!
trap 'kill "$BRIDGE_PID" >/dev/null 2>&1 || true' EXIT
sleep 1.5

cat /tmp/antigravity-bridge.log
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

SIM_UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
for runtime in sorted(data.keys(), reverse=True):
    if "iOS" not in runtime: continue
    for dev in data[runtime]:
        if dev.get("isAvailable") and "iPhone" in dev.get("name", ""):
            print(dev["udid"])
            sys.exit(0)
')"

if [[ -z "$SIM_UDID" ]]; then
  echo "[!] No available iPhone Simulator found in Xcode."
  exit 1
fi

echo "[*] Selected iPhone Simulator UDID: $SIM_UDID"
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

SIMCTL_CHILD_ANTIGRAVITY_BACKEND_URL="http://127.0.0.1:${BRIDGE_PORT}" \
SIMCTL_CHILD_ANTIGRAVITY_CSRF_TOKEN="$BRIDGE_CSRF" \
SIMCTL_CHILD_ANTIGRAVITY_HOST_NAME="$(scutil --get ComputerName 2>/dev/null || hostname)" \
  xcrun simctl launch "$SIM_UDID" dev.antigravity.ios.app

sleep 2.5
mkdir -p verification/output/real-simulator
xcrun simctl io "$SIM_UDID" screenshot "verification/output/real-simulator/LIVE_CONNECTED_HOME.png"
echo "[PASS] Real Simulator screenshot saved to verification/output/real-simulator/LIVE_CONNECTED_HOME.png"
echo ""
echo "Simulator is now running Antigravity.app connected to http://127.0.0.1:${BRIDGE_PORT}."
echo "Press Ctrl+C when finished interacting to stop the background Companion Bridge."
wait "$BRIDGE_PID"
