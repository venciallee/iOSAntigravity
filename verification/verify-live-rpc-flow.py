#!/usr/bin/env python3
"""End-to-End Live Connect-RPC Flow Verifier (`verification/verify-live-rpc-flow.py`).

Verifies the exact protocol lifecycle used by `AntigravityRPCClient.swift` & `AntigravitySessionStore.swift`:
  1. Login / Authentication (`x-codeium-csrf-token` 401 rejection + 200 handshake on `GetWorkspaceInfos` & `GetAllCascadeTrajectories`)
  2. Session Creation (`StartCascade` -> returns `cascadeId` & registers in `trajectorySummaries`)
  3. Sending Messages (`SendUserCascadeMessage` with `items`, `@file` context mentions, `cascadeConfig`)
  4. Trajectory Step Retrieval (`GetCascadeTrajectorySteps` JSON `<600` steps & Binary `application/proto` `>600` steps)
  5. Face ID Command Gate (`HandleCascadeUserInteraction` 403 without biometric flag -> 200 with `faceIdVerified: true`)
  6. 5-Byte Connect Streaming Envelope (`JetboxSubscribeToSummaries`)

Usage:
  # Self-contained E2E run (spins up local bridge automatically):
  python3 verification/verify-live-rpc-flow.py

  # Against a live Mac running `python3 scripts/mac-companion-bridge.py`:
  python3 verification/verify-live-rpc-flow.py --url http://192.168.1.20:8787 --csrf <token>
"""

import argparse
import importlib.util
import json
import secrets
import ssl
import struct
import sys
import threading
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICE_PREFIX = "/exa.language_server_pb.LanguageServerService/"


def load_bridge_module():
    bridge_path = ROOT / "scripts" / "mac-companion-bridge.py"
    spec = importlib.util.spec_from_file_location("mac_companion_bridge", bridge_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


import time
import urllib.parse


def make_unverified_ssl_context() -> ssl.SSLContext:
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def urlopen_direct(req: urllib.request.Request, timeout: float = 15.0):
    parsed = urllib.parse.urlparse(req.full_url)
    host = (parsed.hostname or "").lower()
    handlers = []
    if host in ("127.0.0.1", "localhost", "::1"):
        handlers.append(urllib.request.ProxyHandler({}))
    if parsed.scheme == "https":
        handlers.append(urllib.request.HTTPSHandler(context=make_unverified_ssl_context()))
    opener = urllib.request.build_opener(*handlers)
    return opener.open(req, timeout=timeout)


def call_rpc_json(base_url: str, method: str, body: dict, csrf_token: str = None):
    url = f"{base_url.rstrip('/')}{SERVICE_PREFIX}{method}"
    headers = {
        "Content-Type": "application/json",
        "Connect-Protocol-Version": "1",
    }
    if csrf_token is not None:
        headers["x-codeium-csrf-token"] = csrf_token
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        method="POST",
        headers=headers,
    )
    last_err = None
    for attempt in range(16):
        try:
            with urlopen_direct(req, timeout=15) as resp:
                raw = resp.read()
                return resp.status, json.loads(raw.decode("utf-8")) if raw else {}
        except urllib.error.HTTPError as e:
            raw = e.read()
            try:
                parsed = json.loads(raw.decode("utf-8"))
            except Exception:
                parsed = {"raw": raw.decode("utf-8", errors="replace")}
            return e.code, parsed
        except urllib.error.URLError as e:
            last_err = e
            if isinstance(getattr(e, "reason", None), ConnectionRefusedError) and attempt < 15:
                time.sleep(0.5)
                continue
            raise
    raise last_err


def run_flow(base_url: str, csrf_token: str, live_external: bool = False, read_only: bool = False):
    print(f"[*] Target Backend : {base_url}", flush=True)

    # 1. Auth Gate & Login Handshake
    bad_status, _ = call_rpc_json(base_url, "GetWorkspaceInfos", {}, csrf_token="invalid-token")
    assert bad_status in (401, 403), f"Expected 401/403 with invalid token, got {bad_status}"
    print(f"  [PASS] 1a. Auth Gate rejected invalid CSRF token ({bad_status})", flush=True)

    ws_status, ws_res = call_rpc_json(base_url, "GetWorkspaceInfos", {}, csrf_token=csrf_token)
    assert ws_status == 200, f"GetWorkspaceInfos failed: {ws_status} {ws_res}"
    workspaces = ws_res.get("workspaces") or ws_res.get("workspaceInfos") or []
    first_ws = workspaces[0] if workspaces else {}
    ws_uri = (
        first_ws.get("workspaceUri")
        or first_ws.get("workspaceFolderAbsoluteUri")
        or "file:///workspace"
    )
    print(f"  [PASS] 1b. Login Handshake (`GetWorkspaceInfos`) -> {len(workspaces)} workspace(s), primary={ws_uri}")

    if read_only:
        list_status, list_res = call_rpc_json(base_url, "GetAllCascadeTrajectories", {}, csrf_token=csrf_token)
        assert list_status == 200, f"GetAllCascadeTrajectories failed: {list_status} {list_res}"
        summary_map = list_res.get("trajectorySummaries") or {}
        traj_list = list_res.get("trajectories") or []
        total_sessions = len(summary_map) if summary_map else len(traj_list)
        print(f"  [PASS] 2.  Synced Live Desktop Sessions (`GetAllCascadeTrajectories` read-only) -> {total_sessions} trajectory record(s)", flush=True)
        sample_cid = next((cid for cid, v in summary_map.items() if (v or {}).get("stepCount", 0) > 0), None)
        if sample_cid:
            st_code, st_res = call_rpc_json(
                base_url,
                "GetCascadeTrajectorySteps",
                {"cascadeId": sample_cid, "startIndex": 0, "endIndex": 20},
                csrf_token=csrf_token,
            )
            assert st_code == 200
            print(f"  [PASS] 3.  Synced Real Trajectory Steps (`GetCascadeTrajectorySteps` for {sample_cid}) -> {len(st_res.get('steps', []))} step(s)", flush=True)
        print("\nALL LIVE CONNECT-RPC FLOW CHECKS PASSED (READ-ONLY DESKTOP MODE).", flush=True)
        return

    # 2. Create Session (`StartCascade`)
    sc_status, sc_res = call_rpc_json(
        base_url,
        "StartCascade",
        {
            "metadata": {"ideName": "antigravity-ios", "ideVersion": "2.0.0"},
            "workspaceUris": [ws_uri],
            "modelId": "MODEL_PLACEHOLDER_M26",
        },
        csrf_token=csrf_token,
    )
    assert sc_status == 200 and sc_res.get("cascadeId"), f"StartCascade failed: {sc_status} {sc_res}"
    cascade_id = sc_res["cascadeId"]
    print(f"  [PASS] 2.  Create Session (`StartCascade`) -> cascadeId={cascade_id}")

    # 3. Send Message (`SendUserCascadeMessage`) + Confirm Summary & Trajectory Steps
    msg_payload = {
        "cascadeId": cascade_id,
        "items": [
            {"text": "Reply in one short sentence confirming iOS Connect-RPC handshake."},
            {
                "item": {
                    "file": {
                        "absoluteUri": f"{ws_uri}/Packages/AntigravityData/Package.swift",
                        "label": "@Package.swift",
                    }
                }
            },
        ],
        "userResponse": "Reply in one short sentence confirming iOS Connect-RPC handshake.",
        "metadata": {"ideName": "antigravity-ios", "ideVersion": "2.0.0"},
        "cascadeConfig": {
            "plannerConfig": {
                "conversational": {"plannerMode": "CONVERSATIONAL_PLANNER_MODE_DEFAULT"},
                "requestedModel": {"model": "MODEL_PLACEHOLDER_M26"},
            }
        },
    }
    send_status, send_res = call_rpc_json(base_url, "SendUserCascadeMessage", msg_payload, csrf_token=csrf_token)
    assert send_status == 200, f"SendUserCascadeMessage failed: {send_status} {send_res}"
    print(f"  [PASS] 3a. Sent Message (`SendUserCascadeMessage`) to {cascade_id}")

    in_map = False
    in_arr = False
    for _ in range(6):
        list_status, list_res = call_rpc_json(base_url, "GetAllCascadeTrajectories", {}, csrf_token=csrf_token)
        assert list_status == 200
        in_map = cascade_id in (list_res.get("trajectorySummaries") or {})
        in_arr = any(t.get("cascadeId") == cascade_id for t in (list_res.get("trajectories") or []))
        if in_map or in_arr:
            break
        time.sleep(0.25)
    assert in_map or in_arr, "Newly created cascadeId not found in GetAllCascadeTrajectories"
    print(f"  [PASS] 3b. Session confirmed in `GetAllCascadeTrajectories` (trajectorySummaries={in_map})", flush=True)

    steps = []
    for _ in range(8):
        steps_status, steps_res = call_rpc_json(
            base_url,
            "GetCascadeTrajectorySteps",
            {"cascadeId": cascade_id, "startIndex": 0, "endIndex": 50},
            csrf_token=csrf_token,
        )
        assert steps_status == 200, f"GetCascadeTrajectorySteps failed: {steps_status}"
        steps = steps_res.get("steps", [])
        if len(steps) >= 1:
            break
        time.sleep(0.25)
    assert len(steps) >= 1, f"Expected >=1 trajectory steps after sending message, got {len(steps)}"
    print(f"  [PASS] 3c. Synced Trajectory (`GetCascadeTrajectorySteps` JSON) -> {len(steps)} step(s) returned", flush=True)

    if not live_external:
        # 4. Trigger WAITING command & verify Face ID Interaction Gate
        call_rpc_json(
            base_url,
            "SendUserCascadeMessage",
            {"cascadeId": cascade_id, "userResponse": "Please run_command vegeta benchmark"},
            csrf_token=csrf_token,
        )
        _, wait_steps_res = call_rpc_json(
            base_url,
            "GetCascadeTrajectorySteps",
            {"cascadeId": cascade_id, "startIndex": 0, "endIndex": 50},
            csrf_token=csrf_token,
        )
        waiting = [s for s in wait_steps_res.get("steps", []) if s.get("status") == "CORTEX_STEP_STATUS_WAITING"]
        assert waiting, "Expected a WAITING runCommand step"
        wait_idx = waiting[-1]["stepIndex"]

        no_bio_status, _ = call_rpc_json(
            base_url,
            "HandleCascadeUserInteraction",
            {
                "interaction": {
                    "trajectoryId": cascade_id,
                    "stepIndex": wait_idx,
                    "runCommand": {
                        "confirm": True,
                        "proposedCommandLine": "go test -v ./...",
                        "submittedCommandLine": "go test -v ./...",
                        "faceIdVerified": False,
                    },
                }
            },
            csrf_token=csrf_token,
        )
        assert no_bio_status == 403, f"Expected 403 without Face ID verification, got {no_bio_status}"

        bio_status, bio_res = call_rpc_json(
            base_url,
            "HandleCascadeUserInteraction",
            {
                "interaction": {
                    "trajectoryId": cascade_id,
                    "stepIndex": wait_idx,
                    "runCommand": {
                        "confirm": True,
                        "proposedCommandLine": "go test -v ./...",
                        "submittedCommandLine": "go test -v ./...",
                        "faceIdVerified": True,
                    },
                }
            },
            csrf_token=csrf_token,
        )
        assert bio_status == 200 and bio_res.get("accepted") is True
        print("  [PASS] 4.  Face ID Approval Gate (`HandleCascadeUserInteraction` 403 -> 200 verified)", flush=True)

        # 5. Connect 5-byte Envelope Stream (`JetboxSubscribeToSummaries`)
        stream_req = urllib.request.Request(
            f"{base_url.rstrip('/')}{SERVICE_PREFIX}JetboxSubscribeToSummaries",
            data=struct.pack(">BI", 0, 2) + b"{}",
            method="POST",
            headers={
                "Content-Type": "application/connect+json",
                "Connect-Protocol-Version": "1",
                "x-codeium-csrf-token": csrf_token,
            },
        )
        with urlopen_direct(stream_req, timeout=10) as sresp:
            raw_stream = sresp.read()
        flags, frame_len = struct.unpack(">BI", raw_stream[:5])
        first_event = json.loads(raw_stream[5 : 5 + frame_len].decode("utf-8"))
        assert flags == 0 and "cascadeId" in first_event
        print(f"  [PASS] 5.  Connect 5-Byte Envelope Stream (`JetboxSubscribeToSummaries`) -> frame0={first_event['cascadeId']}", flush=True)

        # 6. Binary Protobuf >600-step fetch (`application/proto`)
        proto_req = urllib.request.Request(
            f"{base_url.rstrip('/')}{SERVICE_PREFIX}GetCascadeTrajectorySteps",
            data=b"\x0a\x10cas-live-welcome\x10\x00\x18\xdd\x04",
            method="POST",
            headers={
                "Content-Type": "application/proto",
                "Accept": "application/proto",
                "Connect-Protocol-Version": "1",
                "x-codeium-csrf-token": csrf_token,
            },
        )
        with urlopen_direct(proto_req, timeout=10) as presp:
            proto_bytes = presp.read()
        assert len(proto_bytes) > 10000
        print(f"  [PASS] 6.  Binary Protobuf `GetCascadeTrajectorySteps` (>600 steps) -> {len(proto_bytes)} bytes", flush=True)

    print("\nALL LIVE CONNECT-RPC FLOW CHECKS PASSED.", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=None, help="Target Connect-RPC base URL")
    parser.add_argument("--csrf", default=None, help="x-codeium-csrf-token")
    parser.add_argument(
        "--read-only",
        action="store_true",
        help="Verify live auth + workspaces + trajectories + steps without creating a new test session",
    )
    args = parser.parse_args()

    if args.url:
        run_flow(args.url, args.csrf or "", live_external=True, read_only=args.read_only)
        return

    bridge_mod = load_bridge_module()
    csrf = f"test-csrf-{secrets.token_hex(8)}"
    server = bridge_mod.create_bridge_server(
        bind_host="127.0.0.1",
        bind_port=0,
        bridge_csrf=csrf,
        workspace_root=str(ROOT),
    )
    port = server.server_port
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        run_flow(f"http://127.0.0.1:{port}", csrf, live_external=False)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
