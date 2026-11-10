#!/usr/bin/env python3
"""Mock Antigravity LanguageServer (`exa.language_server_pb.LanguageServerService`).

Speaks the real Connect-RPC protocol used by `language_server --standalone --subclient_type hub`:
1. 5-byte Connect streaming envelope (`[flags:1B][length:4B BE][payload]`) for `JetboxSubscribeToSummaries`
   and `StreamCascadeReactiveUpdates`.
2. Binary Protobuf (`Content-Type: application/proto`) for `GetCascadeTrajectorySteps` (>600 step support),
   including field 56 (`requestedInteraction` oneof).
3. Authoritative oneof validation for `HandleCascadeUserInteraction`.
"""
import json
import struct
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
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
            # WAITING step (status=9) with requestedInteraction.permission (field 21 inside field 56)
            step_buf += encode_varint_field(1, 21)  # CORTEX_STEP_TYPE_RUN_COMMAND
            step_buf += encode_varint_field(4, 9)   # CORTEX_STEP_STATUS_WAITING
            perm_spec = encode_ld(2, b"verification/*")
            req_interaction = encode_ld(21, perm_spec)
            step_buf += encode_ld(56, req_interaction)
        else:
            step_buf += encode_varint_field(1, 15)  # CORTEX_STEP_TYPE_PLANNER_RESPONSE
            step_buf += encode_varint_field(4, 3)   # CORTEX_STEP_STATUS_DONE
            planner = encode_ld(1, f"Step {idx} completed.".encode("utf-8")) + encode_ld(
                3, b"Checking Connect-RPC invariants"
            )
            step_buf += encode_ld(20, planner)
        out += encode_ld(1, bytes(step_buf))
    return bytes(out)


class MockLanguageServerHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

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
            snapshot = {
                "summaries": [
                    {
                        "cascadeId": "cas-01-waiting",
                        "title": "Implement Native Connect-RPC & Live Activity",
                        "workspaceUri": "file:///home/antigravity/venciallee/iOSAntigravity",
                        "branchName": "feat/connect-rpc-client",
                        "status": "CORTEX_STEP_STATUS_WAITING",
                        "stepCount": 24,
                        "isPinned": True,
                        "pendingInteractionTitle": "Approve command: python3 verification/esdd-verify.py",
                    },
                    {
                        "cascadeId": "cas-02-running",
                        "title": "Audit CoreText 120fps Streaming Cell Layout",
                        "workspaceUri": "file:///home/antigravity/venciallee/iOSAntigravity",
                        "branchName": "feat/live-activity",
                        "status": "CORTEX_STEP_STATUS_IN_PROGRESS",
                        "stepCount": 14,
                        "isPinned": True,
                    },
                    {
                        "cascadeId": "cas-03-done",
                        "title": "Decode Binary Protobuf Trajectory Steps (>600 ceiling)",
                        "workspaceUri": "file:///home/antigravity/venciallee/iOSAntigravity",
                        "branchName": "main",
                        "status": "CORTEX_STEP_STATUS_DONE",
                        "stepCount": 642,
                        "isPinned": False,
                    },
                ]
            }
            delta = {
                "delta": {
                    "cascadeId": "cas-02-running",
                    "stepCount": 15,
                    "status": "CORTEX_STEP_STATUS_IN_PROGRESS",
                }
            }
            stream_bytes = (
                encode_connect_envelope(json.dumps(snapshot).encode("utf-8"), flags=0x00)
                + encode_connect_envelope(json.dumps(delta).encode("utf-8"), flags=0x00)
                + encode_connect_envelope(b"{}", flags=0x02)
            )
            self.send_response(200)
            self.send_header("Content-Type", "application/connect+json")
            self.send_header("Content-Length", str(len(stream_bytes)))
            self.end_headers()
            self.wfile.write(stream_bytes)
            return

        if method == "GetCascadeTrajectorySteps":
            content_type = self.headers.get("Content-Type", "")
            if "application/proto" in content_type:
                proto_bytes = build_sample_binary_steps_response(total_steps=605)
                self.send_response(200)
                self.send_header("Content-Type", "application/proto")
                self.send_header("Content-Length", str(len(proto_bytes)))
                self.end_headers()
                self.wfile.write(proto_bytes)
            else:
                self._send_json(200, {"steps": [], "truncatedAt": 600})
            return

        if method == "HandleCascadeUserInteraction":
            req = json.loads(body.decode("utf-8") or "{}")
            interaction = req.get("interaction", {})
            # Authoritative oneof gate validation: must carry a recognized interaction member
            valid_members = {"permission", "filePermission", "runCommand", "askQuestion", "deploy"}
            matched = valid_members.intersection(interaction.keys())
            if not matched:
                self._send_json(400, {"accepted": False, "reason": "Missing authoritative requestedInteraction oneof member"})
                return
            self._send_json(
                200,
                {
                    "accepted": True,
                    "matchedOneof": sorted(matched)[0],
                    "trajectoryId": interaction.get("trajectoryId"),
                    "stepIndex": interaction.get("stepIndex"),
                },
            )
            return

        if method == "GetWorkspaceInfos":
            self._send_json(
                200,
                {
                    "host": "lt74xt6l0m-golden-star",
                    "version": "v2.30.0",
                    "workspaces": [
                        {
                            "workspaceUri": "file:///home/antigravity/venciallee/iOSAntigravity",
                            "displayName": "venciallee/iOSAntigravity",
                            "activeBranch": "feat/connect-rpc-client",
                            "worktrees": ["main", "feat/connect-rpc-client", "feat/live-activity"],
                        }
                    ],
                },
            )
            return

        self._send_json(200, {"ok": True, "method": method})

    def _send_json(self, status: int, data: dict):
        raw = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


class LiveMockServer:
    def __init__(self):
        self.server = HTTPServer(("127.0.0.1", 0), MockLanguageServerHandler)
        self.port = self.server.server_port
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.server.shutdown()
        self.server.server_close()
