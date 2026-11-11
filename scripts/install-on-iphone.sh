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

candidates = []
for dev in data.get("result", {}).get("devices", []):
    hw = dev.get("hardwareProperties", {}) or {}
    conn = dev.get("connectionProperties", {}) or {}
    props = dev.get("deviceProperties", {}) or {}
    platform = hw.get("platform", "")
    pairing = conn.get("pairingState", "")
    tunnel = conn.get("tunnelState", "")
    if platform == "iOS" and pairing == "paired" and tunnel not in ("unavailable", "disconnected"):
        udid = hw.get("udid") or dev.get("identifier") or ""
        core_id = dev.get("identifier") or udid
        name = props.get("name") or "iPhone"
        dev_type = hw.get("deviceType", "") or hw.get("productType", "")
        is_iphone = ("iphone" in dev_type.lower()) or ("iphone" in name.lower())
        if udid:
            candidates.append((0 if is_iphone else 1, udid, core_id, name))

if candidates:
    candidates.sort(key=lambda item: item[0])
    _, udid, core_id, name = candidates[0]
    print("|".join([udid, core_id, name]))
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

mkdir -p "$ROOT_DIR/.build"
DERIVED_DATA="$ROOT_DIR/.build/DerivedDataDevice"
BUILD_LOG="$ROOT_DIR/.build/xcodebuild-device.log"

echo "[*] Building & signing Antigravity.app for ${DEVICE_NAME}..."
if ! xcodebuild \
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
  build >"$BUILD_LOG" 2>&1; then
  echo "[!] xcodebuild failed. Build output:"
  tail -n 80 "$BUILD_LOG" || true
  exit 1
fi

# Resolve actual Antigravity.app output location (handles Xcode Custom/Legacy Build Locations & Xcode 27 layouts)
SETTINGS_JSON_FILE="$(mktemp "${TMPDIR:-/tmp}/agy-buildsettings.XXXXXX")"
if ! xcodebuild \
  -project iOSAntigravity.xcodeproj \
  -scheme Antigravity \
  -configuration Debug \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED_DATA" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ANTIGRAVITY_BUNDLE_PREFIX="$BUNDLE_PREFIX" \
  -showBuildSettings \
  -json >"$SETTINGS_JSON_FILE" 2>/dev/null; then
  xcodebuild \
    -project iOSAntigravity.xcodeproj \
    -scheme Antigravity \
    -configuration Debug \
    -sdk iphoneos \
    -destination "id=${DEVICE_UDID}" \
    -derivedDataPath "$DERIVED_DATA" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    ANTIGRAVITY_BUNDLE_PREFIX="$BUNDLE_PREFIX" \
    -showBuildSettings \
    -json >"$SETTINGS_JSON_FILE" 2>/dev/null || true
fi

APP_PATH="$(python3 - "$SETTINGS_JSON_FILE" "$DERIVED_DATA" "$ROOT_DIR" <<'PY'
import json
import os
import plistlib
import sys
from pathlib import Path

settings_path, derived_data, root_dir = sys.argv[1], sys.argv[2], sys.argv[3]

def is_iphoneos_app(app_dir: str) -> bool:
    if not app_dir or not os.path.isdir(app_dir):
        return False
    info_plist = os.path.join(app_dir, "Info.plist")
    if not os.path.isfile(info_plist):
        return False
    try:
        with open(info_plist, "rb") as fp:
            pl = plistlib.load(fp)
        platform_name = str(pl.get("DTPlatformName", "")).lower()
        if platform_name and platform_name != "iphoneos":
            return False
        return True
    except Exception:
        return True

# 1. Exact path reported by xcodebuild -showBuildSettings -json
try:
    raw = Path(settings_path).read_text(encoding="utf-8", errors="ignore")
    bracket_idx = raw.find("[")
    if bracket_idx >= 0:
        entries = json.loads(raw[bracket_idx:])
        for entry in entries:
            bs = entry.get("buildSettings") or {}
            target = entry.get("target", "")
            wrapper = bs.get("WRAPPER_NAME") or bs.get("FULL_PRODUCT_NAME") or "Antigravity.app"
            product_type = bs.get("PRODUCT_TYPE", "")
            if target == "Antigravity" or (product_type == "com.apple.product-type.application" and wrapper == "Antigravity.app"):
                for cand in (
                    bs.get("CODESIGNING_FOLDER_PATH"),
                    os.path.join(bs.get("TARGET_BUILD_DIR", ""), wrapper) if bs.get("TARGET_BUILD_DIR") else None,
                    os.path.join(bs.get("BUILT_PRODUCTS_DIR", ""), wrapper) if bs.get("BUILT_PRODUCTS_DIR") else None,
                ):
                    if cand and cand.endswith(".app") and is_iphoneos_app(cand):
                        print(cand)
                        sys.exit(0)
except Exception:
    pass

# 2. Fallback: scan DerivedData, project build dirs, and Xcode custom build locations
search_roots = [
    (os.path.join(derived_data, "Build", "Products"), False),
    (derived_data, False),
    (os.path.join(root_dir, "Build", "Products"), False),
    (os.path.join(root_dir, "build"), False),
]
xcode_prefs = os.path.expanduser("~/Library/Preferences/com.apple.dt.Xcode.plist")
if os.path.isfile(xcode_prefs):
    try:
        with open(xcode_prefs, "rb") as fp:
            prefs = plistlib.load(fp)
        for key in ("IDECustomBuildProductsPath", "IDECustomDerivedDataLocation"):
            val = prefs.get(key)
            if isinstance(val, str) and val.strip():
                expanded = os.path.expanduser(val.strip())
                if not os.path.isabs(expanded):
                    expanded = os.path.join(root_dir, expanded)
                search_roots.append((expanded, key == "IDECustomDerivedDataLocation"))
    except Exception:
        pass
search_roots.append((os.path.expanduser("~/Library/Developer/Xcode/DerivedData"), True))

found = []
seen = set()
for root, filter_project_prefix in search_roots:
    if not os.path.isdir(root):
        continue
    direct = os.path.join(root, "Debug-iphoneos", "Antigravity.app")
    if direct not in seen and is_iphoneos_app(direct):
        seen.add(direct)
        found.append((os.path.getmtime(direct), direct))
    for dirpath, dirnames, _ in os.walk(root):
        if filter_project_prefix and os.path.abspath(dirpath) == os.path.abspath(root):
            dirnames[:] = [
                d for d in dirnames
                if d.lower().startswith("iosantigravity") or d in ("Build", "Products", "Debug-iphoneos")
            ]
        else:
            dirnames[:] = [
                d for d in dirnames
                if d not in ("Intermediates.noindex", "Index.noindex", "SourcePackages", "Logs", ".git")
                and not d.endswith(".xctest")
                and not d.endswith(".appex")
            ]
        if "Antigravity.app" in dirnames:
            cand = os.path.join(dirpath, "Antigravity.app")
            dirnames.remove("Antigravity.app")
            if cand not in seen and is_iphoneos_app(cand):
                seen.add(cand)
                found.append((os.path.getmtime(cand), cand))

if found:
    found.sort(key=lambda item: item[0], reverse=True)
    print(found[0][1])
PY
)"
rm -f "$SETTINGS_JSON_FILE"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "[!] Could not locate built Antigravity.app bundle after xcodebuild succeeded."
  echo "    Last lines of $BUILD_LOG:"
  tail -n 40 "$BUILD_LOG" || true
  exit 1
fi

ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || echo "${BUNDLE_PREFIX}.app")"
echo "[+] Built app bundle  : ${APP_PATH} (${ACTUAL_BUNDLE_ID})"
echo "[*] Installing Antigravity.app onto ${DEVICE_NAME}..."
xcrun devicectl device install app --device "$CORE_DEVICE_ID" "$APP_PATH"
if ! xcrun devicectl device process launch --device "$CORE_DEVICE_ID" "$ACTUAL_BUNDLE_ID" >/dev/null 2>&1; then
  echo "[!] Installed on ${DEVICE_NAME}! If launch was blocked by iOS first-time signing trust:"
  echo "    On iPhone, open Settings > General > VPN & Device Management -> trust your Apple ID certificate, then tap Antigravity."
fi

echo ""
echo "[PASS] Antigravity.app installed on ${DEVICE_NAME}!"
echo "       1. In Antigravity Desktop on your Mac/PC, click 'Remote Control' to open the QR code."
echo "       2. On your iPhone -> Settings tab -> tap 'Scan Remote Control QR Code' and sign in with Google."
echo "       (No bridge script or Tailscale needed — works over Wi-Fi and 5G cellular!)"
if [[ "$WITH_BRIDGE" -eq 1 ]]; then
  echo ""
  echo "[*] Starting optional Mac Companion Bridge (--with-bridge)..."
  exec python3 -u scripts/mac-companion-bridge.py
fi
