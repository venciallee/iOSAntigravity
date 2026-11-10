#!/usr/bin/env python3
"""Unified ESDD End-to-End Verification & Visual Screenshot Runner (`esdd-verify.py`).

Executes the 4-stage ESDD pipeline:
1. Spec-DAG & Swift Source Contract Inspection (`esdd_inspector.py`).
2. Live Connect-RPC Protocol E2E Verification against `mock_language_server.py`:
   - 5-byte Connect streaming envelope (`JetboxSubscribeToSummaries`)
   - Binary Protobuf trajectory steps (`GetCascadeTrajectorySteps` >600 step ceiling)
   - Authoritative oneof matching (`HandleCascadeUserInteraction`)
3. Pixel-Accurate iOS 18 / iPhone 16 Pro (`393x852pt @3x` = `1179x2556px`) Visual Rendering
   & Automated Accessibility / HIG Geometry Audit (`>=44pt` touch targets, zero overflow).
4. Generates a composite 8-screen gallery (`ESDD_ALL_SCREENS_OVERVIEW.png`), individual
   `@3x` screenshots, `results.json`, and `report.md`.
"""
import json
import shutil
import subprocess
import threading
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from PIL import Image, ImageDraw

from esdd_inspector import inspect_esdd_spec_and_swift_contracts
from mock_language_server import (
    LiveMockServer,
    decode_varint,
    encode_connect_envelope,
    parse_connect_envelopes,
)
from ui_renderer import render_scene_html


def run_connect_rpc_e2e_tests(port: int) -> dict:
    base = f"http://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService"
    results = []

    # Test 1: JetboxSubscribeToSummaries 5-byte Connect streaming envelope
    req = urllib.request.Request(
        f"{base}/JetboxSubscribeToSummaries",
        data=encode_connect_envelope(b"{}"),
        headers={"Content-Type": "application/connect+json", "Connect-Protocol-Version": "1"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        raw = resp.read()
        frames = parse_connect_envelopes(raw)
        assert len(frames) == 3, f"Expected 3 envelope frames, got {len(frames)}"
        assert frames[0][0] == 0x00 and frames[2][0] == 0x02
        snapshot = json.loads(frames[0][1].decode("utf-8"))
        assert len(snapshot["summaries"]) == 3
        results.append(
            "JetboxSubscribeToSummaries: parsed 3 Connect 5-byte frames (snapshot + delta + 0x02 EndStream)"
        )

    # Test 2: GetCascadeTrajectorySteps binary Protobuf (>600 steps)
    req_proto = urllib.request.Request(
        f"{base}/GetCascadeTrajectorySteps",
        data=b"\x0a\x0e" + b"cas-01-waiting" + b"\x10\x00\x18\xdd\x04",
        headers={"Content-Type": "application/proto", "Accept": "application/proto"},
        method="POST",
    )
    with urllib.request.urlopen(req_proto, timeout=5) as resp:
        proto_bytes = resp.read()
        # Count top-level field 1 (tag 0x0A) messages
        offset = 0
        step_count = 0
        while offset < len(proto_bytes):
            tag, offset = decode_varint(proto_bytes, offset)
            length, offset = decode_varint(proto_bytes, offset)
            offset += length
            if (tag >> 3) == 1:
                step_count += 1
        assert step_count == 605, f"Expected 605 binary protobuf steps, got {step_count}"
        results.append(
            f"GetCascadeTrajectorySteps (application/proto): decoded {step_count} steps (bypassed 600-step JSON ceiling)"
        )

    # Test 3: HandleCascadeUserInteraction authoritative oneof member
    interaction_body = json.dumps(
        {
            "interaction": {
                "trajectoryId": "cas-01-waiting",
                "stepIndex": 24,
                "permission": {
                    "allow": True,
                    "turnGrants": {"allow": ["execute(verification/*)"], "deny": []},
                },
            }
        }
    ).encode("utf-8")
    req_inter = urllib.request.Request(
        f"{base}/HandleCascadeUserInteraction",
        data=interaction_body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req_inter, timeout=5) as resp:
        ack = json.loads(resp.read().decode("utf-8"))
        assert ack["accepted"] is True and ack["matchedOneof"] == "permission"
        results.append(
            "HandleCascadeUserInteraction: verified authoritative oneof 'permission' with turnGrants"
        )

    return {"passed": True, "tests": results}


class SceneRenderServer:
    def __init__(self, claims_by_state: dict):
        self.claims_by_state = claims_by_state
        self.ax_reports = {}

        outer = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, fmt, *args):
                pass

            def do_GET(self):
                if self.path.startswith("/scene/"):
                    state_id = self.path.split("/scene/")[1].split("?")[0]
                    claim = outer.claims_by_state[state_id]
                    selectors = list(
                        dict.fromkeys(
                            claim.get("requiredSelectors", [])
                            + claim.get("minTouchTargetSelectors", [])
                        )
                    )
                    html = render_scene_html(state_id, selectors).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Content-Length", str(len(html)))
                    self.end_headers()
                    self.wfile.write(html)
                else:
                    self.send_response(404)
                    self.end_headers()

            def do_POST(self):
                if self.path == "/__esdd_ax_report":
                    length = int(self.headers.get("Content-Length", "0"))
                    raw = self.rfile.read(length)
                    data = json.loads(raw.decode("utf-8"))
                    outer.ax_reports[data["stateId"]] = data
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"ok")
                else:
                    self.send_response(404)
                    self.end_headers()

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        self.port = self.server.server_port
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.server.shutdown()
        self.server.server_close()


def build_overview_grid(screenshot_paths: list, output_path: Path):
    """Builds a 4x2 high-resolution overview grid of all 8 ESDD iOS screens."""
    cols, rows = 4, 2
    thumb_w, thumb_h = 393, 852
    pad = 24
    header_h = 84
    canvas_w = cols * thumb_w + (cols + 1) * pad
    canvas_h = header_h + rows * thumb_h + (rows + 1) * pad

    grid = Image.new("RGB", (canvas_w, canvas_h), (7, 9, 14))
    draw = ImageDraw.Draw(grid)
    draw.text(
        (pad, 28),
        "iOSAntigravity - ESDD End-to-End Visual Verification Suite (8 States | iPhone 16 Pro 393x852pt @3x)",
        fill=(248, 250, 252),
    )

    for idx, (state_id, img_path) in enumerate(screenshot_paths):
        r = idx // cols
        c = idx % cols
        x = pad + c * (thumb_w + pad)
        y = header_h + pad + r * (thumb_h + pad)
        with Image.open(img_path) as im:
            resized = im.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            grid.paste(resized, (x, y))
        draw.rectangle(
            [x - 1, y - 1, x + thumb_w + 1, y + thumb_h + 1],
            outline=(99, 102, 241),
            width=2,
        )

    grid.save(output_path, format="PNG")


def main():
    repo_root = Path(__file__).resolve().parents[1]
    ir = json.loads((repo_root / "specs" / "esdd-ir.json").read_text(encoding="utf-8"))
    out_dir = repo_root / "verification" / "output"
    shots_dir = out_dir / "screenshots"
    ax_dir = out_dir / "ax_trees"
    shots_dir.mkdir(parents=True, exist_ok=True)
    ax_dir.mkdir(parents=True, exist_ok=True)

    print("=== [Stage 1/4] ESDD Spec-DAG & Swift Source Contract Inspection ===")
    spec_report = inspect_esdd_spec_and_swift_contracts(repo_root)
    for chk in spec_report["checks"]:
        print(f"  ✓ {chk}")
    if not spec_report["passed"]:
        raise SystemExit(f"Spec inspection failed: {spec_report['errors']}")

    print("\n=== [Stage 2/4] Connect-RPC E2E Protocol Verification ===")
    with LiveMockServer() as mock_ls:
        rpc_report = run_connect_rpc_e2e_tests(mock_ls.port)
        for t in rpc_report["tests"]:
            print(f"  ✓ {t}")

    print("\n=== [Stage 3/4] iOS 18 (@3x) Visual Rendering & HIG Geometry Audit ===")
    claims = ir["claims"]
    claims_by_state = {c["state"]: c for c in claims}
    chromium_bin = shutil.which("chromium") or shutil.which("google-chrome")
    if not chromium_bin:
        raise RuntimeError("Chromium not found for screenshot verification")

    claim_results = []
    screenshot_entries = []

    with SceneRenderServer(claims_by_state) as scene_srv:
        for claim in claims:
            state_id = claim["state"]
            png_path = shots_dir / f"{state_id}.png"
            url = f"http://127.0.0.1:{scene_srv.port}/scene/{state_id}"
            cmd = [
                chromium_bin,
                "--headless",
                "--no-sandbox",
                "--disable-gpu",
                "--hide-scrollbars",
                "--window-size=393,852",
                "--force-device-scale-factor=3",
                f"--screenshot={png_path}",
                url,
            ]
            subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            with Image.open(png_path) as im:
                px_w, px_h = im.size

            ax = scene_srv.ax_reports.get(state_id, {})
            ax_path = ax_dir / f"{state_id}.json"
            ax_path.write_text(json.dumps(ax, indent=2), encoding="utf-8")

            violations = []
            if (px_w, px_h) != (1179, 2556):
                violations.append(f"Expected @3x resolution 1179x2556, got {px_w}x{px_h}")

            if ax.get("scrollWidth", 393) > 393:
                violations.append(f"Horizontal overflow detected: scrollWidth={ax.get('scrollWidth')}")

            elements = ax.get("elements", {})
            for req_sel in claim["requiredSelectors"]:
                info = elements.get(req_sel, {})
                if not info.get("exists"):
                    violations.append(f"Missing required selector {req_sel}")

            for touch_sel in claim["minTouchTargetSelectors"]:
                info = elements.get(touch_sel, {})
                if not info.get("exists"):
                    violations.append(f"Missing touch target selector {touch_sel}")
                else:
                    if info["height"] < 44 or info["width"] < 44:
                        violations.append(
                            f"HIG 44pt violation on {touch_sel}: {info['width']}x{info['height']}pt"
                        )

            passed = len(violations) == 0
            status_str = "PASS" if passed else f"FAIL ({violations})"
            print(
                f"  ✓ [{claim['id']}] {state_id} -> {png_path.name} ({px_w}x{px_h}px) · HIG Audit: {status_str}"
            )
            if not passed:
                raise SystemExit(f"ESDD HIG Audit failed on {state_id}: {violations}")

            screenshot_entries.append((state_id, png_path))
            claim_results.append(
                {
                    "claimId": claim["id"],
                    "state": state_id,
                    "category": claim["category"],
                    "passed": passed,
                    "screenshot": str(png_path.relative_to(repo_root)),
                    "resolutionPx": f"{px_w}x{px_h}",
                    "axSnapshot": str(ax_path.relative_to(repo_root)),
                    "verifiedSelectors": len(claim["requiredSelectors"]),
                    "verifiedTouchTargets": len(claim["minTouchTargetSelectors"]),
                }
            )

    overview_path = shots_dir / "ESDD_ALL_SCREENS_OVERVIEW.png"
    build_overview_grid(screenshot_entries, overview_path)
    print(f"\n=== [Stage 4/4] Composite Overview Saved: {overview_path.relative_to(repo_root)} ===")

    summary_payload = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "methodology": "ESDD (Executable Spec Driven Development)",
        "overallPassed": True,
        "specInspection": spec_report,
        "connectRpcE2E": rpc_report,
        "claims": claim_results,
    }
    (out_dir / "results.json").write_text(json.dumps(summary_payload, indent=2), encoding="utf-8")

    report_lines = [
        "# iOSAntigravity — ESDD End-to-End Acceptance Report",
        "",
        f"- **Status**: ✅ ALL 8 CLAIMS PASSED (Zero Evidence Gaps)",
        f"- **Device Baseline**: iPhone 16 Pro (`393×852pt @3x` → `1179×2556px`)",
        f"- **Connect-RPC E2E**: 5-byte streaming envelope + 605-step binary Protobuf + `RequestedInteraction` oneof verified",
        "",
        "## Claim Verification Matrix",
        "",
        "| Claim | State | Category | Resolution | HIG >=44pt Targets | Status |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |",
    ]
    for cr in claim_results:
        report_lines.append(
            f"| `{cr['claimId']}` | `{cr['state']}` | {cr['category']} | `{cr['resolutionPx']}` | {cr['verifiedTouchTargets']} verified | ✅ PASS |"
        )
    (out_dir / "report.md").write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    print(f"=== ESDD Report Written: {(out_dir / 'report.md').relative_to(repo_root)} ===")


if __name__ == "__main__":
    main()
