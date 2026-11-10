#!/usr/bin/env python3
"""Mock Antigravity LanguageServer (`exa.language_server_pb.LanguageServerService`).

Supports the full Connect-RPC & Binary Protobuf E2E surface for iOSAntigravity v2.0:
1. 5-byte Connect streaming envelope (`[flags:1B][length:4B BE][payload]`) for
   `JetboxSubscribeToSummaries` and `StreamCascadeReactiveUpdates`.
2. Binary Protobuf (`Content-Type: application/proto`) for `GetCascadeTrajectorySteps`
   with >600 steps (605 steps default), including field 56 (`requestedInteraction` oneof).
3. Face ID-signed `HandleCascadeUserInteraction` (`runCommand`, `askQuestion`,
   `filePermission`, `permission`, `planReview`).
4. Workspace & Automation RPCs: `CreateProjectWorkspace` (MacBook Pro / Cloud),
   `TriggerAutomationNow`, `CreateAutomation`, `ResumeAutomation`,
   `SendUserCascadeMessage`, `SubmitReviewComments`, and `MarkAllConversationsRead`.
5. CORS headers (`Access-Control-Allow-Origin: *`) so interactive mobile viewport E2E
   tests (`TC-01`..`TC-16`) can dispatch live `fetch()` RPCs directly from the UI.
"""
import json
import struct
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse


def encode_varint(value: int) -> bytes:
    if value == 0:
        return b"\x00"
    out = bytearray()
    while value > 0x7F:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value & 0x7F)
    return bytes(out)


def decode_varint(buf: bytes, offset: int = 0):
    result = 0
    shift = 0
    while offset < len(buf):
        b = buf[offset]
        offset += 1
        result |= (b & 0x7F) << shift
        if (b & 0x80) == 0:
            return result, offset
        shift += 7
    raise ValueError("Truncated varint")


def encode_ld(field_number: int, payload: bytes) -> bytes:
    tag = (field_number << 3) | 2
    return encode_varint(tag) + encode_varint(len(payload)) + payload


def encode_varint_field(field_number: int, value: int) -> bytes:
    tag = (field_number << 3) | 0
    return encode_varint(tag) + encode_varint(value)


def encode_connect_envelope(payload: bytes, flags: int = 0x00) -> bytes:
    return struct.pack(">BI", flags, len(payload)) + payload


def parse_connect_envelopes(raw: bytes):
    offset = 0
    frames = []
    while offset + 5 <= len(raw):
        flags, length = struct.unpack(">BI", raw[offset : offset + 5])
        offset += 5
        payload = raw[offset : offset + length]
        offset += length
        frames.append((flags, payload))
    return frames


def build_sample_binary_steps_response(total_steps: int = 605) -> bytes:
    """Builds a binary Protobuf GetCascadeTrajectoryStepsResponse with >600 steps."""
    out = bytearray()
    for idx in range(total_steps):
        step_buf = bytearray()
        if idx == total_steps - 1:
            # WAITING step (status=9) with requestedInteraction.runCommand (field 23 inside field 56)
            step_buf += encode_varint_field(1, 21)  # CORTEX_STEP_TYPE_RUN_COMMAND
            step_buf += encode_varint_field(4, 9)   # CORTEX_STEP_STATUS_WAITING
            cmd_spec = encode_ld(
                1,
                b"vegeta attack -rate=2000/s -duration=30s -targets=load/transfers.txt | vegeta report",
            )
            req_interaction = encode_ld(23, cmd_spec)
            step_buf += encode_ld(56, req_interaction)
        elif idx == total_steps - 2:
            # Structured ask_question step (field 24 inside field 56)
            step_buf += encode_varint_field(1, 28)  # CORTEX_STEP_TYPE_ASK_QUESTION
            step_buf += encode_varint_field(4, 3)   # CORTEX_STEP_STATUS_DONE
            q_spec = encode_ld(1, b"Which admin actions should be audited?")
            step_buf += encode_ld(56, encode_ld(24, q_spec))
        else:
            step_buf += encode_varint_field(1, 15)  # CORTEX_STEP_TYPE_PLANNER_RESPONSE
            step_buf += encode_varint_field(4, 3)   # CORTEX_STEP_STATUS_DONE
            planner = encode_ld(1, f"Step {idx} completed.".encode("utf-8")) + encode_ld(
                3, b"Isolating fake clock & verifying rate limiter"
            )
            step_buf += encode_ld(20, planner)
        out += encode_ld(1, bytes(step_buf))
    return bytes(out)


class MockServerState:
    def __init__(self):
        self.lock = threading.Lock()
        self.rpc_log = []
        self.unread_count = 3
        self.projects = [
            {
                "id": "proj-ledger-svc",
                "name": "ledger-svc",
                "path": "~/code/ledger-svc",
                "runtime": "macbook_pro",
                "sourceType": "github",
                "repository": "acme/ledger-svc",
                "branch": "main",
                "conversationCount": 5,
            },
            {
                "id": "proj-web-console",
                "name": "web-console",
                "path": "cloud://acme/web-console",
                "runtime": "cloud",
                "sourceType": "github",
                "repository": "acme/web-console",
                "branch": "main",
                "conversationCount": 3,
            },
        ]
        self.automations = [
            {
                "id": "auto-nightly-audit",
                "title": "Nightly dependency audit",
                "project": "ledger-svc",
                "schedule": "Daily at 02:00",
                "model": "Flash",
                "state": "scheduled",
                "nextRun": "Tonight, 02:00",
                "lastRun": "Succeeded · 22h ago",
                "runCount": 14,
            },
            {
                "id": "auto-weekly-flaky",
                "title": "Weekly flaky-test report",
                "project": "ledger-svc",
                "schedule": "Mondays at 09:00",
                "model": "Pro",
                "state": "scheduled",
                "nextRun": "Mon, 09:00",
                "lastRun": "Needs review · 2d",
                "runCount": 6,
            },
            {
                "id": "auto-pr-triage",
                "title": "Triage new pull requests",
                "project": "web-console",
                "schedule": "On PR opened",
                "model": "Flash Lite",
                "state": "always_on",
                "lastRun": "Last run 14m ago",
                "runCount": 42,
            },
            {
                "id": "auto-bundle-watch",
                "title": "Bundle size watch",
                "project": "web-console",
                "schedule": "Daily at 08:00",
                "model": "Flash",
                "state": "paused",
                "lastRun": "Paused 3d ago",
                "runCount": 9,
            },
        ]
        self.interactions = []
        self.messages = []
        self.reviews = []

    def record(self, method: str, payload: dict):
        with self.lock:
            self.rpc_log.append({"method": method, "payload": payload})


class LiveMockServer:
    def __init__(self):
        self.state = MockServerState()
        outer_state = self.state

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, fmt, *args):
                pass

            def _send_cors_headers(self):
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header(
                    "Access-Control-Allow-Methods", "GET, POST, OPTIONS"
                )
                self.send_header(
                    "Access-Control-Allow-Headers",
                    "Content-Type, Accept, Connect-Protocol-Version, X-FaceID-Signature",
                )

            def do_OPTIONS(self):
                self.send_response(204)
                self._send_cors_headers()
                self.send_header("Content-Length", "0")
                self.end_headers()

            def do_GET(self):
                if self.path == "/__mock_state":
                    with outer_state.lock:
                        snapshot = {
                            "unreadCount": outer_state.unread_count,
                            "projectCount": len(outer_state.projects),
                            "projects": list(outer_state.projects),
                            "automations": list(outer_state.automations),
                            "interactionCount": len(outer_state.interactions),
                            "messageCount": len(outer_state.messages),
                            "reviewCount": len(outer_state.reviews),
                            "rpcLog": list(outer_state.rpc_log),
                        }
                    self._send_json(200, snapshot)
                    return
                self._send_json(404, {"error": "Not found"})

            def do_POST(self):
                path = urlparse(self.path).path
                content_len = int(self.headers.get("Content-Length", "0"))
                body = self.rfile.read(content_len) if content_len > 0 else b""
                prefix = "/exa.language_server_pb.LanguageServerService/"

                if not path.startswith(prefix):
                    self._send_json(404, {"error": f"Unknown service path: {path}"})
                    return

                method = path[len(prefix) :]

                if method == "JetboxSubscribeToSummaries":
                    outer_state.record(method, {"framedBytes": len(body)})
                    snapshot = {
                        "host": {"name": "MacBook Pro", "online": True, "version": "v2.30.0"},
                        "summaries": [
                            {
                                "cascadeId": "cas-rate-limiter",
                                "title": "Add rate limiter to /transfers",
                                "project": "ledger-svc",
                                "workspaceUri": "file:///Users/dev/code/ledger-svc",
                                "branchName": "main",
                                "status": "CORTEX_STEP_STATUS_IN_PROGRESS",
                                "stepIndex": 4,
                                "stepTotal": 7,
                                "currentCommand": "go test ./internal/...",
                                "isPinned": True,
                                "unread": False,
                                "diffAdditions": 128,
                                "diffDeletions": 14,
                            },
                            {
                                "cascadeId": "cas-release-v23",
                                "title": "Release checklist v2.3",
                                "project": "web-console",
                                "workspaceUri": "cloud://acme/web-console",
                                "branchName": "main",
                                "status": "CORTEX_STEP_STATUS_DONE",
                                "subtitle": "Done · Walkthrough ready",
                                "isPinned": True,
                                "unread": False,
                            },
                            {
                                "cascadeId": "cas-flaky-settlement",
                                "title": "Fix flaky TestSettlementBatch",
                                "project": "ledger-svc",
                                "workspaceUri": "file:///Users/dev/code/ledger-svc",
                                "branchName": "main",
                                "status": "CORTEX_STEP_STATUS_WAITING",
                                "pendingInteractionTitle": "Needs review · Implementation plan ready",
                                "isPinned": False,
                                "unread": True,
                            },
                            {
                                "cascadeId": "cas-go-125",
                                "title": "Upgrade to Go 1.25",
                                "project": "ledger-svc",
                                "workspaceUri": "file:///Users/dev/code/ledger-svc",
                                "branchName": "main",
                                "status": "CORTEX_STEP_STATUS_DONE",
                                "diffAdditions": 42,
                                "diffDeletions": 31,
                                "isPinned": False,
                                "unread": True,
                            },
                            {
                                "cascadeId": "cas-idempotency",
                                "title": "Idempotency keys for payouts",
                                "project": "ledger-svc",
                                "workspaceUri": "file:///Users/dev/code/ledger-svc",
                                "branchName": "main",
                                "status": "CORTEX_STEP_STATUS_DONE",
                                "subtitle": "Done · Merged into main",
                                "isPinned": False,
                                "unread": True,
                            },
                        ],
                    }
                    delta = {
                        "delta": {
                            "cascadeId": "cas-rate-limiter",
                            "stepIndex": 5,
                            "stepTotal": 7,
                            "status": "CORTEX_STEP_STATUS_WAITING",
                            "pendingCommand": "vegeta attack -rate=2000/s -duration=30s",
                        }
                    }
                    stream_bytes = (
                        encode_connect_envelope(
                            json.dumps(snapshot).encode("utf-8"), flags=0x00
                        )
                        + encode_connect_envelope(
                            json.dumps(delta).encode("utf-8"), flags=0x00
                        )
                        + encode_connect_envelope(b"{}", flags=0x02)
                    )
                    self.send_response(200)
                    self._send_cors_headers()
                    self.send_header("Content-Type", "application/connect+json")
                    self.send_header("Content-Length", str(len(stream_bytes)))
                    self.end_headers()
                    self.wfile.write(stream_bytes)
                    return

                if method == "GetCascadeTrajectorySteps":
                    content_type = self.headers.get("Content-Type", "")
                    outer_state.record(method, {"contentType": content_type})
                    if "application/proto" in content_type:
                        proto_bytes = build_sample_binary_steps_response(total_steps=605)
                        self.send_response(200)
                        self._send_cors_headers()
                        self.send_header("Content-Type", "application/proto")
                        self.send_header("Content-Length", str(len(proto_bytes)))
                        self.end_headers()
                        self.wfile.write(proto_bytes)
                    else:
                        self._send_json(200, {"steps": [], "truncatedAt": 600})
                    return

                req = {}
                if body:
                    try:
                        req = json.loads(body.decode("utf-8"))
                    except Exception:
                        req = {}

                if method == "HandleCascadeUserInteraction":
                    interaction = req.get("interaction", {})
                    valid_members = {
                        "permission",
                        "filePermission",
                        "runCommand",
                        "askQuestion",
                        "planReview",
                        "deploy",
                    }
                    matched = sorted(valid_members.intersection(interaction.keys()))
                    if not matched:
                        self._send_json(
                            400,
                            {
                                "accepted": False,
                                "reason": "Missing authoritative requestedInteraction oneof member",
                            },
                        )
                        return

                    oneof_name = matched[0]
                    faceid_sig = (
                        self.headers.get("X-FaceID-Signature")
                        or interaction.get("faceIdSignature")
                        or ("LAContext-biometric-ok" if interaction.get("biometricConfirmed") else None)
                    )

                    if oneof_name == "runCommand":
                        rc = interaction["runCommand"]
                        if rc.get("confirm") is True and not faceid_sig:
                            self._send_json(
                                403,
                                {
                                    "accepted": False,
                                    "reason": "Face ID hardware presence signature required for command approval",
                                },
                            )
                            return

                    ack = {
                        "accepted": True,
                        "matchedOneof": oneof_name,
                        "faceIdVerified": bool(faceid_sig),
                        "trajectoryId": interaction.get("trajectoryId", "cas-rate-limiter"),
                        "stepIndex": interaction.get("stepIndex", 5),
                        "newStatus": "CORTEX_STEP_STATUS_RUNNING",
                    }
                    with outer_state.lock:
                        outer_state.interactions.append(ack)
                    outer_state.record(method, req)
                    self._send_json(200, ack)
                    return

                if method == "CreateProjectWorkspace":
                    runtime = req.get("runtime", "cloud")
                    source_type = req.get("sourceType", "github")
                    repo_name = req.get("repository", "acme/ledger-svc")
                    proj_name = req.get("name") or (
                        f"{repo_name.split('/')[-1]}-cloud"
                        if runtime == "cloud"
                        else repo_name.split("/")[-1]
                    )
                    new_proj = {
                        "id": f"proj-{proj_name}",
                        "name": proj_name,
                        "path": f"cloud://{repo_name}" if runtime == "cloud" else f"~/code/{proj_name}",
                        "runtime": runtime,
                        "sourceType": source_type,
                        "repository": repo_name,
                        "branch": req.get("branch", "main"),
                        "worktree": req.get("worktree", "new"),
                        "conversationCount": 0,
                    }
                    with outer_state.lock:
                        outer_state.projects.append(new_proj)
                    outer_state.record(method, req)
                    self._send_json(200, {"ok": True, "project": new_proj})
                    return

                if method == "TriggerAutomationNow":
                    auto_id = req.get("automationId", "auto-nightly-audit")
                    triggered = None
                    with outer_state.lock:
                        for item in outer_state.automations:
                            if item["id"] == auto_id:
                                item["lastRun"] = "Running now · triggered"
                                item["runCount"] = item.get("runCount", 0) + 1
                                triggered = dict(item)
                                break
                    outer_state.record(method, req)
                    self._send_json(
                        200,
                        {
                            "ok": True,
                            "automationId": auto_id,
                            "status": "RUNNING",
                            "automation": triggered,
                        },
                    )
                    return

                if method == "CreateAutomation":
                    prompt = req.get("prompt", "Every weekday at 9, summarize")
                    created = {
                        "id": f"auto-custom-{len(outer_state.automations) + 1}",
                        "title": prompt,
                        "project": req.get("project", "ledger-svc"),
                        "schedule": req.get("schedule", "Weekdays at 09:00"),
                        "model": req.get("model", "Flash"),
                        "state": "scheduled",
                        "nextRun": "Tomorrow, 09:00",
                        "lastRun": "Just created",
                        "runCount": 0,
                    }
                    with outer_state.lock:
                        outer_state.automations.insert(0, created)
                    outer_state.record(method, req)
                    self._send_json(200, {"ok": True, "automation": created})
                    return

                if method == "ResumeAutomation":
                    auto_id = req.get("automationId", "auto-bundle-watch")
                    resumed = None
                    with outer_state.lock:
                        for item in outer_state.automations:
                            if item["id"] == auto_id:
                                item["state"] = "scheduled"
                                item["lastRun"] = "Resumed · Ready"
                                resumed = dict(item)
                                break
                    outer_state.record(method, req)
                    self._send_json(200, {"ok": True, "automation": resumed})
                    return

                if method == "MarkAllConversationsRead":
                    with outer_state.lock:
                        outer_state.unread_count = 0
                    outer_state.record(method, req)
                    self._send_json(200, {"ok": True, "unreadCount": 0})
                    return

                if method == "SendUserCascadeMessage":
                    msg = {
                        "cascadeId": req.get("cascadeId", "cas-rate-limiter"),
                        "text": req.get("text", ""),
                        "contextChips": req.get("contextChips", []),
                        "mode": req.get("mode", "Planning"),
                        "model": req.get("model", "Gemini 3.1 Pro"),
                    }
                    with outer_state.lock:
                        outer_state.messages.append(msg)
                    outer_state.record(method, req)
                    self._send_json(200, {"ok": True, "turnId": len(outer_state.messages), "message": msg})
                    return

                if method == "SubmitReviewComments":
                    with outer_state.lock:
                        outer_state.reviews.append(req)
                    outer_state.record(method, req)
                    self._send_json(
                        200,
                        {
                            "ok": True,
                            "submittedCount": len(req.get("comments", [])) or 1,
                        },
                    )
                    return

                outer_state.record(method, req)
                self._send_json(200, {"ok": True, "method": method})

            def _send_json(self, status: int, data: dict):
                raw = json.dumps(data).encode("utf-8")
                self.send_response(status)
                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.port = self.server.server_port
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.server.shutdown()
        self.server.server_close()
