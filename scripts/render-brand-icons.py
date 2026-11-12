#!/usr/bin/env python3
"""Render 100% original AG Orbit iOS 18 AppIcon (Light, Dark, Tinted 1024x1024 opaque sRGB)
and in-app About/Copyright icon preview assets.

Copyright (c) 2026 iOSAntigravity Contributors. All rights reserved.
Contains 100% original geometric vector artwork aligned with the Matte Obsidian (#090A0D),
Periwinkle (#8EB4FF), and Warm Amber (#EBB365) UE design tokens — zero third-party or
Google LLC trademarked graphic assets.
"""
import base64
import io
import json
import shutil
import socket
import subprocess
import time
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

from PIL import Image
from wsproto import ConnectionType, WSConnection
from wsproto.events import AcceptConnection, Message, Ping, Request


def find_chromium() -> str:
    for candidate in ("chromium", "chromium-browser", "google-chrome"):
        path = shutil.which(candidate)
        if path:
            return path
    raise RuntimeError("Headless Chromium not found on PATH")


def render_html_to_rgb_png(chromium_bin: str, html: str, size: int = 1024) -> Image.Image:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]

    proc = subprocess.Popen(
        [
            chromium_bin,
            "--headless",
            "--no-sandbox",
            "--disable-gpu",
            "--hide-scrollbars",
            "--disable-dev-shm-usage",
            f"--remote-debugging-port={port}",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    sock = None
    try:
        ws_url = None
        for _ in range(60):
            try:
                targets = json.loads(
                    urllib.request.urlopen(f"http://127.0.0.1:{port}/json/list", timeout=1).read()
                )
                for t in targets:
                    if t.get("type") == "page" and t.get("webSocketDebuggerUrl"):
                        ws_url = t["webSocketDebuggerUrl"]
                        break
                if ws_url:
                    break
            except Exception:
                time.sleep(0.1)
        if not ws_url:
            raise RuntimeError("Failed to attach to Headless Chromium CDP target")

        parsed = urlparse(ws_url)
        sock = socket.create_connection((parsed.hostname, parsed.port), timeout=15)
        ws = WSConnection(ConnectionType.CLIENT)
        target_path = parsed.path + (f"?{parsed.query}" if parsed.query else "")
        sock.sendall(ws.send(Request(host=f"{parsed.hostname}:{parsed.port}", target=target_path)))

        accepted = False
        while not accepted:
            ws.receive_data(sock.recv(65536))
            for ev in ws.events():
                if isinstance(ev, AcceptConnection):
                    accepted = True

        msg_id = 0
        rx_buf = ""

        def cdp(method: str, params: dict = None) -> dict:
            nonlocal msg_id, rx_buf
            msg_id += 1
            req_id = msg_id
            sock.sendall(ws.send(Message(data=json.dumps({"id": req_id, "method": method, "params": params or {}}))))
            while True:
                for ev in ws.events():
                    if isinstance(ev, Ping):
                        sock.sendall(ws.send(ev.response()))
                    elif isinstance(ev, Message):
                        rx_buf += ev.data
                        if ev.message_finished:
                            raw = rx_buf
                            rx_buf = ""
                            resp = json.loads(raw)
                            if resp.get("id") == req_id:
                                if "error" in resp:
                                    raise RuntimeError(f"CDP {method} error: {resp['error']}")
                                return resp.get("result", {})
                ws.receive_data(sock.recv(65536))

        cdp("Page.enable")
        cdp(
            "Emulation.setDeviceMetricsOverride",
            {"width": size, "height": size, "deviceScaleFactor": 1, "mobile": False},
        )
        frame_tree = cdp("Page.getFrameTree")
        frame_id = frame_tree["frameTree"]["frame"]["id"]
        cdp("Page.setDocumentContent", {"frameId": frame_id, "html": html})
        time.sleep(0.15)
        shot = cdp(
            "Page.captureScreenshot",
            {"format": "png", "clip": {"x": 0, "y": 0, "width": size, "height": size, "scale": 1}},
        )
        png_bytes = base64.b64decode(shot["data"])
        return Image.open(io.BytesIO(png_bytes)).convert("RGB")
    finally:
        if sock:
            try:
                sock.close()
            except Exception:
                pass
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()


DARK_HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  html, body {{
    width: 1024px;
    height: 1024px;
    overflow: hidden;
    background:
      radial-gradient(circle at 50% 42%, rgba(142, 180, 255, 0.16) 0%, rgba(142, 180, 255, 0.0) 62%),
      linear-gradient(180deg, #151823 0%, #090A0D 100%);
    display: flex;
    align-items: center;
    justify-content: center;
  }}
  svg {{ width: 1024px; height: 1024px; display: block; }}
</style>
</head>
<body>
{svg}
</body>
</html>
"""

LIGHT_HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  html, body {{
    width: 1024px;
    height: 1024px;
    overflow: hidden;
    background:
      radial-gradient(circle at 50% 35%, #FFFFFF 0%, #EDF2FC 68%, #DFE8FA 100%);
    display: flex;
    align-items: center;
    justify-content: center;
  }}
  .disc {{
    width: 828px;
    height: 828px;
    border-radius: 50%;
    background:
      radial-gradient(circle at 50% 38%, #1C2130 0%, #0D1017 100%);
    box-shadow:
      0 28px 64px rgba(18, 32, 68, 0.22),
      0 6px 18px rgba(18, 32, 68, 0.12),
      inset 0 2px 3px rgba(255, 255, 255, 0.18);
    display: flex;
    align-items: center;
    justify-content: center;
  }}
  .disc svg {{ width: 920px; height: 920px; flex: none; }}
</style>
</head>
<body>
  <div class="disc">{svg}</div>
</body>
</html>
"""

TINTED_HTML = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  html, body {
    width: 1024px;
    height: 1024px;
    overflow: hidden;
    background: #000000;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  svg { width: 1024px; height: 1024px; display: block; }
</style>
</head>
<body>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" fill="none">
  <circle cx="512" cy="512" r="324"
    stroke="#FFFFFF" stroke-opacity="0.30" stroke-width="48" stroke-linecap="round"
    stroke-dasharray="224 66.822 224 1600"
    transform="rotate(337.143 512 512)" />
  <circle cx="512" cy="512" r="324"
    stroke="#FFFFFF" stroke-width="48" stroke-linecap="round"
    stroke-dasharray="224 66.822 224 66.822 224 66.822 224 66.822 224 700"
    transform="rotate(80 512 512)" />
  <circle cx="512" cy="512" r="214" stroke="#FFFFFF" stroke-opacity="0.28" stroke-width="10" />
  <path d="M418 446L498 512L418 578"
    stroke="#FFFFFF" stroke-width="42" stroke-linecap="round" stroke-linejoin="round" />
  <line x1="534" y1="576" x2="618" y2="576"
    stroke="#FFFFFF" stroke-width="42" stroke-linecap="round" />
  <circle cx="778.4" cy="327.6" r="48" fill="#000000" />
  <circle cx="778.4" cy="327.6" r="35" fill="#FFFFFF" />
</svg>
</body>
</html>
"""


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    master_svg = (repo_root / "scripts" / "assets" / "ag-orbit-original-icon.svg").read_text(encoding="utf-8")

    appicon_dir = repo_root / "iOS" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
    preview_dir = repo_root / "iOS" / "Resources" / "Assets.xcassets" / "AntigravityAppIconPreview.imageset"
    appicon_dir.mkdir(parents=True, exist_ok=True)
    preview_dir.mkdir(parents=True, exist_ok=True)

    chromium = find_chromium()

    light_img = render_html_to_rgb_png(
        chromium,
        LIGHT_HTML_TEMPLATE.format(svg=master_svg),
        size=1024,
    )
    light_path = appicon_dir / "AppIcon.png"
    light_img.save(light_path, format="PNG", optimize=True)

    dark_img = render_html_to_rgb_png(
        chromium,
        DARK_HTML_TEMPLATE.format(svg=master_svg),
        size=1024,
    )
    dark_path = appicon_dir / "AppIcon-Dark.png"
    dark_img.save(dark_path, format="PNG", optimize=True)

    tinted_img = render_html_to_rgb_png(
        chromium,
        TINTED_HTML,
        size=1024,
    )
    tinted_path = appicon_dir / "AppIcon-Tinted.png"
    tinted_img.save(tinted_path, format="PNG", optimize=True)

    # Use the signature Matte Obsidian dark icon badge inside the dark-mode Settings screen
    dark_img.resize((128, 128), Image.Resampling.LANCZOS).save(
        preview_dir / "AntigravityAppIconPreview@2x.png", format="PNG", optimize=True
    )
    dark_img.resize((192, 192), Image.Resampling.LANCZOS).save(
        preview_dir / "AntigravityAppIconPreview@3x.png", format="PNG", optimize=True
    )

    for p in (light_path, dark_path, tinted_path):
        with Image.open(p) as verify_im:
            assert verify_im.size == (1024, 1024), f"Unexpected size {verify_im.size} for {p}"
            assert verify_im.mode == "RGB", f"Expected alpha-free RGB mode for {p}, got {verify_im.mode}"
        print(f"[OK] Rendered original icon {p.relative_to(repo_root)} (1024x1024 opaque RGB)")


if __name__ == "__main__":
    main()
