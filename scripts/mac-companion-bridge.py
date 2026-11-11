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


def make_unverified_ssl_context() -> ssl.SSLContext:
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def urlopen_direct(req: urllib.request.Request, timeout: float = 15.0, ssl_ctx: ssl.SSLContext = None):
    """Opens HTTP/HTTPS requests while bypassing system/env HTTP proxies for loopback (`127.0.0.1`/`localhost`)."""
    parsed = urllib.parse.urlparse(req.full_url)
    host = (parsed.hostname or "").lower()
    handlers = []
    if host in ("127.0.0.1", "localhost", "::1"):
        handlers.append(urllib.request.ProxyHandler({}))
    if parsed.scheme == "https" and ssl_ctx is not None:
        handlers.append(urllib.request.HTTPSHandler(context=ssl_ctx))
    opener = urllib.request.build_opener(*handlers)
    return opener.open(req, timeout=timeout)


def detect_lan_ip() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"


def discover_local_language_server():
    """Discovers a running Antigravity `language_server` PID, CSRF token, and port with bounded timeouts."""
    try:
        ps_out = subprocess.check_output(
            ["ps", "aux"], text=True, stderr=subprocess.DEVNULL, timeout=2.5
        )
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
        hinted_ports = [
            int(p)
            for p in re.findall(r"--[A-Za-z0-9_]*port[=\s]+(\d+)", line)
            if 1024 <= int(p) <= 65535
        ]
        candidates.append((pid, csrf_token, hinted_ports))

    ctx = make_unverified_ssl_context()
    deadline = time.monotonic() + 6.0

    for pid, csrf_token, hinted_ports in candidates:
        if time.monotonic() > deadline:
            break
        ports = list(dict.fromkeys(hinted_ports))
        try:
            lsof_out = subprocess.check_output(
                ["lsof", "-nP", "-a", "-p", str(pid), "-iTCP", "-sTCP:LISTEN"],
                text=True,
                stderr=subprocess.DEVNULL,
                timeout=2.5,
            )
            for row in lsof_out.splitlines():
                m = re.search(r":(\d+)\s+\(LISTEN\)", row)
                if m:
                    p = int(m.group(1))
                    if p not in ports:
                        ports.append(p)
        except Exception:
            pass

        for port in ports:
            if time.monotonic() > deadline:
                break
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
                    with urlopen_direct(
                        req,
                        timeout=0.8,
                        ssl_ctx=ctx if scheme == "https" else None,
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


def discover_desktop_oauth_token() -> str:
    """Extracts the active OAuth access token (`ya29.*`) from Antigravity Desktop's `state.vscdb` (read-only)."""
    env_key = os.environ.get("ANTIGRAVITY_API_KEY", "").strip()
    if env_key:
        return env_key
    if sys.platform != "darwin":
        return ""
    db_path = Path.home() / "Library/Application Support/Antigravity/User/globalStorage/state.vscdb"
    if not db_path.exists():
        return ""
    try:
        import base64
        import sqlite3

        uri = f"file:{urllib.parse.quote(str(db_path))}?mode=ro"
        conn = sqlite3.connect(uri, uri=True, timeout=1.5)
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT value FROM ItemTable WHERE key IN ("
                "'antigravityUnifiedStateSync.oauthToken', "
                "'jetskiStateSync.agentManagerInitState'"
                ")"
            )
            rows = cur.fetchall()
        finally:
            conn.close()

        for (val,) in rows:
            if not val:
                continue
            text = val if isinstance(val, str) else val.decode("utf-8", errors="ignore")
            m = re.search(r"(ya29\.[A-Za-z0-9._\-]+)", text)
            if m:
                return m.group(1)
            try:
                decoded = base64.b64decode(text).decode("utf-8", errors="ignore")
                m2 = re.search(r"(ya29\.[A-Za-z0-9._\-]+)", decoded)
                if m2:
                    return m2.group(1)
            except Exception:
                continue
    except Exception:
        return ""
    return ""


def query_upstream_default_model(upstream_url: str, upstream_csrf: str, api_key: str) -> tuple[str, set[str]]:
    """Queries `GetCascadeModelConfigData` on real `language_server` to resolve valid model enum IDs."""
    if not upstream_url:
        return "", set()
    ctx = make_unverified_ssl_context()
    meta = {"ideName": "antigravity", "extensionName": "antigravity", "locale": "en"}
    if api_key:
        meta["apiKey"] = api_key
    req = urllib.request.Request(
        f"{upstream_url}{SERVICE_PREFIX}GetCascadeModelConfigData",
        data=json.dumps({"metadata": meta}).encode("utf-8"),
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Connect-Protocol-Version": "1",
            "x-codeium-csrf-token": upstream_csrf,
        },
    )
    try:
        with urlopen_direct(
            req,
            timeout=1.5,
            ssl_ctx=ctx if upstream_url.startswith("https://") else None,
        ) as resp:
            obj = json.loads(resp.read().decode("utf-8") or "{}")
            valid_models = set()
            for cfg in obj.get("clientModelConfigs") or []:
                m = (cfg.get("modelOrAlias") or {}).get("model")
                if m:
                    valid_models.add(m)
            default_model = (
                ((obj.get("defaultOverrideModelConfig") or {}).get("modelOrAlias") or {}).get("model")
                or (next(iter(valid_models)) if valid_models else "")
            )
            return default_model, valid_models
    except Exception:
        return "", set()


def create_bridge_server(
    bind_host: str,
    bind_port: int,
    bridge_csrf: str,
    upstream_url: str = None,
    upstream_csrf: str = None,
    workspace_root: str = None,
):
    state = CompanionState(workspace_root or os.getcwd())
    ssl_ctx = make_unverified_ssl_context()
    desktop_api_key = discover_desktop_oauth_token() if upstream_url else ""
    upstream_default_model, upstream_valid_models = (
        query_upstream_default_model(upstream_url, upstream_csrf or bridge_csrf, desktop_api_key)
        if upstream_url
        else ("", set())
    )

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
                        "desktopAuthDetected": bool(desktop_api_key),
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

            if method == "CreateProjectWorkspace":
                req_obj = self._parse_json(raw_body)
                name = req_obj.get("name") or "new-project"
                runtime = req_obj.get("runtime") or "Local"
                repo = req_obj.get("repository") or name
                ws_uri = f"cloud://{repo}" if runtime == "Cloud" else f"file://{Path(state.workspace_root).parent / name}"
                with state.lock:
                    state.workspaces.append(
                        {
                            "workspaceUri": ws_uri,
                            "workspaceFolderAbsoluteUri": ws_uri,
                            "displayName": name,
                            "activeBranch": "main",
                            "indexedFiles": [],
                        }
                    )
                self._write_json(200, {"ok": True, "workspaceUri": ws_uri, "name": name})
                return

            if method == "GetTurnDiff":
                files = []
                try:
                    diff_out = subprocess.check_output(
                        ["git", "diff", "--numstat"],
                        cwd=state.workspace_root,
                        text=True,
                        stderr=subprocess.DEVNULL,
                    )
                    for row in diff_out.splitlines():
                        parts = row.split("\t")
                        if len(parts) == 3:
                            add_c = int(parts[0]) if parts[0].isdigit() else 0
                            del_c = int(parts[1]) if parts[1].isdigit() else 0
                            files.append({"filePath": parts[2], "additions": add_c, "deletions": del_c})
                except Exception:
                    pass
                self._write_json(200, {"files": files})
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

            if method == "JetboxSubscribeToSummaries":
                self._handle_standalone_rpc(method, raw_body, content_type)
                return

            # 3. Forward to real Desktop `language_server` when available!
            if upstream_url:
                self._proxy_to_upstream(method, raw_body, content_type)
                return

            # 4. Standalone Sandbox Mode (full live Connect-RPC state machine!)
            self._handle_standalone_rpc(method, raw_body, content_type)

        def _build_upstream_metadata(self, existing: dict) -> dict:
            meta = {}
            meta["ideName"] = "antigravity"
            meta["extensionName"] = "antigravity"
            meta["locale"] = existing.get("locale") or "en"
            if existing.get("ideVersion"):
                meta["ideVersion"] = existing["ideVersion"]
            api_key = existing.get("apiKey") or desktop_api_key or discover_desktop_oauth_token()
            if api_key:
                meta["apiKey"] = api_key
            return meta

        def _sanitize_for_upstream(self, method: str, req_obj: dict) -> tuple[int, dict]:
            """Sanitizes companion JSON extensions into strict `exa.language_server_pb` protojson."""
            if method == "StartCascade":
                sanitized = {
                    "metadata": self._build_upstream_metadata(req_obj.get("metadata") or {}),
                    "source": req_obj.get("source") or "CORTEX_TRAJECTORY_SOURCE_CASCADE_CLIENT",
                }
                if req_obj.get("workspaceUris"):
                    sanitized["workspaceUris"] = req_obj["workspaceUris"]
                return 200, sanitized

            if method == "SendUserCascadeMessage":
                fallback_text = req_obj.get("userResponse", "")
                clean_items = []
                for entry in req_obj.get("items") or []:
                    if not isinstance(entry, dict):
                        continue
                    if "text" in entry:
                        clean_items.append({"text": entry["text"]})
                    elif isinstance(entry.get("item"), dict) and isinstance(entry["item"].get("file"), dict):
                        abs_uri = entry["item"]["file"].get("absoluteUri", "")
                        local_path = abs_uri.replace("file://", "") if abs_uri.startswith("file://") else ""
                        if abs_uri and (not local_path or os.path.exists(local_path)):
                            clean_items.append({"item": {"file": {"absoluteUri": abs_uri}}})
                if not clean_items and fallback_text:
                    clean_items.append({"text": fallback_text})

                sanitized = {
                    "cascadeId": req_obj.get("cascadeId", ""),
                    "items": clean_items,
                    "metadata": self._build_upstream_metadata(req_obj.get("metadata") or {}),
                }
                cascade_cfg = json.loads(json.dumps(req_obj.get("cascadeConfig") or {}))
                planner_cfg = cascade_cfg.get("plannerConfig")
                if isinstance(planner_cfg, dict):
                    req_model = (planner_cfg.get("requestedModel") or {}).get("model", "")
                    if upstream_valid_models and req_model not in upstream_valid_models:
                        if upstream_default_model:
                            planner_cfg["requestedModel"] = {"model": upstream_default_model}
                        else:
                            planner_cfg.pop("requestedModel", None)
                    elif not upstream_valid_models and (" " in req_model or not req_model.startswith("MODEL_")):
                        if upstream_default_model:
                            planner_cfg["requestedModel"] = {"model": upstream_default_model}
                        else:
                            planner_cfg.pop("requestedModel", None)
                    sanitized["cascadeConfig"] = cascade_cfg
                return 200, sanitized

            if method == "HandleCascadeUserInteraction":
                cloned = json.loads(json.dumps(req_obj))
                interaction = cloned.get("interaction") or {}
                rc = interaction.get("runCommand")
                if isinstance(rc, dict):
                    if rc.get("confirm") and rc.get("faceIdVerified") is False:
                        return 403, {"accepted": False, "reason": "Face ID verification required"}
                    rc.pop("faceIdVerified", None)
                return 200, cloned

            return 200, req_obj

        def _proxy_to_upstream(self, method: str, raw_body: bytes, content_type: str):
            target = f"{upstream_url}{SERVICE_PREFIX}{method}"
            is_json = "json" in content_type.lower() and "connect+" not in content_type.lower()
            forward_body = raw_body
            req_obj = {}

            if is_json:
                req_obj = self._parse_json(raw_body)
                gate_status, sanitized = self._sanitize_for_upstream(method, req_obj)
                if gate_status != 200:
                    self._write_json(gate_status, sanitized)
                    return
                req_obj = sanitized
                forward_body = json.dumps(req_obj).encode("utf-8")

            headers = {
                "Content-Type": content_type,
                "Connect-Protocol-Version": self.headers.get("Connect-Protocol-Version", "1"),
                "x-codeium-csrf-token": upstream_csrf or bridge_csrf,
            }
            if "Accept" in self.headers:
                headers["Accept"] = self.headers["Accept"]

            is_https = target.startswith("https://")
            attempts = 0
            while True:
                attempts += 1
                req = urllib.request.Request(target, data=forward_body, method="POST", headers=headers)
                try:
                    with urlopen_direct(
                        req,
                        timeout=30,
                        ssl_ctx=ssl_ctx if is_https else None,
                    ) as resp:
                        resp_bytes = resp.read()
                        resp_ct = resp.headers.get("Content-Type", "application/json")
                        if is_json and method == "StartCascade":
                            sc_obj = self._parse_json(resp_bytes)
                            new_cid = sc_obj.get("cascadeId")
                            if new_cid:
                                uris = req_obj.get("workspaceUris") or []
                                ws_uri = uris[0] if uris else state.workspaces[0]["workspaceUri"]
                                slug = Path(ws_uri.replace("file://", "")).name or "workspace"
                                with state.lock:
                                    state.trajectories.setdefault(
                                        new_cid,
                                        {
                                            "cascadeId": new_cid,
                                            "title": "New iOS Remote Session",
                                            "projectSlug": slug,
                                            "workspaceUri": ws_uri,
                                            "branchName": "main",
                                            "status": "CORTEX_STEP_STATUS_DONE",
                                            "stepCount": 0,
                                            "statusSubtitle": "Ready for instructions",
                                            "isPinned": False,
                                            "isArchived": False,
                                            "isUnread": False,
                                        },
                                    )
                                    state.steps_by_cascade.setdefault(new_cid, [])
                        elif is_json and method == "SendUserCascadeMessage":
                            cid = req_obj.get("cascadeId", "")
                            if cid:
                                items = req_obj.get("items") or []
                                text_val = next(
                                    (i.get("text", "") for i in items if isinstance(i, dict) and "text" in i),
                                    "",
                                )
                                with state.lock:
                                    local_steps = state.steps_by_cascade.setdefault(cid, [])
                                    if not local_steps and text_val:
                                        local_steps.append(
                                            {
                                                "stepIndex": 0,
                                                "type": "CORTEX_STEP_TYPE_USER_INPUT",
                                                "status": "CORTEX_STEP_STATUS_DONE",
                                                "userInput": {"userResponse": text_val, "items": items},
                                            }
                                        )
                                    if cid in state.trajectories:
                                        if text_val and state.trajectories[cid]["title"].startswith("New "):
                                            state.trajectories[cid]["title"] = text_val[:48]
                                        state.trajectories[cid]["stepCount"] = max(
                                            state.trajectories[cid]["stepCount"], len(local_steps)
                                        )
                        elif is_json and method == "GetWorkspaceInfos":
                            resp_bytes = self._normalize_workspace_infos_response(resp_bytes)
                        elif is_json and method == "GetAllCascadeTrajectories":
                            resp_bytes = self._merge_local_trajectories_response(resp_bytes)
                        elif is_json and method == "GetCascadeTrajectorySteps":
                            resp_bytes = self._merge_local_steps_response(req_obj, resp_bytes)
                        self.send_response(resp.status)
                        self._send_cors()
                        self.send_header("Content-Type", resp_ct)
                        self.send_header("Content-Length", str(len(resp_bytes)))
                        self.end_headers()
                        self.wfile.write(resp_bytes)
                        return
                except urllib.error.HTTPError as e:
                    err_body = e.read()
                    err_text = err_body.decode("utf-8", errors="ignore")
                    # Auto-strip any protojson unknown top-level field if Desktop schema differs
                    if is_json and e.code == 400 and attempts <= 3:
                        m = re.search(r'unknown field "([^"]+)"', err_text)
                        if m and m.group(1) in req_obj:
                            req_obj.pop(m.group(1), None)
                            forward_body = json.dumps(req_obj).encode("utf-8")
                            continue
                    # Graceful fallback to local companion state if Desktop rejects model/auth/offline
                    if is_json and method in ("StartCascade", "SendUserCascadeMessage") and e.code in (
                        400,
                        401,
                        403,
                        404,
                        500,
                        502,
                        503,
                    ):
                        sys.stderr.write(
                            f"[Bridge] Upstream {method} returned HTTP {e.code} ({err_text[:120]}); falling back to companion session store.\n"
                        )
                        self._handle_standalone_rpc(method, raw_body, content_type)
                        return
                    self.send_response(e.code)
                    self._send_cors()
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(err_body)))
                    self.end_headers()
                    self.wfile.write(err_body)
                    return
                except Exception as exc:
                    if is_json and method in ("StartCascade", "SendUserCascadeMessage"):
                        sys.stderr.write(
                            f"[Bridge] Upstream {method} transport error ({exc}); falling back to companion session store.\n"
                        )
                        self._handle_standalone_rpc(method, raw_body, content_type)
                        return
                    self._write_json(502, {"error": f"Upstream language_server error: {exc}"})
                    return

        def _normalize_workspace_infos_response(self, resp_bytes: bytes) -> bytes:
            obj = self._parse_json(resp_bytes)
            raw_items = obj.get("workspaceInfos") or obj.get("workspaces") or []
            normalized = []
            for item in raw_items:
                if not isinstance(item, dict):
                    continue
                uri = item.get("workspaceUri") or item.get("workspaceFolderAbsoluteUri") or ""
                if not uri:
                    continue
                enriched = dict(item)
                enriched.setdefault("workspaceUri", uri)
                enriched.setdefault("workspaceFolderAbsoluteUri", uri)
                enriched.setdefault("displayName", Path(uri.replace("file://", "")).name or "workspace")
                enriched.setdefault("activeBranch", item.get("gitBranch") or "main")
                normalized.append(enriched)
            if not normalized:
                with state.lock:
                    normalized = list(state.workspaces)
            obj["workspaces"] = normalized
            obj.setdefault("workspaceInfos", normalized)
            return json.dumps(obj).encode("utf-8")

        def _merge_local_trajectories_response(self, resp_bytes: bytes) -> bytes:
            obj = self._parse_json(resp_bytes)
            summaries = obj.setdefault("trajectorySummaries", {})
            with state.lock:
                for cid, t in state.trajectories.items():
                    if cid == "cas-live-welcome":
                        continue
                    summaries.setdefault(
                        cid,
                        {
                            "summary": t["title"],
                            "stepCount": t["stepCount"],
                            "status": t["status"],
                            "workspaces": [{"workspaceFolderAbsoluteUri": t["workspaceUri"]}],
                        },
                    )
            return json.dumps(obj).encode("utf-8")

        def _merge_local_steps_response(self, req_obj: dict, resp_bytes: bytes) -> bytes:
            obj = self._parse_json(resp_bytes)
            cid = req_obj.get("cascadeId", "")
            if not obj.get("steps") and cid:
                with state.lock:
                    local_steps = state.steps_by_cascade.get(cid)
                    if local_steps:
                        obj["steps"] = list(local_steps)
            return json.dumps(obj).encode("utf-8")

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

    class ReusableThreadingHTTPServer(ThreadingHTTPServer):
        allow_reuse_address = True
        daemon_threads = True

    return ReusableThreadingHTTPServer((bind_host, bind_port), BridgeHandler)


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
        print("[*] Scanning for local Antigravity Desktop `language_server`...", flush=True)
        discovered = discover_local_language_server()
        if discovered:
            upstream_url = discovered["upstream_url"]
            upstream_csrf = discovered["upstream_csrf"]
            print(
                f"[+] Auto-discovered Antigravity Desktop language_server (PID {discovered['pid']}) at {upstream_url}",
                flush=True,
            )
        else:
            print(
                "[!] No running Antigravity Desktop `language_server` detected; starting in Stateful Companion Sandbox mode.",
                flush=True,
            )
            print(
                "    (Open Antigravity Desktop on macOS and re-run to proxy real desktop sessions automatically.)",
                flush=True,
            )

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

    print("\n" + "=" * 74, flush=True)
    print("  iOSAntigravity — Connect-RPC Backend Bridge Ready", flush=True)
    print("=" * 74, flush=True)
    print(f"  Mode          : {'LIVE DESKTOP PROXY -> ' + upstream_url if upstream_url else 'STATEFUL SANDBOX'}", flush=True)
    print(f"  LAN Endpoint  : {endpoint}", flush=True)
    print(f"  CSRF Token    : {bridge_csrf}", flush=True)
    print(f"  iOS Deep Link : {pair_uri}", flush=True)
    print("-" * 74, flush=True)
    print("  Quick CLI Verification (Login + StartCascade + SendUserCascadeMessage):", flush=True)
    print(f"    python3 verification/verify-live-rpc-flow.py --url {endpoint} --csrf {bridge_csrf}", flush=True)
    print("=" * 74 + "\n", flush=True)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down bridge...", flush=True)
        server.shutdown()


if __name__ == "__main__":
    main()
