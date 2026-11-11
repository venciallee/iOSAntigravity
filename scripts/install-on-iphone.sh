#!/usr/bin/env bash
# ==============================================================================
# iOSAntigravity — Build, Sign & Install on Physical iPhone + Start Live Bridge
# Usage on your Mac (with iPhone connected via USB or same Wi-Fi):
#   bash scripts/install-on-iphone.sh
# Optional overrides:
#   TEAM_ID=ABCDE12345 BUNDLE_PREFIX=com.yourname.antigravity bash scripts/install-on-iphone.sh
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "[*] Installing xcodegen via Homebrew..."
  brew install xcodegen
fi

xcodegen generate

# 1. Auto-detect Apple Development Team ID from local macOS Keychain if not set
WITH_BRIDGE=0
for arg in "$@"; do
  if [[ "$arg" == "--with-bridge" ]]; then
    WITH_BRIDGE=1
  fi
done

TEAM_ID="${TEAM_ID:-}"
if [[ -z "$TEAM_ID" ]]; then
  TEAM_ID="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*(\([A-Z0-9]\{10\}\)).*/\1/p' \
    | head -n 1 || true)"
fi

# Derive a unique per-Mac bundle prefix by default so Personal Team signing never hits global App ID collisions
USER_SLUG="$(id -un | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')"
BUNDLE_PREFIX="${BUNDLE_PREFIX:-com.${USER_SLUG:-local}.antigravity.ios}"

if [[ -z "$TEAM_ID" ]]; then
  echo "[!] No Apple Development signing certificate found in Keychain yet."
  echo "    Opening iOSAntigravity.xcodeproj in Xcode — sign in under Settings > Accounts,"
  echo "    select your Team on the 'Antigravity' target, pick your iPhone, and press Cmd+R!"
  open iOSAntigravity.xcodeproj
  if [[ "$WITH_BRIDGE" -eq 1 ]]; then
    exec python3 -u scripts/mac-companion-bridge.py
  fi
  exit 0
fi

echo "[*] Signing Team ID   : ${TEAM_ID}"
echo "[*] Bundle Prefix     : ${BUNDLE_PREFIX} (${BUNDLE_PREFIX}.app)"

# 2. Detect connected physical iPhone via xcrun devicectl / xctrace
IPHONE_INFO_FILE="$(mktemp "${TMPDIR:-/tmp}/agy-iphone.XXXXXX")"
trap 'rm -f "$IPHONE_INFO_FILE"' EXIT

xcrun devicectl list devices --json-output "$IPHONE_INFO_FILE" >/dev/null 2>&1 || true

DEVICE_LINE="$(python3 - "$IPHONE_INFO_FILE" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], "r", encoding="utf-8"))
except Exception:
    sys.exit(0)

for dev in data.get("result", {}).get("devices", []):
    hw = dev.get("hardwareProperties", {}) or {}
    conn = dev.get("connectionProperties", {}) or {}
    platform = hw.get("platform", "")
    pairing = conn.get("pairingState", "")
    tunnel = conn.get("tunnelState", "")
    if platform == "iOS" and pairing == "paired" and tunnel not in ("unavailable", "disconnected"):
        udid = hw.get("udid") or dev.get("identifier") or ""
        core_id = dev.get("identifier") or udid
        name = dev.get("deviceProperties", {}).get("name") or "iPhone"
        if udid:
            print("|".join([udid, core_id, name]))
            sys.exit(0)
PY
)"

if [[ -z "$DEVICE_LINE" ]]; then
  echo "[!] No unlocked/paired physical iPhone detected via devicectl."
  echo "    Connect & unlock your iPhone (enable Settings > Privacy & Security > Developer Mode),"
  echo "    or build directly in Xcode (opening project now)..."
  open iOSAntigravity.xcodeproj
  if [[ "$WITH_BRIDGE" -eq 1 ]]; then
    exec python3 -u scripts/mac-companion-bridge.py
  fi
  exit 0
fi

IFS='|' read -r DEVICE_UDID CORE_DEVICE_ID DEVICE_NAME <<< "$DEVICE_LINE"
echo "[+] Detected Physical iPhone: ${DEVICE_NAME} (UDID=${DEVICE_UDID})"

DERIVED_DATA="$ROOT_DIR/.build/DerivedDataDevice"
echo "[*] Building & signing Antigravity.app for ${DEVICE_NAME}..."
xcodebuild \
  -project iOSAntigravity.xcodeproj \
  -scheme Antigravity \
  -configuration Debug \
  -sdk iphoneos \
  -destination "id=${DEVICE_UDID}" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ANTIGRAVITY_BUNDLE_PREFIX="$BUNDLE_PREFIX" \
  -quiet \
  build

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphoneos" -maxdepth 1 -name "Antigravity.app" | head -n 1)"
echo "[*] Installing Antigravity.app onto ${DEVICE_NAME}..."
xcrun devicectl device install app --device "$CORE_DEVICE_ID" "$APP_PATH"
xcrun devicectl device process launch --device "$CORE_DEVICE_ID" "${BUNDLE_PREFIX}.app" || true

echo ""
echo "[PASS] Antigravity.app installed & launched on ${DEVICE_NAME}!"
echo "       1. In Antigravity Desktop on your Mac/PC, click 'Remote Control' to open the QR code."
echo "       2. On your iPhone -> Settings tab -> tap 'Scan Remote Control QR Code' and sign in with Google."
echo "       (No bridge script or Tailscale needed — works over Wi-Fi and 5G cellular!)"
if [[ "$WITH_BRIDGE" -eq 1 ]]; then
  echo ""
  echo "[*] Starting optional Mac Companion Bridge (--with-bridge)..."
  exec python3 -u scripts/mac-companion-bridge.py
fi
