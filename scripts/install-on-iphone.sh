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

WITH_BRIDGE=0
for arg in "$@"; do
  if [[ "$arg" == "--with-bridge" ]]; then
    WITH_BRIDGE=1
  fi
done

# 1. Detect connected physical iPhone FIRST (excluding Xcode 26/27 DeviceHub Simulators!)
IPHONE_INFO_FILE="$(mktemp "${TMPDIR:-/tmp}/agy-iphone.XXXXXX")"
SIM_LIST_FILE="$(mktemp "${TMPDIR:-/tmp}/agy-sims.XXXXXX")"
DEST_INFO_FILE="$(mktemp "${TMPDIR:-/tmp}/agy-dests.XXXXXX")"
SIGN_PLAN_FILE="$(mktemp "${TMPDIR:-/tmp}/agy-signplan.XXXXXX")"
SETTINGS_JSON_FILE=""
trap 'rm -f "$IPHONE_INFO_FILE" "$SIM_LIST_FILE" "$DEST_INFO_FILE" "$SIGN_PLAN_FILE" ${SETTINGS_JSON_FILE:+"$SETTINGS_JSON_FILE"}' EXIT

xcrun devicectl list devices --json-output "$IPHONE_INFO_FILE" >/dev/null 2>&1 || true
xcrun simctl list devices -j >"$SIM_LIST_FILE" 2>/dev/null || true

DEVICE_REPORT="$(python3 - "$IPHONE_INFO_FILE" "$SIM_LIST_FILE" <<'PY'
import json
import sys

devicectl_path, simctl_path = sys.argv[1], sys.argv[2]

sim_udids = set()
try:
    sim_data = json.load(open(simctl_path, "r", encoding="utf-8"))
    for runtime_devs in (sim_data.get("devices") or {}).values():
        for sdev in runtime_devs or []:
            u = str(sdev.get("udid") or "").strip().lower()
            if u:
                sim_udids.add(u)
except Exception:
    pass

try:
    data = json.load(open(devicectl_path, "r", encoding="utf-8"))
except Exception:
    sys.exit(0)

candidates = []
unavailable_notes = []

for dev in data.get("result", {}).get("devices", []):
    hw = dev.get("hardwareProperties") or {}
    conn = dev.get("connectionProperties") or {}
    props = dev.get("deviceProperties") or {}

    platform = str(hw.get("platform") or "")
    reality = str(hw.get("reality") or "").strip().lower()
    udid = str(hw.get("udid") or dev.get("identifier") or "").strip()
    core_id = str(dev.get("identifier") or udid).strip()
    transport = str(conn.get("transportType") or "").strip().lower()
    pairing = str(conn.get("pairingState") or "").strip().lower()
    tunnel = str(conn.get("tunnelState") or "").strip().lower()
    name = str(props.get("name") or "iPhone").strip()

    # Strictly exclude Xcode 26/27 DeviceHub Simulators (`reality == "simulated"` or present in `simctl`)
    if reality and reality != "physical":
        continue
    if udid.lower() in sim_udids or core_id.lower() in sim_udids:
        continue
    if transport in ("local", "simulated", "simulator"):
        continue
    if platform != "iOS" or not udid:
        continue

    dev_type = str(hw.get("deviceType") or hw.get("productType") or "")
    is_iphone = ("iphone" in dev_type.lower()) or ("iphone" in name.lower())

    # Note: In CoreDevice (`devicectl`), an idle USB/Wi-Fi connected physical iPhone (`available (paired)`)
    # reports `tunnelState == "disconnected"` until devicectl/xcodebuild opens the DDI tunnel on demand.
    # Only `tunnelState == "unavailable"` means the device is offline / unplugged.
    is_reachable = (pairing == "paired" and tunnel not in ("unavailable", ""))
    if is_reachable:
        is_wired = transport in ("wired", "usb")
        prio = (
            0 if is_iphone else 1,
            0 if is_wired else 1,
            0 if tunnel == "connected" else 1,
        )
        candidates.append((prio, udid, core_id, name, transport or tunnel))
    else:
        unavailable_notes.append(f"{name} (pairing={pairing or 'unknown'}, tunnel={tunnel or 'unknown'}, transport={transport or 'none'})")

if candidates:
    candidates.sort(key=lambda item: item[0])
    _, udid, core_id, name, via = candidates[0]
    print(f"READY|{udid}|{core_id}|{name}|{via}")
elif unavailable_notes:
    print("UNAVAILABLE|" + "; ".join(unavailable_notes))
PY
)"

DEVICE_LINE=""
if [[ "$DEVICE_REPORT" == READY\|* ]]; then
  DEVICE_LINE="${DEVICE_REPORT#READY|}"
fi

# 2. Build ordered list of Signing Plans: (TEAM_ID, BUNDLE_PREFIX, REASON)
#    - Avoids shared corporate username collisions (e.g. `id -un == bytedance` -> `com.bytedance.*` rejected by Personal Team)
#    - Reuses cached unexpired wildcard/exact `.mobileprovision` profiles covering DEVICE_UDID (works even offline!)
#    - Tries all unlocked `Apple Development` / `iPhone Developer` identities in Keychain (active teams with valid profiles first)
PROBE_UDID=""
if [[ -n "$DEVICE_LINE" ]]; then
  IFS='|' read -r PROBE_UDID _ _ _ <<< "$DEVICE_LINE"
fi

python3 - "$PROBE_UDID" "${TEAM_ID:-}" "${BUNDLE_PREFIX:-}" >"$SIGN_PLAN_FILE" <<'PY'
from datetime import datetime, timezone
import hashlib
import os
import plistlib
import re
import socket
import subprocess
import sys
from pathlib import Path

device_udid, env_team, env_prefix = sys.argv[1].strip(), sys.argv[2].strip(), sys.argv[3].strip()

# Derive a deterministic per-Mac unique prefix (`io.agy.dev<8hex>`) that never collides with corporate namespaces
hw_seed = ""
try:
    ioreg_out = subprocess.check_output(
        ["ioreg", "-rd1", "-c", "IOPlatformExpertDevice"],
        text=True,
        stderr=subprocess.DEVNULL,
    )
    m = re.search(r'"IOPlatformUUID"\s*=\s*"([^"]+)"', ioreg_out)
    if m:
        hw_seed = m.group(1)
except Exception:
    pass
if not hw_seed:
    hw_seed = f"{socket.gethostname()}:{os.path.expanduser('~')}"

mac_hash = hashlib.sha256(hw_seed.encode("utf-8")).hexdigest()[:8]
default_prefix = env_prefix or f"io.agy.dev{mac_hash}"

if env_team and env_prefix:
    print(f"{env_team}|{env_prefix}|explicit TEAM_ID & BUNDLE_PREFIX")
    sys.exit(0)

# Enumerate unlocked codesigning Team IDs from Keychain (Apple Development / iPhone Developer first)
dev_teams = []
other_teams = []
try:
    sec_out = subprocess.check_output(
        ["security", "find-identity", "-v", "-p", "codesigning"],
        text=True,
        stderr=subprocess.DEVNULL,
    )
    for line in sec_out.splitlines():
        m = re.search(r'"([^"]*\(([A-Z0-9]{10})\))"', line)
        if not m:
            continue
        label, tid = m.group(1), m.group(2)
        if env_team and tid != env_team:
            continue
        is_dev = ("Apple Development" in label) or ("iPhone Developer" in label)
        target_list = dev_teams if is_dev else other_teams
        if tid not in dev_teams and tid not in other_teams:
            target_list.append(tid)
except Exception:
    pass

all_teams = [env_team] if (env_team and env_team not in dev_teams + other_teams) else (dev_teams + other_teams)
if not all_teams:
    sys.exit(0)

# Inspect local cached Provisioning Profiles (Xcode 16/26/27 UserData + Legacy MobileDevice)
profile_dirs = [
    Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
    Path.home() / "Library/MobileDevice/Provisioning Profiles",
]
now_utc = datetime.now(timezone.utc).replace(tzinfo=None)
team_active_profile_count = {t: 0 for t in all_teams}
exact_prefixes_by_team = {}  # (team, prefix) -> set of matched suffixes (.app, .app.LiveActivity, .app.Share)
wildcard_plans = []

for pdir in profile_dirs:
    if not pdir.is_dir():
        continue
    for mp in list(pdir.glob("*.mobileprovision")) + list(pdir.glob("*.provisionprofile")):
        try:
            raw = mp.read_bytes()
            s = raw.find(b"<?xml")
            e = raw.find(b"</plist>")
            if s < 0 or e <= s:
                continue
            pl = plistlib.loads(raw[s : e + len(b"</plist>")])
        except Exception:
            continue

        exp = pl.get("ExpirationDate")
        if isinstance(exp, datetime):
            exp_naive = exp.astimezone(timezone.utc).replace(tzinfo=None) if exp.tzinfo else exp
            if exp_naive <= now_utc:
                continue

        tids = pl.get("TeamIdentifier") or []
        tid = str(tids[0]).strip() if tids else ""
        if tid not in all_teams:
            continue

        ent = pl.get("Entitlements") or {}
        # Only Development profiles (`get-task-allow == True`) can sign Debug iphoneos builds
        if ent.get("get-task-allow") is not True:
            continue

        team_active_profile_count[tid] = team_active_profile_count.get(tid, 0) + 1

        prov_devs = [str(d).strip().lower() for d in (pl.get("ProvisionedDevices") or [])]
        if device_udid and device_udid.lower() not in prov_devs:
            continue

        app_id = str(ent.get("application-identifier") or "")
        if not app_id.startswith(f"{tid}."):
            continue
        pattern = app_id[len(tid) + 1 :]

        if pattern == "*":
            cand_prefix = env_prefix or default_prefix
            wildcard_plans.append((0, tid, cand_prefix, "cached '*' wildcard profile"))
        elif pattern.endswith(".*"):
            ns = pattern[:-2]
            if not env_prefix:
                cand_prefix = f"{ns}.agy{mac_hash[:6]}"
                wildcard_plans.append((1, tid, cand_prefix, f"cached '{ns}.*' wildcard profile"))
            elif env_prefix.startswith(ns + "."):
                wildcard_plans.append((1, tid, env_prefix, f"cached '{ns}.*' wildcard profile"))
        else:
            for suffix in (".app.LiveActivity", ".app.Share", ".app"):
                if pattern.endswith(suffix):
                    base_p = pattern[: -len(suffix)]
                    if not env_prefix or env_prefix == base_p:
                        exact_prefixes_by_team.setdefault((tid, base_p), set()).add(suffix)
                    break

plans = []
seen = set()

def add_plan(t: str, p: str, reason: str):
    if (t, p) not in seen:
        seen.add((t, p))
        plans.append((t, p, reason))

# 1. Exact cached profile triples covering all 3 targets (.app + .LiveActivity + .Share)
for (tid, base_p), suffixes in exact_prefixes_by_team.items():
    if {".app", ".app.LiveActivity", ".app.Share"}.issubset(suffixes):
        add_plan(tid, base_p, "cached exact provisioning profiles")

# 2. Cached wildcard profiles covering DEVICE_UDID (works 100% offline without Xcode account login!)
wildcard_plans.sort(key=lambda item: item[0])
for _, tid, cand_p, reason in wildcard_plans:
    add_plan(tid, cand_p, reason)

# 3. Automatic signing across all unlocked Development teams (prioritize teams with active local profiles)
sorted_teams = sorted(
    all_teams,
    key=lambda t: (0 if t in dev_teams else 1, -team_active_profile_count.get(t, 0)),
)
for tid in sorted_teams:
    add_plan(tid, default_prefix, "Xcode Automatic Signing")

for tid, cand_p, reason in plans:
    print(f"{tid}|{cand_p}|{reason}")
PY

apply_xcodeproj_signing_defaults() {
  local target_team="$1"
  local target_prefix="$2"
  python3 - "$ROOT_DIR/iOSAntigravity.xcodeproj/project.pbxproj" "$target_team" "$target_prefix" <<'PY'
import re
import sys
from pathlib import Path

pbx_path, team_id, bundle_prefix = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
if not pbx_path.is_file():
    sys.exit(0)

txt = pbx_path.read_text(encoding="utf-8")
if bundle_prefix:
    txt = re.sub(r"ANTIGRAVITY_BUNDLE_PREFIX = [^;]+;", f"ANTIGRAVITY_BUNDLE_PREFIX = {bundle_prefix};", txt)
if team_id:
    if "DEVELOPMENT_TEAM =" in txt:
        txt = re.sub(r"DEVELOPMENT_TEAM = [^;]*;", f"DEVELOPMENT_TEAM = {team_id};", txt)
    else:
        txt = txt.replace(
            "CODE_SIGN_STYLE = Automatic;",
            f"CODE_SIGN_STYLE = Automatic;\n\t\t\t\tDEVELOPMENT_TEAM = {team_id};",
        )
pbx_path.write_text(txt, encoding="utf-8")
PY
}

FIRST_PLAN="$(head -n 1 "$SIGN_PLAN_FILE" || true)"
if [[ -z "$FIRST_PLAN" ]]; then
  echo "[!] No Apple Development signing certificate found in Keychain yet."
  echo "    Opening iOSAntigravity.xcodeproj in Xcode — sign in under Xcode > Settings (Cmd+,) > Accounts,"
  echo "    select your Team on the 'Antigravity' target, pick your iPhone, and press Cmd+R!"
  open iOSAntigravity.xcodeproj
  if [[ "$WITH_BRIDGE" -eq 1 ]]; then
    exec python3 -u scripts/mac-companion-bridge.py
  fi
  exit 0
fi

IFS='|' read -r TEAM_ID BUNDLE_PREFIX _ <<< "$FIRST_PLAN"
apply_xcodeproj_signing_defaults "$TEAM_ID" "$BUNDLE_PREFIX"

if [[ -z "$DEVICE_LINE" ]]; then
  echo "[!] No reachable paired physical iPhone detected."
  if [[ "$DEVICE_REPORT" == UNAVAILABLE\|* ]]; then
    echo "    Seen offline/unpaired iOS hardware: ${DEVICE_REPORT#UNAVAILABLE|}"
  fi
  xcodebuild -project iOSAntigravity.xcodeproj -scheme Antigravity -showdestinations >"$DEST_INFO_FILE" 2>&1 || true
  grep -E "platform:iOS[, }]" "$DEST_INFO_FILE" | grep -v "DVTiPhonePlaceholder" | sed 's/^/    Xcode destination: /' || true
  echo ""
  echo "    Please plug in & unlock your physical iPhone (trust this Mac + enable Settings > Privacy & Security > Developer Mode),"
  echo "    then re-run 'bash scripts/install-on-iphone.sh', or select your iPhone in Xcode (opening project now)..."
  open iOSAntigravity.xcodeproj
  if [[ "$WITH_BRIDGE" -eq 1 ]]; then
    exec python3 -u scripts/mac-companion-bridge.py
  fi
  exit 0
fi

IFS='|' read -r DEVICE_UDID CORE_DEVICE_ID DEVICE_NAME DEVICE_VIA <<< "$DEVICE_LINE"
echo "[+] Detected Physical iPhone: ${DEVICE_NAME} (UDID=${DEVICE_UDID}, via=${DEVICE_VIA})"

mkdir -p "$ROOT_DIR/.build"
DERIVED_DATA="$ROOT_DIR/.build/DerivedDataDevice"
BUILD_LOG="$ROOT_DIR/.build/xcodebuild-device.log"

: >"$BUILD_LOG"
BUILD_SUCCEEDED=0
while IFS='|' read -r -u 3 CAND_TEAM CAND_PREFIX CAND_REASON; do
  [[ -z "$CAND_TEAM" ]] && continue
  TEAM_ID="$CAND_TEAM"
  BUNDLE_PREFIX="$CAND_PREFIX"
  apply_xcodeproj_signing_defaults "$TEAM_ID" "$BUNDLE_PREFIX"
  echo "[*] Trying Team ${TEAM_ID} · Bundle ${BUNDLE_PREFIX}.app (${CAND_REASON})..."

  if xcodebuild \
    -project iOSAntigravity.xcodeproj \
    -scheme Antigravity \
    -configuration Debug \
    -sdk iphoneos \
    -destination "platform=iOS,id=${DEVICE_UDID}" \
    -derivedDataPath "$DERIVED_DATA" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    ANTIGRAVITY_BUNDLE_PREFIX="$BUNDLE_PREFIX" \
    build </dev/null >>"$BUILD_LOG" 2>&1; then
    BUILD_SUCCEEDED=1
    break
  else
    echo "    [x] Signing/build attempt with Team ${TEAM_ID} (${BUNDLE_PREFIX}.app) did not succeed."
  fi
done 3< "$SIGN_PLAN_FILE"

if [[ "$BUILD_SUCCEEDED" -ne 1 ]]; then
  echo ""
  EXPIRED_ACCOUNT="$(sed -n "s/.*Unable to log in with account '\([^']*\)'.*/\1/p" "$BUILD_LOG" | head -n 1 || true)"
  if [[ -n "$EXPIRED_ACCOUNT" ]]; then
    echo "[!] Xcode Apple ID 登录会话已过期 (${EXPIRED_ACCOUNT})，无法自动向 Apple 申请真机描述文件。"
    echo "    工程已自动预填唯一 Bundle ID (${BUNDLE_PREFIX}.app) 与 Team (${TEAM_ID})，只需两步即可恢复："
    echo "      1. 在即将弹出的 Xcode 中按 Cmd + , 打开 Settings -> Accounts"
    echo "      2. 选中 '${EXPIRED_ACCOUNT}'，点击 'Sign In Again' 重新输入 Apple ID 密码完成登录"
    echo "      3. 重新执行: bash scripts/install-on-iphone.sh （或直接在 Xcode 顶部选中 ${DEVICE_NAME} 按 Cmd + R）"
    open iOSAntigravity.xcodeproj
    exit 1
  fi

  echo "[!] xcodebuild failed for physical iPhone (${DEVICE_NAME}). Key errors:"
  grep -E "error:|warning:.*Provisioning|No profiles|Developer Mode" "$BUILD_LOG" | tail -n 30 || true
  echo "    --- Tail of $BUILD_LOG ---"
  tail -n 50 "$BUILD_LOG" || true
  exit 1
fi

# Resolve actual Antigravity.app output location (handles Xcode Custom/Legacy Build Locations & Xcode 27 layouts)
SETTINGS_JSON_FILE="$(mktemp "${TMPDIR:-/tmp}/agy-buildsettings.XXXXXX")"
if ! xcodebuild \
  -project iOSAntigravity.xcodeproj \
  -scheme Antigravity \
  -configuration Debug \
  -sdk iphoneos \
  -destination "platform=iOS,id=${DEVICE_UDID}" \
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
    -destination "generic/platform=iOS" \
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
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "[!] Could not locate built iphoneos Antigravity.app bundle after xcodebuild succeeded."
  grep -E '"(CODESIGNING_FOLDER_PATH|TARGET_BUILD_DIR|EFFECTIVE_PLATFORM_NAME)"' "$SETTINGS_JSON_FILE" | head -n 12 || true
  if [[ -d "$DERIVED_DATA" ]]; then
    echo "    App bundles currently inside $DERIVED_DATA:"
    find "$DERIVED_DATA" -maxdepth 5 -name "*.app" 2>/dev/null || true
  fi
  echo "    Last lines of $BUILD_LOG:"
  tail -n 50 "$BUILD_LOG" || true
  exit 1
fi
rm -f "$SETTINGS_JSON_FILE"

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
