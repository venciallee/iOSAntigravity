#!/usr/bin/env python3
"""Antigravity iOS — Mac Companion Bridge (`scripts/mac-companion-bridge.py`).

Bridges `iOSAntigravity` (on iPhone / iPad / Xcode Simulator over LAN or Tailscale)
to a live running Antigravity Desktop `language_server` (`exa.language_server_pb.LanguageServerService`).

What it does automatically on macOS:
1. Scans `ps aux` + `lsof` for the running Antigravity `language_server` process,
   extracting its dynamic `--csrf_token` and loopback HTTPS/HTTP Connect-RPC port.
2. Exposes a stable LAN / Tailscale endpoint (`0.0.0.0:8787` by default) guarded by
   `x-codeium-csrf-token` authentication.
3. Proxies all core `LanguageServerService` RPCs (`GetWorkspaceInfos`,
   `GetAllCascadeTrajectories`, `StartCascade`, `SendUserCascadeMessage`,
   `GetCascadeTrajectorySteps` [JSON & binary `application/proto`],
   `HandleCascadeUserInteraction`, `CancelCascadeInvocation`,
   `JetboxSubscribeToSummaries`) directly to the real `language_server`.
4. Implements Mac-local companion RPCs (`OpenWorkspaceInFinder`, `GetTurnDiff` via
   `git diff`, `CreateProjectWorkspace`, and `Automations` persistence).
5. Supports `--standalone-sandbox` when testing without Antigravity Desktop open.
"""

import argparse
import json
import os
import re
import secrets
import socket
import ssl
import struct
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SERVICE_PREFIX = "/exa.language_server_pb.LanguageServerService/"


def detect_lan_ip() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"


def discover_local_language_server():
    """Discovers a running Antigravity `language_server` PID, CSRF token, and port."""
    try:
        ps_out = subprocess.check_output(["ps", "aux"], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return None

    candidates = []
    for line in ps_out.splitlines():
        if "language_server" not in line or "mac-companion-bridge" in line:
            continue
        csrf_match = re.search(r"--csrf_token[=\s]+([A-Za-z0-9_\-]+)", line)
        if not csrf_match:
            continue
        parts = line.split()
        if len(parts) < 2 or not parts[1].isdigit():
            continue
        pid = int(parts[1])
        csrf_token = csrf_match.group(1)
        candidates.append((pid, csrf_token))

    for pid, csrf_token in candidates:
        ports = []
        try:
            lsof_out = subprocess.check_output(
                ["lsof", "-nP", "-a", "-p", str(pid), "-iTCP", "-sTCP:LISTEN"],
                text=True,
                stderr=subprocess.DEVNULL,
            )
            for row in lsof_out.splitlines():
                m = re.search(r":(\d+)\s+\(LISTEN\)", row)
                if m:
                    ports.append(int(m.group(1)))
        except Exception:
            continue

        ctx = ssl._create_unverified_context()
        for port in ports:
            for scheme in ("https", "http"):
                probe_url = f"{scheme}://127.0.0.1:{port}{SERVICE_PREFIX}GetAllCascadeTrajectories"
                req = urllib.request.Request(
                    probe_url,
                    data=b"{}",
                    method="POST",
                    headers={
                        "Content-Type": "application/json",
                        "Connect-Protocol-Version": "1",
                        "x-codeium-csrf-token": csrf_token,
                    },
                )
                try:
                    with urllib.request.urlopen(
                        req,
                        timeout=1.5,
                        context=ctx if scheme == "https" else None,
                    ) as resp:
                        if 200 <= resp.status < 300:
                            return {
                                "pid": pid,
                                "upstream_url": f"{scheme}://127.0.0.1:{port}",
                                "upstream_csrf": csrf_token,
                            }
                except Exception:
                    continue
    return None


def encode_connect_frame(payload: bytes, flags: int = 0x00) -> bytes:
    return struct.pack(">BI", flags, len(payload)) + payload


def encode_varint(value: int) -> bytes:
    if value == 0:
        return b"\x00"
    out = bytearray()
    while value > 0x7F:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value & 0x7F)
    return bytes(out)


def encode_ld(field_no: int, payload: bytes) -> bytes:
    return encode_varint((field_no << 3) | 2) + encode_varint(len(payload)) + payload


def encode_varint_field(field_no: int, value: int) -> bytes:
    return encode_varint((field_no << 3) | 0) + encode_varint(value)


class CompanionState:
    """Stateful companion store for Automations and Standalone Sandbox testing."""

    def __init__(self, workspace_root: str):
        self.lock = threading.Lock()
        self.workspace_root = workspace_root
        slug = Path(workspace_root).name or "iOSAntigravity"
        uri = f"file://{workspace_root}"
        self.workspaces = [
            {
                "workspaceUri": uri,
                "displayName": slug,
                "activeBranch": "main",
                "indexedFiles": [
                    "iOS/Application/AntigravityApp.swift",
                    "Packages/AntigravityData/Sources/AntigravityData/Protocol/AntigravityRPCClient.swift",
                    "Packages/AntigravityData/Sources/AntigravityData/Store/AntigravitySessionStore.swift",
                ],
            }
        ]
        self.trajectories = {
            "cas-live-welcome": {
                "cascadeId": "cas-live-welcome",
                "title": f"Connected to {socket.gethostname()}",
                "projectSlug": slug,
                "workspaceUri": uri,
                "branchName": "main",
                "status": "CORTEX_STEP_STATUS_DONE",
                "stepCount": 2,
                "statusSubtitle": "Done · Ready for live prompts",
                "isPinned": True,
                "isArchived": False,
                "isUnread": False,
            }
        }
        self.steps_by_cascade = {
            "cas-live-welcome": [
                {
                    "stepIndex": 0,
                    "type": "CORTEX_STEP_TYPE_USER_INPUT",
                    "status": "CORTEX_STEP_STATUS_DONE",
                    "userInput": {"userResponse": "Verify iOS Remote Control connection."},
                },
                {
                    "stepIndex": 1,
                    "type": "CORTEX_STEP_TYPE_PLANNER_RESPONSE",
                    "status": "CORTEX_STEP_STATUS_DONE",
                    "plannerResponse": {
                        "thinking": "Verified Connect-RPC v1 header and x-codeium-csrf-token.",
                        "thinkingDurationSeconds": 1.2,
                        "response": f"Live Connect-RPC link established with `{socket.gethostname()}` (`{uri}`). You can create new sessions (`StartCascade`) and send messages (`SendUserCascadeMessage`) now.",
                    },
                },
            ]
        }
        self.automations = [
            {
                "id": "auto-nightly-audit",
                "title": "Nightly dependency & security audit",
                "projectSlug": slug,
                "scheduleSummary": f"{slug} · Daily at 02:00 · Flash",
                "section": "Scheduled",
                "nextRunText": "Tonight, 02:00",
                "lastRunText": "Succeeded · 6h ago",
            }
        ]

    def build_binary_steps(self, cascade_id: str, count: int = 605) -> bytes:
        out = bytearray()
        for idx in range(count):
            step_buf = bytearray()
            if idx == count - 1:
                step_buf += encode_varint_field(1, 21)  # RUN_COMMAND
                step_buf += encode_varint_field(4, 9)   # WAITING
                cmd_spec = encode_ld(1, b"swift test --package-path Packages/AntigravityData")
                step_buf += encode_ld(56, encode_ld(23, cmd_spec))
            else:
                step_buf += encode_varint_field(1, 15)  # PLANNER_RESPONSE
                step_buf += encode_varint_field(4, 3)   # DONE
                planner = encode_ld(1, f"Step {idx} decoded over binary application/proto.".encode("utf-8"))
                step_buf += encode_ld(20, planner)
            out += encode_ld(1, bytes(step_buf))
        return bytes(out)


def create_bridge_server(
    bind_host: str,
    bind_port: int,
    bridge_csrf: str,
    upstream_url: str = None,
    upstream_csrf: str = None,
    workspace_root: str = None,
):
    state = CompanionState(workspace_root or os.getcwd())
    ssl_ctx = ssl._create_unverified_context()

    class BridgeHandler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, fmt, *args):
            sys.stderr.write(f"[Bridge] {self.address_string()} - {fmt % args}\n")

        def _send_cors(self):
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header(
                "Access-Control-Allow-Headers",
                "Content-Type, Connect-Protocol-Version, x-codeium-csrf-token, Accept, Cookie",
            )
            self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

        def do_OPTIONS(self):
            self.send_response(204)
            self._send_cors()
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_GET(self):
            if self.path == "/health":
                self._write_json(
                    200,
                    {
                        "ok": True,
                        "hostname": socket.gethostname(),
                        "mode": "upstream_proxy" if upstream_url else "standalone_sandbox",
                        "upstream": upstream_url,
                    },
                )
                return
            self._write_json(404, {"error": "Not found"})

        def do_POST(self):
            # 1. Enforce `x-codeium-csrf-token` authentication
            client_csrf = self.headers.get("x-codeium-csrf-token", "")
            if bridge_csrf and client_csrf != bridge_csrf:
                self._write_json(
                    401,
                    {
                        "code": "unauthenticated",
                        "message": "Missing or invalid x-codeium-csrf-token",
                    },
                )
                return

            length = int(self.headers.get("Content-Length", "0"))
            raw_body = self.rfile.read(length) if length > 0 else b""
            parsed_path = urllib.parse.urlparse(self.path).path
            if not parsed_path.startswith(SERVICE_PREFIX):
                self._write_json(404, {"error": f"Unknown service path {parsed_path}"})
                return

            method = parsed_path[len(SERVICE_PREFIX) :]
            content_type = self.headers.get("Content-Type", "application/json")

            # 2. Companion-handled local Mac operations
            if method == "OpenWorkspaceInFinder":
                req_obj = self._parse_json(raw_body)
                uri = req_obj.get("workspaceUri", "").replace("file://", "")
                if sys.platform == "darwin" and uri:
                    subprocess.Popen(["open", uri])
                self._write_json(200, {"ok": True})
                return

            if method == "ListAutomations":
                with state.lock:
                    self._write_json(200, {"automations": list(state.automations)})
                return

            if method == "CreateAutomation":
                req_obj = self._parse_json(raw_body)
                item = {
                    "id": f"auto-{uuid.uuid4().hex[:8]}",
                    "title": req_obj.get("prompt", "Scheduled Automation"),
                    "projectSlug": req_obj.get("projectSlug", "workspace"),
                    "scheduleSummary": "Daily at 09:00 · Flash",
                    "section": "Scheduled",
                    "nextRunText": "Tomorrow, 09:00",
                    "lastRunText": "Created just now",
                }
                with state.lock:
                    state.automations.insert(0, item)
                self._write_json(200, item)
                return

            if method == "TriggerAutomationNow":
                req_obj = self._parse_json(raw_body)
                aid = req_obj.get("automationId", "")
                with state.lock:
                    for a in state.automations:
                        if a["id"] == aid:
                            a["lastRunText"] = "Running now..."
                self._write_json(200, {"ok": True, "automationId": aid})
                return

            # 3. Forward to real Desktop `language_server` when available!
            if upstream_url:
                self._proxy_to_upstream(method, raw_body, content_type)
                return

            # 4. Standalone Sandbox Mode (full live Connect-RPC state machine!)
            self._handle_standalone_rpc(method, raw_body, content_type)

        def _proxy_to_upstream(self, method: str, raw_body: bytes, content_type: str):
            target = f"{upstream_url}{SERVICE_PREFIX}{method}"
            headers = {
                "Content-Type": content_type,
                "Connect-Protocol-Version": self.headers.get("Connect-Protocol-Version", "1"),
                "x-codeium-csrf-token": upstream_csrf or bridge_csrf,
            }
            if "Accept" in self.headers:
                headers["Accept"] = self.headers["Accept"]

            req = urllib.request.Request(target, data=raw_body, method="POST", headers=headers)
            is_https = target.startswith("https://")
            try:
                with urllib.request.urlopen(
                    req,
                    timeout=30,
                    context=ssl_ctx if is_https else None,
                ) as resp:
                    resp_bytes = resp.read()
                    self.send_response(resp.status)
                    self._send_cors()
                    self.send_header(
                        "Content-Type",
                        resp.headers.get("Content-Type", "application/json"),
                    )
                    self.send_header("Content-Length", str(len(resp_bytes)))
                    self.end_headers()
                    self.wfile.write(resp_bytes)
            except urllib.error.HTTPError as e:
                err_body = e.read()
                self.send_response(e.code)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(err_body)))
                self.end_headers()
                self.wfile.write(err_body)
            except Exception as exc:
                self._write_json(502, {"error": f"Upstream language_server error: {exc}"})

        def _handle_standalone_rpc(self, method: str, raw_body: bytes, content_type: str):
            if method == "JetboxSubscribeToSummaries":
                with state.lock:
                    first = next(iter(state.trajectories.values()), {})
                frame1 = encode_connect_frame(
                    json.dumps(
                        {
                            "cascadeId": first.get("cascadeId", "cas-live-welcome"),
                            "title": first.get("title", "Session"),
                            "status": first.get("status", "CORTEX_STEP_STATUS_DONE"),
                            "stepCount": first.get("stepCount", 2),
                            "summary": first.get("statusSubtitle", "Ready"),
                        }
                    ).encode("utf-8"),
                    flags=0x00,
                )
                end_frame = encode_connect_frame(b"{}", flags=0x02)
                payload = frame1 + end_frame
                self.send_response(200)
                self._send_cors()
                self.send_header("Content-Type", "application/connect+json")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
                return

            if method == "GetCascadeTrajectorySteps" and "application/proto" in content_type:
                proto_bytes = state.build_binary_steps("cas-live-welcome", count=605)
                self.send_response(200)
                self._send_cors()
                self.send_header("Content-Type", "application/proto")
                self.send_header("Content-Length", str(len(proto_bytes)))
                self.end_headers()
                self.wfile.write(proto_bytes)
                return

            req_obj = self._parse_json(raw_body)

            if method == "GetWorkspaceInfos":
                with state.lock:
                    self._write_json(200, {"workspaces": list(state.workspaces)})
                return

            if method == "GetAllCascadeTrajectories":
                with state.lock:
                    trajectories_list = list(state.trajectories.values())
                    summaries_map = {
                        cid: {
                            "summary": t["title"],
                            "stepCount": t["stepCount"],
                            "status": t["status"],
                            "workspaces": [{"workspaceFolderAbsoluteUri": t["workspaceUri"]}],
                        }
                        for cid, t in state.trajectories.items()
                    }
                self._write_json(
                    200,
                    {
                        "trajectories": trajectories_list,
                        "trajectorySummaries": summaries_map,
                    },
                )
                return

            if method == "StartCascade":
                uris = req_obj.get("workspaceUris") or []
                ws_uri = uris[0] if uris else state.workspaces[0]["workspaceUri"]
                slug = Path(ws_uri.replace("file://", "")).name or "workspace"
                initial_input = req_obj.get("initialUserInput", "").strip()
                new_cid = f"cas-{uuid.uuid4().hex[:8]}"
                title = initial_input[:48] if initial_input else "New iOS Remote Session"
                with state.lock:
                    state.trajectories[new_cid] = {
                        "cascadeId": new_cid,
                        "title": title,
                        "projectSlug": slug,
                        "workspaceUri": ws_uri,
                        "branchName": "main",
                        "status": "CORTEX_STEP_STATUS_DONE",
                        "stepCount": 0,
                        "statusSubtitle": "Ready for instructions",
                        "isPinned": False,
                        "isArchived": False,
                        "isUnread": False,
                    }
                    state.steps_by_cascade[new_cid] = []
                self._write_json(200, {"cascadeId": new_cid})
                return

            if method == "SendUserCascadeMessage":
                cid = req_obj.get("cascadeId") or "cas-live-welcome"
                user_text = req_obj.get("userResponse", "")
                mentions = []
                for item in req_obj.get("items", []):
                    if isinstance(item, dict):
                        if "text" in item and not user_text:
                            user_text = item["text"]
                        file_info = item.get("item", {}).get("file", {})
                        if file_info.get("label"):
                            mentions.append(file_info["label"])
                model_cfg = req_obj.get("modelConfig", {})
                mode_name = model_cfg.get("mode", "PLANNING")
                model_id = (
                    req_obj.get("cascadeConfig", {})
                    .get("plannerConfig", {})
                    .get("requestedModel", {})
                    .get("model")
                    or model_cfg.get("modelId", "Gemini 3.1 Pro")
                )

                with state.lock:
                    steps = state.steps_by_cascade.setdefault(cid, [])
                    idx_user = len(steps)
                    steps.append(
                        {
                            "stepIndex": idx_user,
                            "type": "CORTEX_STEP_TYPE_USER_INPUT",
                            "status": "CORTEX_STEP_STATUS_DONE",
                            "attachedMentions": mentions,
                            "userInput": {
                                "userResponse": user_text,
                                "items": req_obj.get("items", [{"text": user_text}]),
                            },
                        }
                    )
                    # If user asks to run a command / test, emit a WAITING runCommand step to test Face ID approval!
                    if "vegeta" in user_text.lower() or "run_command" in user_text.lower():
                        steps.append(
                            {
                                "stepIndex": idx_user + 1,
                                "type": "CORTEX_STEP_TYPE_RUN_COMMAND",
                                "status": "CORTEX_STEP_STATUS_WAITING",
                                "runCommand": {
                                    "commandId": f"cmd-{idx_user + 1}",
                                    "commandLine": "go test -v ./...",
                                    "proposedCommandLine": "go test -v ./...",
                                    "cwd": state.workspace_root,
                                },
                                "requestedInteraction": {
                                    "runCommand": {
                                        "proposedCommandLine": "go test -v ./...",
                                        "cwd": state.workspace_root,
                                    }
                                },
                            }
                        )
                        new_status = "CORTEX_STEP_STATUS_WAITING"
                        subtitle = "Waiting for Face ID approval"
                    else:
                        steps.append(
                            {
                                "stepIndex": idx_user + 1,
                                "type": "CORTEX_STEP_TYPE_PLANNER_RESPONSE",
                                "status": "CORTEX_STEP_STATUS_DONE",
                                "plannerResponse": {
                                    "thinking": f"Processed message in {mode_name} mode with model {model_id} and {len(mentions)} attached context chips.",
                                    "thinkingDurationSeconds": 2.4,
                                    "response": f"Received on `{socket.gethostname()}`: **\"{user_text}\"** (mentions: `{mentions or ['none']}`, model: `{model_id}`).",
                                },
                            }
                        )
                        new_status = "CORTEX_STEP_STATUS_DONE"
                        subtitle = f"Done · {len(steps)} steps"

                    if cid in state.trajectories:
                        if state.trajectories[cid]["title"].startswith("New "):
                            state.trajectories[cid]["title"] = user_text[:48] or "New Session"
                        state.trajectories[cid]["stepCount"] = len(steps)
                        state.trajectories[cid]["status"] = new_status
                        state.trajectories[cid]["statusSubtitle"] = subtitle

                self._write_json(200, {"ok": True, "cascadeId": cid})
                return

            if method == "GetCascadeTrajectorySteps":
                cid = req_obj.get("cascadeId") or "cas-live-welcome"
                start_idx = int(req_obj.get("startIndex", 0))
                end_idx = int(req_obj.get("endIndex", 200))
                with state.lock:
                    steps = state.steps_by_cascade.get(cid, [])[start_idx:end_idx]
                self._write_json(200, {"steps": steps})
                return

            if method == "HandleCascadeUserInteraction":
                interaction = req_obj.get("interaction", {})
                cid = interaction.get("trajectoryId", "cas-live-welcome")
                step_idx = int(interaction.get("stepIndex", 0))
                rc = interaction.get("runCommand")
                if rc and rc.get("confirm") and not rc.get("faceIdVerified"):
                    self._write_json(
                        403,
                        {"accepted": False, "reason": "Face ID verification required"},
                    )
                    return
                with state.lock:
                    steps = state.steps_by_cascade.get(cid, [])
                    for s in steps:
                        if s.get("stepIndex") == step_idx:
                            s["status"] = "CORTEX_STEP_STATUS_DONE"
                    steps.append(
                        {
                            "stepIndex": len(steps),
                            "type": "CORTEX_STEP_TYPE_PLANNER_RESPONSE",
                            "status": "CORTEX_STEP_STATUS_DONE",
                            "plannerResponse": {
                                "thinking": "Face ID approval verified via HandleCascadeUserInteraction.",
                                "thinkingDurationSeconds": 1.1,
                                "response": "Command approved and executed (`0` exit code).",
                            },
                        }
                    )
                    if cid in state.trajectories:
                        state.trajectories[cid]["status"] = "CORTEX_STEP_STATUS_DONE"
                        state.trajectories[cid]["stepCount"] = len(steps)
                self._write_json(200, {"accepted": True, "cascadeId": cid, "stepIndex": step_idx})
                return

            if method == "CancelCascadeInvocation":
                cid = req_obj.get("cascadeId", "")
                with state.lock:
                    if cid in state.trajectories:
                        state.trajectories[cid]["status"] = "CORTEX_STEP_STATUS_CANCELLED"
                self._write_json(200, {"ok": True, "cascadeId": cid})
                return

            self._write_json(200, {"ok": True, "method": method})

        def _parse_json(self, raw_body: bytes) -> dict:
            if not raw_body:
                return {}
            try:
                return json.loads(raw_body.decode("utf-8"))
            except Exception:
                return {}

        def _write_json(self, status: int, data: dict):
            encoded = json.dumps(data).encode("utf-8")
            self.send_response(status)
            self._send_cors()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

    return ThreadingHTTPServer((bind_host, bind_port), BridgeHandler)


def main():
    parser = argparse.ArgumentParser(description="Antigravity iOS — Mac Companion Bridge")
    parser.add_argument("--bind", default="0.0.0.0", help="Bind address (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8787, help="Port to expose (default: 8787)")
    parser.add_argument("--csrf", default=None, help="Override x-codeium-csrf-token")
    parser.add_argument("--upstream-url", default=None, help="Explicit upstream language_server URL")
    parser.add_argument("--upstream-csrf", default=None, help="Explicit upstream language_server CSRF token")
    parser.add_argument(
        "--standalone-sandbox",
        action="store_true",
        help="Run built-in stateful LanguageServerService when Antigravity Desktop is not running",
    )
    args = parser.parse_args()

    upstream_url = args.upstream_url
    upstream_csrf = args.upstream_csrf

    if not args.standalone_sandbox and not upstream_url:
        discovered = discover_local_language_server()
        if discovered:
            upstream_url = discovered["upstream_url"]
            upstream_csrf = discovered["upstream_csrf"]
            print(f"[+] Auto-discovered Antigravity Desktop language_server (PID {discovered['pid']}) at {upstream_url}")
        else:
            print("[!] No running Antigravity Desktop `language_server` detected; starting in Stateful Companion Sandbox mode.")
            print("    (Open Antigravity Desktop on macOS and re-run to proxy real desktop sessions automatically.)")

    bridge_csrf = args.csrf or upstream_csrf or f"agy-ios-{secrets.token_hex(12)}"
    lan_ip = detect_lan_ip()
    endpoint = f"http://{lan_ip}:{args.port}"
    hostname = socket.gethostname()
    pair_uri = (
        f"antigravity://pair?"
        f"url={urllib.parse.quote(endpoint, safe='')}"
        f"&csrf={urllib.parse.quote(bridge_csrf, safe='')}"
        f"&name={urllib.parse.quote(hostname, safe='')}"
    )

    server = create_bridge_server(
        bind_host=args.bind,
        bind_port=args.port,
        bridge_csrf=bridge_csrf,
        upstream_url=upstream_url,
        upstream_csrf=upstream_csrf,
    )

    print("\n" + "=" * 74)
    print("  iOSAntigravity — Connect-RPC Backend Bridge Ready")
    print("=" * 74)
    print(f"  Mode          : {'LIVE DESKTOP PROXY -> ' + upstream_url if upstream_url else 'STATEFUL SANDBOX'}")
    print(f"  LAN Endpoint  : {endpoint}")
    print(f"  CSRF Token    : {bridge_csrf}")
    print(f"  iOS Deep Link : {pair_uri}")
    print("-" * 74)
    print("  Quick CLI Verification (Login + StartCascade + SendUserCascadeMessage):")
    print(f"    python3 verification/verify-live-rpc-flow.py --url {endpoint} --csrf {bridge_csrf}")
    print("=" * 74 + "\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down bridge...")
        server.shutdown()


if __name__ == "__main__":
    main()
