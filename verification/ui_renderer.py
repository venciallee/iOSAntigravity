#!/usr/bin/env python3
"""13-Screen iOS 18 / iPhone 16 Pro (@3x) Visual Renderer & Interactive DOM Harness (`ui_renderer.py`).

Renders `UE01_AGENTS_HOME` .. `UE13_LIVE_ACTIVITY_SPEC` with 1:1 visual parity against
the 13 official Antigravity iOS UE reference screens:
- `UE01`..`UE12`: `393×852pt @3x` (`1179×2556px`), OLED Matte Obsidian (`#090A0D`),
  Card (`#141519`), Elevated (`#1D1F26`), Popover (`#25272F`), Periwinkle CTA (`#8EB4FF`
  with `#0A0E17` dark ink), Active White Pills (`#FFFFFF`), Running Blue (`#7DA7FF`),
  Waiting Amber (`#EBB365`), Done Emerald (`#57C88A`), and Error Coral (`#F07167`).
- `UE13_LIVE_ACTIVITY_SPEC`: `800×500pt @3x` (`2400×1500px`) Dynamic Island & Lock Screen
  multi-agent specification board.
- Full interactive JavaScript handlers wired to `mock_language_server.py` (`?rpcPort=<port>`)
  for `TC-01` .. `TC-16` E2E verification.
"""
import json


# Crisp inline SVG icon library matching Apple SF Symbols & Antigravity UE iconography
ICONS = {
    "chev_down": '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M3 4.5L6 7.5L9 4.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "chev_updown": '<svg width="11" height="14" viewBox="0 0 11 14" fill="none"><path d="M3 5L5.5 2.5L8 5M3 9L5.5 11.5L8 9" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "chev_left": '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M11.5 3.5L6 9L11.5 14.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "chev_right": '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M5 3L9 7L5 11" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "filter_bars": '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M3 5H15M5.5 9H12.5M7.5 13H10.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    "folder_plus": '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M2.2 5C2.2 3.9 3.1 3 4.2 3H6.8L8.4 4.8H13.8C14.9 4.8 15.8 5.7 15.8 6.8V13C15.8 14.1 14.9 15 13.8 15H4.2C3.1 15 2.2 14.1 2.2 13V5Z" stroke="currentColor" stroke-width="1.5"/><path d="M9 8.2V12.2M7 10.2H11" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>',
    "folder": '<svg width="17" height="17" viewBox="0 0 18 18" fill="none"><path d="M2.2 5.2C2.2 4.1 3.1 3.2 4.2 3.2H6.8L8.4 5H13.8C14.9 5 15.8 5.9 15.8 7V13C15.8 14.1 14.9 15 13.8 15H4.2C3.1 15 2.2 14.1 2.2 13V5.2Z" stroke="currentColor" stroke-width="1.5"/></svg>',
    "folder_lg": '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M3 7C3 5.6 4.1 4.5 5.5 4.5H9.2L11.3 6.8H18.5C19.9 6.8 21 7.9 21 9.3V17C21 18.4 19.9 19.5 18.5 19.5H5.5C4.1 19.5 3 18.4 3 17V7Z" stroke="currentColor" stroke-width="1.7"/></svg>',
    "cloud": '<svg width="17" height="17" viewBox="0 0 18 18" fill="none"><path d="M5.2 13.5H13.2C14.9 13.5 16.2 12.2 16.2 10.6C16.2 9.1 15.1 7.8 13.6 7.7C13.1 5.4 11.1 3.8 8.7 3.8C6 3.8 3.8 5.9 3.7 8.6C2.5 9 1.8 10.1 1.8 11.3C1.8 12.6 3.1 13.5 5.2 13.5Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>',
    "search": '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="7.2" cy="7.2" r="4.8" stroke="currentColor" stroke-width="1.6"/><path d="M10.8 10.8L14 14" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>',
    "pin": '<svg width="14" height="14" viewBox="0 0 16 16" fill="none"><path d="M5.5 2.5H10.5L9.8 6.8L12 8.8V10H4V8.8L6.2 6.8L5.5 2.5Z" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/><path d="M8 10V14" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></svg>',
    "plus": '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M9 3.5V14.5M3.5 9H14.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
    "close": '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M3.5 3.5L10.5 10.5M10.5 3.5L3.5 10.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    "dots": '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="4.2" cy="9" r="1.4" fill="currentColor"/><circle cx="9" cy="9" r="1.4" fill="currentColor"/><circle cx="13.8" cy="9" r="1.4" fill="currentColor"/></svg>',
    "chat_tab": '<svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M3.5 5.5C3.5 4.4 4.4 3.5 5.5 3.5H14.5C15.6 3.5 16.5 4.4 16.5 5.5V12C16.5 13.1 15.6 14 14.5 14H8L4.2 16.8V14C3.8 13.6 3.5 12.9 3.5 12V5.5Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>',
    "auto_tab": '<svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M10 4A6 6 0 1 1 4.6 7.4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><path d="M4.2 4.2V7.8H7.8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/><path d="M10 7V10.3L12.3 11.6" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>',
    "sliders": '<svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M3.5 6.5H16.5M3.5 13.5H16.5" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><circle cx="7.5" cy="6.5" r="2.1" fill="#1D1F26" stroke="currentColor" stroke-width="1.7"/><circle cx="12.5" cy="13.5" r="2.1" fill="#1D1F26" stroke="currentColor" stroke-width="1.7"/></svg>',
    "pencil": '<svg width="19" height="19" viewBox="0 0 20 20" fill="none"><path d="M13.6 3.8L16.2 6.4L7.2 15.4H4.6V12.8L13.6 3.8Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>',
    "spinner_blue": '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="9" r="6.8" stroke="#263147" stroke-width="2.1"/><path d="M9 2.2A6.8 6.8 0 0 1 15.6 7.5" stroke="#7DA7FF" stroke-width="2.2" stroke-linecap="round"/></svg>',
    "check": '<svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M2.5 7.3L5.6 10.4L11.5 4" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "doc": '<svg width="15" height="15" viewBox="0 0 16 16" fill="none"><path d="M4 2.2H9.6L12.5 5.1V13.2C12.5 13.8 12 14.2 11.5 14.2H4C3.4 14.2 3 13.8 3 13.2V3.2C3 2.6 3.4 2.2 4 2.2Z" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/><path d="M9.4 2.4V5.3H12.3M5.4 8.2H10.2M5.4 10.8H8.8" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>',
    "archive": '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><rect x="2" y="2.8" width="12" height="3.2" rx="1" stroke="currentColor" stroke-width="1.4"/><path d="M3 6V12.6C3 13.2 3.5 13.6 4.1 13.6H11.9C12.5 13.6 13 13.2 13 12.6V6M6.4 9.2H9.6" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></svg>',
    "trash": '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M2.8 4.4H13.2M6 4.4V2.8H10V4.4M4.2 4.4L4.8 13.2C4.8 13.8 5.3 14.2 5.9 14.2H10.1C10.7 14.2 11.2 13.8 11.2 13.2L11.8 4.4" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "unread_dot": '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="1.4"/><circle cx="8" cy="8" r="2.3" fill="currentColor"/></svg>',
    "branch": '<svg width="14" height="14" viewBox="0 0 16 16" fill="none"><circle cx="5" cy="4" r="1.7" stroke="currentColor" stroke-width="1.4"/><circle cx="5" cy="12" r="1.7" stroke="currentColor" stroke-width="1.4"/><circle cx="11.5" cy="6" r="1.7" stroke="currentColor" stroke-width="1.4"/><path d="M5 5.7V10.3M11.5 7.7C11.5 9.6 5 8.5 5 10.3" stroke="currentColor" stroke-width="1.4"/></svg>',
    "laptop": '<svg width="16" height="16" viewBox="0 0 18 18" fill="none"><rect x="3.2" y="4" width="11.6" height="8.2" rx="1.4" stroke="currentColor" stroke-width="1.5"/><path d="M1.8 14.2H16.2" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg>',
    "bolt": '<svg width="15" height="15" viewBox="0 0 16 16" fill="none"><path d="M9 1.8L3.6 8.8H8L7 14.2L12.4 7.2H8L9 1.8Z" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/></svg>',
    "play": '<svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M3.2 2.2L9.8 6L3.2 9.8V2.2Z" fill="#7DA7FF"/></svg>',
    "planet": '<svg width="15" height="15" viewBox="0 0 16 16" fill="none"><ellipse cx="8" cy="8" rx="6.5" ry="3.2" transform="rotate(-28 8 8)" stroke="currentColor" stroke-width="1.35"/><circle cx="8" cy="8" r="1.7" fill="currentColor"/></svg>',
    "terminal": '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><rect x="1.8" y="2.6" width="12.4" height="10.8" rx="2.4" stroke="currentColor" stroke-width="1.4"/><path d="M4.6 6.2L6.8 8L4.6 9.8M8.2 10H11" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "faceid": '<svg width="17" height="17" viewBox="0 0 18 18" fill="none"><path d="M2.5 5.5V4C2.5 3.2 3.2 2.5 4 2.5H5.5M12.5 2.5H14C14.8 2.5 15.5 3.2 15.5 4V5.5M15.5 12.5V14C15.5 14.8 14.8 15.5 14 15.5H12.5M5.5 15.5H4C3.2 15.5 2.5 14.8 2.5 14V12.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/><path d="M6.3 6.5V7.8M11.7 6.5V7.8M9 6.8V9.6H8.1M6.8 11.6C7.5 12.4 10.5 12.4 11.2 11.6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "mic": '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><rect x="5.6" y="2.2" width="4.8" height="7.4" rx="2.4" stroke="currentColor" stroke-width="1.4"/><path d="M3.4 7.8C3.4 10.3 5.5 12.2 8 12.2C10.5 12.2 12.6 10.3 12.6 7.8M8 12.2V14.2" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></svg>',
    "arrow_up": '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 12.8V3.5M8 3.5L4.2 7.3M8 3.5L11.8 7.3" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "at": '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="9" r="2.8" stroke="currentColor" stroke-width="1.5"/><path d="M11.8 9V10.3C11.8 11.3 12.5 12 13.4 12C14.5 12 15.4 10.8 15.4 9C15.4 5.5 12.5 2.6 9 2.6C5.5 2.6 2.6 5.5 2.6 9C2.6 12.5 5.5 15.4 9 15.4C10.5 15.4 11.9 14.9 13 14.1" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>',
    "cube": '<svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M9 2.2L15 5.6V12.4L9 15.8L3 12.4V5.6L9 2.2Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M3.2 5.8L9 9L14.8 5.8M9 9V15.6" stroke="currentColor" stroke-width="1.5"/></svg>',
    "comment": '<svg width="14" height="14" viewBox="0 0 16 16" fill="none"><path d="M2.5 4.2C2.5 3.4 3.2 2.8 4 2.8H12C12.8 2.8 13.5 3.4 13.5 4.2V9.8C13.5 10.6 12.8 11.2 12 11.2H6.5L3.4 13.5V11.2C2.9 10.9 2.5 10.4 2.5 9.8V4.2Z" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/></svg>',
}


MOBILE_CSS = """
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
  -webkit-font-smoothing: antialiased;
  user-select: none;
}
html, body {
  width: 393px;
  max-width: 393px;
  height: 852px;
  max-height: 852px;
  overflow: hidden;
  background: #090A0D;
  color: #F5F7FA;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Roboto', 'Noto Sans CJK SC', sans-serif;
  position: relative;
}
input, textarea, button {
  font-family: inherit;
  border: none;
  outline: none;
  background: transparent;
  color: inherit;
}
.mono {
  font-family: 'SF Mono', 'JetBrains Mono', 'Liberation Mono', 'DejaVu Sans Mono', monospace;
}
.screen {
  position: relative;
  width: 393px;
  height: 852px;
  overflow: hidden;
  background: #090A0D;
}
.circle-icon-btn {
  width: 44px;
  height: 44px;
  border-radius: 22px;
  background: #1A1B20;
  border: 1px solid rgba(255, 255, 255, 0.05);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #E5E7EF;
  cursor: pointer;
  flex-shrink: 0;
}
.card-group {
  background: #141519;
  border: 1px solid rgba(255, 255, 255, 0.045);
  border-radius: 18px;
  overflow: hidden;
}
.divider {
  height: 1px;
  background: rgba(255, 255, 255, 0.055);
  margin-left: 16px;
}
.section-label {
  font-size: 11.5px;
  font-weight: 600;
  letter-spacing: 0.75px;
  text-transform: uppercase;
  color: #7D818D;
}
.amber-halo {
  width: 18px;
  height: 18px;
  border-radius: 9px;
  background: rgba(235, 179, 101, 0.20);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.amber-halo::after {
  content: '';
  width: 9px;
  height: 9px;
  border-radius: 5px;
  background: #EBB365;
}
.green-halo {
  width: 18px;
  height: 18px;
  border-radius: 9px;
  background: rgba(87, 200, 138, 0.20);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.green-halo::after {
  content: '';
  width: 9px;
  height: 9px;
  border-radius: 5px;
  background: #57C88A;
}
.floating-bottom-dock {
  position: absolute;
  left: 16px;
  right: 16px;
  bottom: 22px;
  display: flex;
  align-items: center;
  gap: 12px;
  z-index: 40;
}
.liquid-tab-bar {
  flex: 1;
  height: 62px;
  border-radius: 31px;
  background: rgba(27, 29, 35, 0.94);
  backdrop-filter: blur(22px);
  border: 1px solid rgba(255, 255, 255, 0.09);
  padding: 4px;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  align-items: center;
  box-shadow: 0 12px 30px rgba(0, 0, 0, 0.55);
}
.tab-item {
  height: 52px;
  border-radius: 26px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  font-size: 10.5px;
  font-weight: 600;
  color: #A0A4B0;
  cursor: pointer;
}
.tab-item.active {
  background: #353842;
  color: #8EB4FF;
}
.fab-periwinkle {
  width: 62px;
  height: 62px;
  border-radius: 31px;
  background: #8EB4FF;
  color: #0A0E17;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 10px 26px rgba(0, 0, 0, 0.5);
  flex-shrink: 0;
}
.cta-periwinkle {
  min-height: 50px;
  border-radius: 25px;
  background: #8EB4FF;
  color: #0A0E17;
  font-size: 15.5px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  cursor: pointer;
}
.sheet-grabber {
  width: 38px;
  height: 4.5px;
  border-radius: 3px;
  background: #52555F;
  margin: 9px auto 0 auto;
}
"""


SPEC_BOARD_CSS = """
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
  -webkit-font-smoothing: antialiased;
}
html, body {
  width: 800px;
  max-width: 800px;
  height: 500px;
  max-height: 500px;
  overflow: hidden;
  background: #ECECEF;
  color: #15171C;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Roboto', 'Noto Sans CJK SC', sans-serif;
}
.mono {
  font-family: 'SF Mono', 'JetBrains Mono', 'Liberation Mono', 'DejaVu Sans Mono', monospace;
}
"""


INTERACTIVE_RUNTIME_JS = r"""
window.__AGY_COLLECT_AX = function(stateId, selectors) {
  const elements = {};
  for (const sel of selectors) {
    const el = document.querySelector(sel);
    if (el) {
      const r = el.getBoundingClientRect();
      elements[sel] = {
        exists: true,
        x: Math.round(r.x * 10) / 10,
        y: Math.round(r.y * 10) / 10,
        width: Math.round(r.width * 10) / 10,
        height: Math.round(r.height * 10) / 10,
        text: (el.innerText || el.value || '').trim().slice(0, 140)
      };
    } else {
      elements[sel] = { exists: false };
    }
  }
  const bodyRect = document.body.getBoundingClientRect();
  return {
    stateId: stateId,
    viewportWidth: Math.round(bodyRect.width),
    viewportHeight: Math.round(bodyRect.height),
    scrollWidth: document.documentElement.scrollWidth,
    scrollHeight: document.documentElement.scrollHeight,
    overflowPx: Math.max(0, document.documentElement.scrollWidth - Math.round(bodyRect.width)),
    elements: elements
  };
};

window.__AGY_RPC = async function(method, payload, extraHeaders) {
  const params = new URLSearchParams(window.location.search);
  const rpcPort = params.get('rpcPort') || window.__AGY_RPC_PORT;
  window.__AGY_LAST_RPC = { method, payload };
  if (!rpcPort) return { ok: true, offline: true };
  try {
    const headers = Object.assign({ 'Content-Type': 'application/json' }, extraHeaders || {});
    const res = await fetch(`http://127.0.0.1:${rpcPort}/exa.language_server_pb.LanguageServerService/${method}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload || {})
    });
    const data = await res.json();
    window.__AGY_LAST_RPC_RESPONSE = data;
    return data;
  } catch (err) {
    return { ok: false, error: String(err) };
  }
};
"""


def _wrap_mobile_page(state_id: str, body_html: str, page_js: str, selectors: list, rpc_port: int = 0) -> str:
    selectors_json = json.dumps(selectors)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=393, initial-scale=1, maximum-scale=1, user-scalable=no" />
<title>{state_id}</title>
<style>{MOBILE_CSS}</style>
</head>
<body data-state-id="{state_id}">
  <div class="screen">
    {body_html}
  </div>
  <script>
    window.__AGY_RPC_PORT = {int(rpc_port)};
    {INTERACTIVE_RUNTIME_JS}
    {page_js}
    window.addEventListener('load', () => {{
      const report = window.__AGY_COLLECT_AX("{state_id}", {selectors_json});
      window.__AGY_AX_REPORT = report;
      fetch('/__esdd_ax_report', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: JSON.stringify(report)
      }}).catch(() => {{}});
    }});
  </script>
</body>
</html>"""


def _wrap_spec_board_page(state_id: str, body_html: str, selectors: list, rpc_port: int = 0) -> str:
    selectors_json = json.dumps(selectors)
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=800, initial-scale=1, maximum-scale=1, user-scalable=no" />
<title>{state_id}</title>
<style>{SPEC_BOARD_CSS}</style>
</head>
<body data-state-id="{state_id}">
  {body_html}
  <script>
    window.__AGY_RPC_PORT = {int(rpc_port)};
    {INTERACTIVE_RUNTIME_JS}
    window.addEventListener('load', () => {{
      const report = window.__AGY_COLLECT_AX("{state_id}", {selectors_json});
      window.__AGY_AX_REPORT = report;
      fetch('/__esdd_ax_report', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: JSON.stringify(report)
      }}).catch(() => {{}});
    }});
  </script>
</body>
</html>"""


def _floating_tab_bar(active_tab: str, fab_testid: str, fab_icon: str) -> str:
    agents_cls = "tab-item active" if active_tab == "agents" else "tab-item"
    auto_cls = "tab-item active" if active_tab == "automations" else "tab-item"
    set_cls = "tab-item active" if active_tab == "settings" else "tab-item"
    return f"""
    <div class="floating-bottom-dock">
      <div data-testid="floating-tab-bar" class="liquid-tab-bar">
        <div data-testid="tab-agents" class="{agents_cls}">
          {ICONS['chat_tab']}
          <span>Agents</span>
        </div>
        <div data-testid="tab-automations" class="{auto_cls}">
          {ICONS['auto_tab']}
          <span>Automations</span>
        </div>
        <div data-testid="tab-settings" class="{set_cls}">
          {ICONS['sliders']}
          <span>Settings</span>
        </div>
      </div>
      <button data-testid="{fab_testid}" class="fab-periwinkle" aria-label="Primary Action">
        {ICONS[fab_icon]}
      </button>
    </div>
    """


def render_scene_html(state_id: str, selectors: list, rpc_port: int = 0) -> str:
    if state_id == "UE01_AGENTS_HOME":
        body = f"""
        <div style="padding: 56px 16px 0 16px; display: flex; flex-direction: column;">
          <!-- Top Utility Bar -->
          <div style="display:flex; align-items:center; justify-content:space-between;">
            <button data-testid="host-switcher-pill" data-online="true" style="min-height:44px; padding:0 14px; border-radius:22px; background:#1A1B20; border:1px solid rgba(255,255,255,0.05); display:inline-flex; align-items:center; gap:8px; cursor:pointer;">
              <span data-testid="host-online-dot" style="width:8.5px; height:8.5px; border-radius:50%; background:#57C88A;"></span>
              <span style="font-size:14.5px; font-weight:600; color:#F5F7FA;">MacBook Pro</span>
              <span style="color:#8E929F; display:flex;">{ICONS['chev_down']}</span>
            </button>
            <div style="display:flex; align-items:center; gap:10px;">
              <button data-testid="btn-display-options" class="circle-icon-btn">{ICONS['filter_bars']}</button>
              <button data-testid="btn-new-project" class="circle-icon-btn">{ICONS['folder_plus']}</button>
            </div>
          </div>

          <!-- Large Title -->
          <h1 style="font-size:34px; font-weight:700; letter-spacing:-0.7px; margin-top:14px; color:#F5F7FA;">Agents</h1>

          <!-- Search Input -->
          <div style="margin-top:12px; height:44px; border-radius:13px; background:#17181D; padding:0 13px; display:flex; align-items:center; gap:9px;">
            <span style="color:#7D818D; display:flex;">{ICONS['search']}</span>
            <input data-testid="agents-search-input" type="text" placeholder="Search conversations" style="flex:1; height:44px; font-size:15.5px; color:#F5F7FA;" />
          </div>

          <!-- Filter Pills -->
          <div style="margin-top:12px; display:flex; align-items:center; gap:7px; overflow:hidden;">
            <button data-testid="filter-pill-all" data-filter="all" class="agy-filter-pill" style="height:36px; min-width:46px; padding:0 14px; border-radius:18px; background:#FFFFFF; color:#0A0E17; font-size:13.5px; font-weight:700; cursor:pointer;">All</button>
            <button data-testid="filter-pill-running" data-filter="running" class="agy-filter-pill" style="height:36px; padding:0 12px; border-radius:18px; background:#17181D; color:#D5D8E2; font-size:13.5px; font-weight:500; display:inline-flex; align-items:center; gap:6px; white-space:nowrap; cursor:pointer;">
              <span style="width:7px; height:7px; border-radius:50%; background:#7DA7FF;"></span>Running 2
            </button>
            <button data-testid="filter-pill-needs-you" data-filter="needs-you" class="agy-filter-pill" style="height:36px; padding:0 12px; border-radius:18px; background:#17181D; color:#D5D8E2; font-size:13.5px; font-weight:500; display:inline-flex; align-items:center; gap:6px; white-space:nowrap; cursor:pointer;">
              <span style="width:7px; height:7px; border-radius:50%; background:#EBB365;"></span>Needs you 1
            </button>
            <button data-testid="filter-pill-unread" data-filter="unread" class="agy-filter-pill" style="height:36px; padding:0 12px; border-radius:18px; background:#17181D; color:#D5D8E2; font-size:13.5px; font-weight:500; white-space:nowrap; cursor:pointer;">Unread 3</button>
          </div>

          <!-- PINNED Section -->
          <div id="pinned-header" style="margin-top:16px; margin-bottom:8px; display:flex; align-items:center; gap:6px; padding-left:2px;">
            <span style="color:#7D818D; display:flex;">{ICONS['pin']}</span>
            <span class="section-label">PINNED</span>
          </div>
          <div data-testid="pinned-section-card" class="card-group">
            <div class="conv-row" data-category="running" data-title="Add rate limiter to /transfers" style="padding:13px 15px; display:flex; gap:11px; align-items:flex-start;">
              <span style="margin-top:2px; display:flex;">{ICONS['spinner_blue']}</span>
              <div style="flex:1; min-width:0;">
                <div style="display:flex; justify-content:space-between; align-items:baseline; gap:8px;">
                  <span style="font-size:15.5px; font-weight:600; color:#F5F7FA; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">Add rate limiter to /transfers</span>
                  <span style="font-size:12.5px; color:#7D818D; flex-shrink:0;">now</span>
                </div>
                <div style="font-size:13.5px; color:#7DA7FF; margin-top:3px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">Running · Step 4 of 7 · go test ./internal/...</div>
                <div style="font-size:12.5px; color:#7D818D; margin-top:2px;">ledger-svc</div>
              </div>
            </div>
            <div class="divider"></div>
            <div class="conv-row" data-category="done" data-title="Release checklist v2.3" style="padding:13px 15px 13px 44px;">
              <div style="display:flex; justify-content:space-between; align-items:baseline;">
                <span style="font-size:15.5px; font-weight:600; color:#F5F7FA;">Release checklist v2.3</span>
                <span style="font-size:12.5px; color:#7D818D;">1h</span>
              </div>
              <div style="font-size:13.5px; color:#8A8E9B; margin-top:3px;">Done · Walkthrough ready</div>
              <div style="font-size:12.5px; color:#7D818D; margin-top:2px;">web-console</div>
            </div>
          </div>

          <!-- Project Group: ledger-svc -->
          <div data-testid="project-group-ledger-svc" style="margin-top:18px;">
            <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:9px;">
              <div style="display:flex; align-items:center; gap:10px;">
                <div style="width:34px; height:34px; border-radius:10px; background:#18191F; border:1px solid rgba(255,255,255,0.05); display:flex; align-items:center; justify-content:center; color:#A5AAB8;">{ICONS['folder']}</div>
                <div>
                  <div style="font-size:16px; font-weight:600; color:#F5F7FA; line-height:19px;">ledger-svc</div>
                  <div style="font-size:12.5px; color:#7D818D;">Local · MacBook Pro · main</div>
                </div>
              </div>
              <div style="display:flex; align-items:center; gap:20px; color:#9DA2B0; padding-right:4px;">
                <span style="display:flex;">{ICONS['plus']}</span>
                <span style="display:flex;">{ICONS['chev_down']}</span>
              </div>
            </div>

            <div class="card-group">
              <div class="conv-row" data-testid="conv-row-flaky" data-category="needs-you unread" data-title="Fix flaky TestSettlementBatch" style="padding:13px 15px; display:flex; gap:11px; align-items:flex-start;">
                <span class="amber-halo" style="margin-top:2px;"></span>
                <div style="flex:1; min-width:0;">
                  <div style="display:flex; justify-content:space-between; align-items:baseline;">
                    <span style="font-size:15.5px; font-weight:600; color:#F5F7FA;">Fix flaky TestSettlementBatch</span>
                    <span style="font-size:12.5px; color:#7D818D;">8m</span>
                  </div>
                  <div style="font-size:13.5px; color:#EBB365; margin-top:3px;">Needs review · Implementation plan ready</div>
                </div>
              </div>
              <div class="divider"></div>
              <div class="conv-row" data-category="unread" data-title="Upgrade to Go 1.25" style="padding:13px 15px; display:flex; gap:11px; align-items:flex-start;">
                <span style="width:18px; height:18px; display:inline-flex; align-items:center; justify-content:center; margin-top:2px; flex-shrink:0;">
                  <span style="width:8.5px; height:8.5px; border-radius:50%; background:#8EB4FF;"></span>
                </span>
                <div style="flex:1; min-width:0;">
                  <div style="display:flex; justify-content:space-between; align-items:baseline;">
                    <span style="font-size:15.5px; font-weight:600; color:#F5F7FA;">Upgrade to Go 1.25</span>
                    <span style="font-size:12.5px; color:#7D818D;">1h</span>
                  </div>
                  <div style="font-size:13.5px; color:#8A8E9B; margin-top:3px;">Done · 6 files changed <span style="color:#57C88A; font-weight:600;">+42</span> <span style="color:#F07167; font-weight:600;">-31</span></div>
                </div>
              </div>
              <div class="divider"></div>
              <div class="conv-row" data-category="unread" data-title="Idempotency keys for payouts" style="padding:13px 15px 13px 44px;">
                <div style="display:flex; justify-content:space-between; align-items:baseline;">
                  <span style="font-size:15.5px; font-weight:600; color:#F5F7FA;">Idempotency keys for payouts</span>
                  <span style="font-size:12.5px; color:#7D818D;">Yesterday</span>
                </div>
                <div style="font-size:13.5px; color:#8A8E9B; margin-top:3px;">Done · Merged into main</div>
              </div>
            </div>
          </div>

          <!-- Project Group: web-console (peeking beneath Floating Tab Bar) -->
          <div id="project-group-web-console" style="margin-top:18px; opacity:0.78;">
            <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:8px;">
              <div style="display:flex; align-items:center; gap:10px;">
                <div style="width:34px; height:34px; border-radius:10px; background:#18191F; display:flex; align-items:center; justify-content:center; color:#A5AAB8;">{ICONS['cloud']}</div>
                <div>
                  <div style="font-size:16px; font-weight:600; color:#F5F7FA;">web-console</div>
                  <div style="font-size:12px; color:#7D818D;">Cloud · acme/web-console</div>
                </div>
              </div>
              <div style="display:flex; align-items:center; gap:20px; color:#9DA2B0; padding-right:4px;">
                <span style="display:flex;">{ICONS['plus']}</span>
                <span style="display:flex;">{ICONS['chev_down']}</span>
              </div>
            </div>
            <div class="card-group" style="padding:12px 15px; opacity:0.55;">
              <div style="font-size:15px; font-weight:600; color:#F5F7FA;">Dark mode for settings page</div>
              <div style="font-size:13px; color:#7DA7FF; margin-top:3px;">Running in cloud · Step 2 of 5</div>
            </div>
          </div>
        </div>
        {_floating_tab_bar("agents", "fab-compose", "pencil")}
        """
        js = """
        document.querySelectorAll('.agy-filter-pill').forEach(btn => {
          btn.addEventListener('click', () => {
            const filter = btn.dataset.filter;
            document.body.dataset.activeFilter = filter;
            document.querySelectorAll('.agy-filter-pill').forEach(b => {
              const active = b === btn;
              b.style.background = active ? '#FFFFFF' : '#17181D';
              b.style.color = active ? '#0A0E17' : '#D5D8E2';
              b.style.fontWeight = active ? '700' : '500';
            });
            document.querySelectorAll('.conv-row').forEach(row => {
              const cats = (row.dataset.category || '').split(' ');
              const show = filter === 'all' || cats.includes(filter);
              row.style.display = show ? '' : 'none';
            });
            const pinnedCard = document.querySelector("[data-testid='pinned-section-card']");
            const anyPinned = Array.from(pinnedCard.querySelectorAll('.conv-row')).some(r => r.style.display !== 'none');
            pinnedCard.style.display = anyPinned ? '' : 'none';
            document.getElementById('pinned-header').style.display = anyPinned ? 'flex' : 'none';
          });
        });
        const searchInput = document.querySelector("[data-testid='agents-search-input']");
        searchInput.addEventListener('input', () => {
          const q = searchInput.value.toLowerCase();
          document.querySelectorAll('.conv-row').forEach(row => {
            const match = (row.dataset.title || '').toLowerCase().includes(q);
            row.style.display = match ? '' : 'none';
          });
        });
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE02_DISPLAY_OPTIONS":
        body = f"""
        <!-- Dimmed Agents Header Behind Sheet -->
        <div style="padding:106px 16px 0 16px; opacity:0.32;">
          <h1 style="font-size:34px; font-weight:700; letter-spacing:-0.7px; color:#E5E7EF;">Agents</h1>
        </div>

        <!-- Bottom Sheet -->
        <div style="position:absolute; top:171px; left:0; right:0; bottom:0; background:#16171C; border-radius:28px 28px 0 0; border-top:1px solid rgba(255,255,255,0.08); padding:0 16px;">
          <div class="sheet-grabber"></div>
          <div style="height:50px; display:flex; align-items:center; justify-content:space-between; margin-top:4px;">
            <button data-testid="sheet-reset-btn" style="min-width:56px; min-height:44px; text-align:left; font-size:16px; color:#9EA2B0; cursor:pointer;">Reset</button>
            <span style="font-size:17px; font-weight:700; color:#F5F7FA;">Display Options</span>
            <button data-testid="sheet-done-btn" style="min-width:56px; min-height:44px; text-align:right; font-size:16px; font-weight:700; color:#8EB4FF; cursor:pointer;">Done</button>
          </div>

          <!-- Group 1: Group By / Sort Conversations / Sort Projects -->
          <div style="margin-top:10px; background:#202228; border-radius:16px; overflow:hidden;">
            <div data-testid="row-group-by" style="min-height:50px; padding:0 16px; display:flex; align-items:center; justify-content:space-between;">
              <span style="font-size:15.5px; color:#F5F7FA;">Group By</span>
              <span style="font-size:15px; color:#8E929F; display:inline-flex; align-items:center; gap:5px;">Project {ICONS['chev_updown']}</span>
            </div>
            <div class="divider"></div>
            <div data-testid="row-sort-conversations" style="min-height:50px; padding:0 16px; background:#272930; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <span style="font-size:15.5px; color:#F5F7FA;">Sort Conversations</span>
              <span id="sort-conv-val" style="font-size:15px; color:#9EA2B0; display:inline-flex; align-items:center; gap:5px;">Last Updated {ICONS['chev_updown']}</span>
            </div>
            <div class="divider"></div>
            <div style="min-height:50px; padding:0 16px; display:flex; align-items:center; justify-content:space-between;">
              <span style="font-size:15.5px; color:#F5F7FA;">Sort Projects</span>
              <span style="font-size:15px; color:#8E929F;">Custom Order</span>
            </div>
          </div>

          <!-- Floating Sort Popover Menu -->
          <div data-testid="sort-popover-menu" style="position:absolute; top:188px; left:124px; width:238px; background:rgba(43,45,53,0.97); backdrop-filter:blur(24px); border:1px solid rgba(255,255,255,0.10); border-radius:16px; box-shadow:0 18px 42px rgba(0,0,0,0.68); z-index:30; overflow:hidden; padding:4px 0;">
            <div class="sort-opt" data-sort="Last Updated" style="height:44px; padding:0 16px; display:flex; align-items:center; gap:10px; font-size:15px; color:#F5F7FA; cursor:pointer;">
              <span class="chk" style="width:16px; display:inline-flex;">{ICONS['check']}</span><span>Last Updated</span>
            </div>
            <div class="sort-opt" data-sort="Date Created" style="height:44px; padding:0 16px; display:flex; align-items:center; gap:10px; font-size:15px; color:#F5F7FA; cursor:pointer;">
              <span class="chk" style="width:16px; display:inline-flex;"></span><span>Date Created</span>
            </div>
            <div class="sort-opt" data-sort="Title" style="height:44px; padding:0 16px; display:flex; align-items:center; gap:10px; font-size:15px; color:#F5F7FA; cursor:pointer;">
              <span class="chk" style="width:16px; display:inline-flex;"></span><span>Title</span>
            </div>
            <div style="height:6px; background:rgba(16,17,22,0.55); margin:2px 0;"></div>
            <div class="order-opt" data-order="Newest First" style="height:44px; padding:0 16px; display:flex; align-items:center; gap:10px; font-size:15px; color:#F5F7FA; cursor:pointer;">
              <span style="width:16px; display:inline-flex;">{ICONS['check']}</span><span>Newest First</span>
            </div>
            <div class="order-opt" data-order="Oldest First" style="height:44px; padding:0 16px; display:flex; align-items:center; gap:10px; font-size:15px; color:#F5F7FA; cursor:pointer;">
              <span style="width:16px; display:inline-flex;"></span><span>Oldest First</span>
            </div>
          </div>

          <!-- Group 2: Filter / Display -->
          <div style="margin-top:14px; background:#202228; border-radius:16px; overflow:hidden;">
            <div style="min-height:48px; padding:0 16px; display:flex; align-items:center; justify-content:space-between;">
              <span style="font-size:15.5px; color:#F5F7FA;">Filter</span>
              <span style="font-size:14.5px; color:#6D707D;">All conversations</span>
            </div>
            <div class="divider"></div>
            <div style="min-height:48px; padding:0 16px; display:flex; align-items:center; justify-content:space-between;">
              <span style="font-size:15.5px; color:#F5F7FA;">Display</span>
              <span style="font-size:14.5px; color:#6D707D;">Comfortable · Previews</span>
            </div>
          </div>

          <!-- Group 3: Auto Pin & Archived Only -->
          <div style="margin-top:14px; background:#202228; border-radius:16px; overflow:hidden;">
            <div data-testid="toggle-auto-pin" data-checked="false" style="min-height:64px; padding:10px 16px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <div>
                <div style="font-size:15.5px; color:#F5F7FA;">Auto Pin</div>
                <div style="font-size:12.5px; color:#7D818D; margin-top:2px;">Pin a conversation when you message it</div>
              </div>
              <div id="auto-pin-track" style="width:50px; height:30px; border-radius:15px; background:#383A43; padding:2px; display:flex; align-items:center;">
                <div id="auto-pin-knob" style="width:26px; height:26px; border-radius:13px; background:#FFFFFF;"></div>
              </div>
            </div>
            <div class="divider"></div>
            <div data-testid="toggle-archived-only" data-checked="false" style="min-height:64px; padding:10px 16px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <div>
                <div style="font-size:15.5px; color:#F5F7FA;">Archived Only</div>
                <div style="font-size:12.5px; color:#7D818D; margin-top:2px;">Show only archived conversations</div>
              </div>
              <div style="width:50px; height:30px; border-radius:15px; background:#383A43; padding:2px; display:flex; align-items:center;">
                <div style="width:26px; height:26px; border-radius:13px; background:#FFFFFF;"></div>
              </div>
            </div>
          </div>

          <!-- Group 4: Mark All as Read -->
          <div style="margin-top:14px; background:#202228; border-radius:16px; overflow:hidden;">
            <button data-testid="btn-mark-all-read" style="width:100%; min-height:50px; padding:0 16px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <span style="font-size:15.5px; font-weight:500; color:#8EB4FF;">Mark All as Read</span>
              <span id="unread-count-label" style="font-size:14.5px; color:#8A8E9B;">3 unread</span>
            </button>
          </div>
        </div>
        """
        js = """
        const autoPin = document.querySelector("[data-testid='toggle-auto-pin']");
        autoPin.addEventListener('click', () => {
          const next = autoPin.dataset.checked !== 'true';
          autoPin.dataset.checked = String(next);
          document.getElementById('auto-pin-track').style.background = next ? '#57C88A' : '#383A43';
          document.getElementById('auto-pin-track').style.justifyContent = next ? 'flex-end' : 'flex-start';
        });
        document.querySelector("[data-testid='btn-mark-all-read']").addEventListener('click', async () => {
          await window.__AGY_RPC('MarkAllConversationsRead', {});
          document.getElementById('unread-count-label').textContent = '0 unread';
          document.body.dataset.unreadCount = '0';
        });
        document.querySelector("[data-testid='sheet-reset-btn']").addEventListener('click', () => {
          autoPin.dataset.checked = 'false';
          document.getElementById('auto-pin-track').style.background = '#383A43';
          document.getElementById('auto-pin-track').style.justifyContent = 'flex-start';
          document.getElementById('unread-count-label').textContent = '3 unread';
          document.getElementById('sort-conv-val').childNodes[0].textContent = 'Last Updated ';
          document.body.dataset.unreadCount = '3';
        });
        document.querySelector("[data-testid='row-sort-conversations']").addEventListener('click', () => {
          const pop = document.querySelector("[data-testid='sort-popover-menu']");
          pop.style.display = pop.style.display === 'none' ? 'block' : 'none';
        });
        document.querySelectorAll('.sort-opt').forEach(opt => {
          opt.addEventListener('click', () => {
            document.getElementById('sort-conv-val').childNodes[0].textContent = opt.dataset.sort + ' ';
            document.body.dataset.sortBy = opt.dataset.sort;
            document.querySelector("[data-testid='sort-popover-menu']").style.display = 'none';
          });
        });
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE03_CONTEXT_MENU_PIN":
        body = f"""
        <!-- Blurred Header Glow -->
        <div style="position:absolute; top:108px; left:18px; width:124px; height:36px; border-radius:18px; background:rgba(255,255,255,0.14); filter:blur(16px);"></div>

        <!-- Rich Long-Press Preview Card -->
        <div data-testid="context-preview-card" style="position:absolute; top:198px; left:16px; right:16px; background:#1B1C22; border:1px solid rgba(255,255,255,0.07); border-radius:22px; padding:18px; box-shadow:0 20px 48px rgba(0,0,0,0.65);">
          <div style="display:flex; align-items:center; gap:10px;">
            <span class="amber-halo"></span>
            <div>
              <div style="font-size:16.5px; font-weight:700; color:#F5F7FA;">Fix flaky TestSettlementBatch</div>
              <div style="font-size:12.5px; color:#8A8E9B; margin-top:2px;">ledger-svc · Gemini 3.1 Pro · 8m</div>
            </div>
          </div>
          <p style="font-size:14.5px; line-height:21px; color:#D5D8E2; margin-top:14px;">
            The flake comes from a shared fake clock across parallel subtests in settlement_test.go. I wrote a plan to isolate it per test — review it before I change anything?
          </p>
          <div style="display:flex; align-items:center; gap:8px; margin-top:15px;">
            <span data-testid="chip-implementation-plan" style="height:32px; padding:0 12px; border-radius:10px; background:#282A33; color:#E5E7EF; font-size:13px; font-weight:500; display:inline-flex; align-items:center; gap:6px;">
              {ICONS['doc']} Implementation Plan
            </span>
            <span data-testid="chip-awaiting-review" style="height:32px; padding:0 12px; border-radius:10px; background:rgba(235,179,101,0.16); color:#EBB365; font-size:13px; font-weight:600; display:inline-flex; align-items:center;">
              Awaiting review
            </span>
          </div>
        </div>

        <!-- iOS Native Context Menu -->
        <div style="position:absolute; top:420px; left:16px; width:260px; background:#25272F; border:1px solid rgba(255,255,255,0.08); border-radius:18px; overflow:hidden; box-shadow:0 18px 40px rgba(0,0,0,0.65);">
          <button data-testid="menu-action-pin" style="width:100%; height:46px; padding:0 16px; display:flex; align-items:center; justify-content:space-between; font-size:15.5px; color:#F5F7FA; background:#2E303A; cursor:pointer;">
            <span id="menu-pin-label">Pin</span><span>{ICONS['pin']}</span>
          </button>
          <div style="height:1px; background:rgba(255,255,255,0.07);"></div>
          <button data-testid="menu-action-unread" style="width:100%; height:46px; padding:0 16px; display:flex; align-items:center; justify-content:space-between; font-size:15.5px; color:#F5F7FA; cursor:pointer;">
            <span>Mark as Unread</span><span>{ICONS['unread_dot']}</span>
          </button>
          <div style="height:1px; background:rgba(255,255,255,0.07);"></div>
          <button data-testid="menu-action-rename" style="width:100%; height:46px; padding:0 16px; display:flex; align-items:center; justify-content:space-between; font-size:15.5px; color:#F5F7FA; cursor:pointer;">
            <span>Rename</span><span>{ICONS['pencil']}</span>
          </button>
          <div style="height:1px; background:rgba(255,255,255,0.07);"></div>
          <button data-testid="menu-action-move" style="width:100%; height:46px; padding:0 16px; display:flex; align-items:center; justify-content:space-between; font-size:15.5px; color:#F5F7FA; cursor:pointer;">
            <span>Move to Project</span><span>{ICONS['chev_right']}</span>
          </button>
          <div style="height:7px; background:#18191F;"></div>
          <button data-testid="menu-action-archive" style="width:100%; height:46px; padding:0 16px; display:flex; align-items:center; justify-content:space-between; font-size:15.5px; color:#F5F7FA; cursor:pointer;">
            <span>Archive</span><span>{ICONS['archive']}</span>
          </button>
          <div style="height:1px; background:rgba(255,255,255,0.07);"></div>
          <button data-testid="menu-action-delete" style="width:100%; height:46px; padding:0 16px; display:flex; align-items:center; justify-content:space-between; font-size:15.5px; color:#F07167; cursor:pointer;">
            <span>Delete</span><span style="color:#F07167;">{ICONS['trash']}</span>
          </button>
        </div>

        <!-- Bottom Swipe Shortcut Showcase -->
        <div style="position:absolute; top:726px; left:16px; right:16px;">
          <div class="section-label" style="margin-bottom:8px;">SWIPE SHORTCUT</div>
          <div id="swipe-row-go125" style="height:64px; border-radius:16px; background:#141519; border:1px solid rgba(255,255,255,0.05); overflow:hidden; display:flex; align-items:stretch;">
            <div style="flex:1; padding:12px 14px; display:flex; flex-direction:column; justify-content:center;">
              <div style="font-size:15px; font-weight:600; color:#F5F7FA;">Upgrade to Go 1.25</div>
              <div id="swipe-row-sub" style="font-size:12.5px; color:#7D818D; margin-top:2px;">Done · 1h</div>
            </div>
            <button data-testid="swipe-action-pin" style="width:76px; background:#8EB4FF; color:#0A0E17; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:3px; font-size:12px; font-weight:700; cursor:pointer;">
              {ICONS['pin']}<span>Pin</span>
            </button>
            <button data-testid="swipe-action-archive" style="width:76px; background:#3B3D46; color:#F5F7FA; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:3px; font-size:12px; font-weight:600; cursor:pointer;">
              {ICONS['archive']}<span>Archive</span>
            </button>
          </div>
        </div>
        """
        js = """
        document.querySelector("[data-testid='menu-action-pin']").addEventListener('click', () => {
          document.body.dataset.pinnedFlaky = 'true';
          document.getElementById('menu-pin-label').textContent = 'Pinned ✓';
        });
        document.querySelector("[data-testid='swipe-action-pin']").addEventListener('click', () => {
          document.body.dataset.swipePinned = 'true';
          document.getElementById('swipe-row-sub').textContent = 'Pinned · Done · 1h';
        });
        document.querySelector("[data-testid='swipe-action-archive']").addEventListener('click', () => {
          document.body.dataset.swipeArchived = 'true';
          document.getElementById('swipe-row-sub').textContent = 'Archived';
        });
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE04_PROJECT_DETAIL":
        body = f"""
        <div style="padding:56px 16px 0 16px; display:flex; flex-direction:column;">
          <!-- Nav Bar -->
          <div style="display:flex; align-items:center; justify-content:space-between;">
            <button data-testid="btn-back-agents" style="min-height:44px; min-width:88px; display:inline-flex; align-items:center; gap:4px; color:#8EB4FF; font-size:16.5px; font-weight:500; cursor:pointer;">
              {ICONS['chev_left']}<span>Agents</span>
            </button>
            <button class="circle-icon-btn">{ICONS['dots']}</button>
          </div>

          <!-- Hero Identity -->
          <div style="display:flex; align-items:center; gap:14px; margin-top:12px;">
            <div style="width:56px; height:56px; border-radius:16px; background:#1A1B21; border:1px solid rgba(255,255,255,0.06); display:flex; align-items:center; justify-content:center; color:#C8CCD8;">
              {ICONS['folder_lg']}
            </div>
            <div>
              <h1 data-testid="project-hero-title" style="font-size:28px; font-weight:700; letter-spacing:-0.5px; color:#F5F7FA;">ledger-svc</h1>
              <div class="mono" style="font-size:13px; color:#8A8E9B; margin-top:3px;">~/code/ledger-svc</div>
            </div>
          </div>

          <!-- Metadata Pills -->
          <div style="display:flex; align-items:center; gap:8px; margin-top:14px;">
            <span style="height:30px; padding:0 11px; border-radius:15px; background:#17181E; border:1px solid rgba(255,255,255,0.05); font-size:12px; color:#D5D8E2; display:inline-flex; align-items:center; gap:6px;">
              <span style="width:7px; height:7px; border-radius:50%; background:#57C88A;"></span>Local · MacBook Pro
            </span>
            <span style="height:30px; padding:0 11px; border-radius:15px; background:#17181E; border:1px solid rgba(255,255,255,0.05); font-size:12px; color:#D5D8E2; display:inline-flex; align-items:center; gap:5px;">
              {ICONS['branch']} main
            </span>
            <span style="height:30px; padding:0 11px; border-radius:15px; background:#17181E; border:1px solid rgba(255,255,255,0.05); font-size:12px; color:#D5D8E2; display:inline-flex; align-items:center;">
              5 conversations
            </span>
          </div>

          <!-- Primary CTA -->
          <button data-testid="btn-new-conv-in-project" class="cta-periwinkle" style="margin-top:16px; height:52px; border-radius:16px;">
            {ICONS['pencil']}<span>New Conversation in Project</span>
          </button>

          <!-- Underline Tabs -->
          <div style="margin-top:18px; border-bottom:1px solid rgba(255,255,255,0.07); display:flex; gap:20px;">
            <button data-testid="project-tab-active" data-tab="active" class="proj-tab" style="height:40px; border-bottom:2px solid #FFFFFF; font-size:14.5px; font-weight:700; color:#F5F7FA; cursor:pointer;">Active <span style="color:#9DA2B0; font-weight:500;">3</span></button>
            <button data-testid="project-tab-archived" data-tab="archived" class="proj-tab" style="height:40px; border-bottom:2px solid transparent; font-size:14.5px; font-weight:500; color:#7D818D; cursor:pointer;">Archived 2</button>
            <button data-testid="project-tab-automations" data-tab="automations" class="proj-tab" style="height:40px; border-bottom:2px solid transparent; font-size:14.5px; font-weight:500; color:#7D818D; cursor:pointer;">Automations 1</button>
          </div>

          <!-- Project Conversations Card -->
          <div data-testid="project-conv-list" class="card-group" style="margin-top:12px;">
            <div style="padding:13px 15px; display:flex; gap:11px; align-items:flex-start;">
              <span style="margin-top:2px; display:flex;">{ICONS['spinner_blue']}</span>
              <div style="flex:1;">
                <div style="display:flex; justify-content:space-between;">
                  <span style="font-size:15.5px; font-weight:600; color:#F5F7FA;">Add rate limiter to /transfers</span>
                  <span style="font-size:12.5px; color:#7D818D;">now</span>
                </div>
                <div style="font-size:13.5px; color:#7DA7FF; margin-top:3px;">Running · Step 4 of 7</div>
              </div>
            </div>
            <div class="divider"></div>
            <div style="padding:13px 15px; display:flex; gap:11px; align-items:flex-start;">
              <span class="amber-halo" style="margin-top:2px;"></span>
              <div style="flex:1;">
                <div style="display:flex; justify-content:space-between;">
                  <span style="font-size:15.5px; font-weight:600; color:#F5F7FA;">Fix flaky TestSettlementBatch</span>
                  <span style="font-size:12.5px; color:#7D818D;">8m</span>
                </div>
                <div style="font-size:13.5px; color:#EBB365; margin-top:3px;">Needs review · Implementation plan ready</div>
              </div>
            </div>
            <div class="divider"></div>
            <div style="padding:13px 15px; display:flex; gap:11px; align-items:flex-start;">
              <span style="width:18px; height:18px; display:inline-flex; align-items:center; justify-content:center; margin-top:2px;">
                <span style="width:8.5px; height:8.5px; border-radius:50%; background:#8EB4FF;"></span>
              </span>
              <div style="flex:1;">
                <div style="display:flex; justify-content:space-between;">
                  <span style="font-size:15.5px; font-weight:600; color:#F5F7FA;">Upgrade to Go 1.25</span>
                  <span style="font-size:12.5px; color:#7D818D;">1h</span>
                </div>
                <div style="font-size:13.5px; color:#8A8E9B; margin-top:3px;">Done · 6 files <span style="color:#57C88A; font-weight:600;">+42</span> <span style="color:#F07167; font-weight:600;">-31</span></div>
              </div>
            </div>
          </div>

          <!-- THIS PROJECT Tools -->
          <div class="section-label" style="margin-top:20px; margin-bottom:8px;">THIS PROJECT</div>
          <div class="card-group">
            <div data-testid="project-row-automation" style="min-height:58px; padding:10px 15px; display:flex; align-items:center; justify-content:space-between;">
              <div style="display:flex; align-items:center; gap:12px;">
                <span style="color:#A0A4B0; display:flex;">{ICONS['auto_tab']}</span>
                <div>
                  <div style="font-size:15px; font-weight:500; color:#F5F7FA;">Nightly dependency audit</div>
                  <div style="font-size:12.5px; color:#7D818D; margin-top:2px;">Daily 02:00 · Next run in 6h</div>
                </div>
              </div>
              <span style="color:#7D818D;">{ICONS['chev_right']}</span>
            </div>
            <div class="divider"></div>
            <div style="min-height:48px; padding:0 15px; display:flex; align-items:center; gap:12px;">
              <span style="color:#A0A4B0; display:flex;">{ICONS['laptop']}</span>
              <span style="font-size:15px; color:#F5F7FA;">Reveal in Finder on Mac</span>
            </div>
            <div class="divider"></div>
            <div data-testid="project-row-skills" style="min-height:48px; padding:0 15px; display:flex; align-items:center; justify-content:space-between;">
              <div style="display:flex; align-items:center; gap:12px;">
                <span style="color:#A0A4B0; display:flex;">{ICONS['doc']}</span>
                <span style="font-size:15px; color:#F5F7FA;">Project rules &amp; skills</span>
              </div>
              <span style="font-size:14px; color:#7D818D;">4</span>
            </div>
          </div>
        </div>
        """
        js = """
        document.querySelectorAll('.proj-tab').forEach(tab => {
          tab.addEventListener('click', () => {
            document.body.dataset.activeProjectTab = tab.dataset.tab;
            document.querySelectorAll('.proj-tab').forEach(t => {
              const active = t === tab;
              t.style.borderBottomColor = active ? '#FFFFFF' : 'transparent';
              t.style.color = active ? '#F5F7FA' : '#7D818D';
              t.style.fontWeight = active ? '700' : '500';
            });
          });
        });
        document.querySelector("[data-testid='btn-new-conv-in-project']").addEventListener('click', () => {
          document.body.dataset.newConvOpened = 'true';
          document.querySelector("[data-testid='btn-new-conv-in-project'] span").textContent = 'Opening ledger-svc Chat...';
        });
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE05_CREATE_PROJECT":
        body = f"""
        <div style="position:absolute; top:55px; left:0; right:0; bottom:0; background:#16171C; border-radius:28px 28px 0 0; border-top:1px solid rgba(255,255,255,0.08); padding:0 16px; display:flex; flex-direction:column;">
          <div class="sheet-grabber"></div>
          <div style="height:48px; display:flex; align-items:center; justify-content:space-between; margin-top:4px;">
            <button data-testid="btn-cancel-project" style="min-width:64px; min-height:44px; text-align:left; font-size:16px; color:#A0A4B0; cursor:pointer;">Cancel</button>
            <span style="font-size:17px; font-weight:700; color:#F5F7FA;">New Project</span>
            <span style="width:64px;"></span>
          </div>

          <div class="section-label" style="margin-top:10px; margin-bottom:8px;">RUNS ON</div>
          <div style="background:#202229; border-radius:14px; padding:4px; display:grid; grid-template-columns:1fr 1fr; gap:4px;">
            <button data-testid="seg-runs-on-mac" data-runtime="macbook_pro" class="runtime-seg" style="height:40px; border-radius:10px; display:flex; align-items:center; justify-content:center; gap:7px; font-size:14.5px; color:#A0A4B0; cursor:pointer;">
              {ICONS['laptop']}<span>MacBook Pro</span>
            </button>
            <button data-testid="seg-runs-on-cloud" data-runtime="cloud" class="runtime-seg" style="height:40px; border-radius:10px; background:#343741; display:flex; align-items:center; justify-content:center; gap:7px; font-size:14.5px; font-weight:700; color:#F5F7FA; cursor:pointer;">
              {ICONS['cloud']}<span>Cloud</span>
            </button>
          </div>
          <p id="runtime-desc" style="font-size:13px; line-height:18px; color:#8A8E9B; margin-top:8px;">
            Runs in its own cloud VM and keeps working while your computer sleeps.
          </p>

          <div class="section-label" style="margin-top:16px; margin-bottom:8px;">SOURCE</div>
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px;">
            <button data-testid="source-card-github" data-source="github" class="src-card" style="height:76px; padding:12px 14px; border-radius:16px; background:#202431; border:1.5px solid #8EB4FF; display:flex; flex-direction:column; justify-content:space-between; align-items:flex-start; cursor:pointer;">
              <span style="color:#8EB4FF;">{ICONS['branch']}</span>
              <span style="font-size:14.5px; font-weight:700; color:#F5F7FA;">GitHub repository</span>
            </button>
            <button data-testid="source-card-drive" data-source="drive" class="src-card" style="height:76px; padding:12px 14px; border-radius:16px; background:#1F2027; border:1.5px solid transparent; display:flex; flex-direction:column; justify-content:space-between; align-items:flex-start; cursor:pointer;">
              <span style="color:#A0A4B0;">{ICONS['folder']}</span>
              <span style="font-size:14.5px; font-weight:600; color:#E5E7EF;">Drive folder</span>
            </button>
          </div>

          <!-- Repo Search -->
          <div style="margin-top:12px; height:44px; border-radius:12px; background:#202229; padding:0 12px; display:flex; align-items:center; gap:8px;">
            <span style="color:#7D818D; display:flex;">{ICONS['search']}</span>
            <input data-testid="repo-search-input" type="text" placeholder="Search repositories" style="flex:1; height:44px; font-size:15px; color:#F5F7FA;" />
          </div>

          <!-- Repo List -->
          <div style="margin-top:10px; background:#202229; border-radius:16px; overflow:hidden;">
            <div data-testid="repo-row-ledger-svc" data-repo="acme/ledger-svc" class="repo-row" style="min-height:56px; padding:9px 14px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <div>
                <div class="mono" style="font-size:14px; color:#F5F7FA;">acme/ledger-svc</div>
                <div style="font-size:12px; color:#7D818D; margin-top:2px;">Private · Go · updated 2h ago</div>
              </div>
              <span class="repo-chk" style="color:#8EB4FF;">{ICONS['check']}</span>
            </div>
            <div class="divider"></div>
            <div data-repo="acme/web-console" class="repo-row" style="min-height:56px; padding:9px 14px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <div>
                <div class="mono" style="font-size:14px; color:#F5F7FA;">acme/web-console</div>
                <div style="font-size:12px; color:#7D818D; margin-top:2px;">Private · TypeScript · updated 1d ago</div>
              </div>
              <span class="repo-chk" style="color:#8EB4FF; display:none;">{ICONS['check']}</span>
            </div>
            <div class="divider"></div>
            <div data-repo="acme/design-tokens" class="repo-row" style="min-height:54px; padding:9px 14px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <div>
                <div class="mono" style="font-size:14px; color:#F5F7FA;">acme/design-tokens</div>
                <div style="font-size:12px; color:#7D818D; margin-top:2px;">Public · updated 5d ago</div>
              </div>
              <span class="repo-chk" style="color:#8EB4FF; display:none;">{ICONS['check']}</span>
            </div>
          </div>

          <div style="margin-top:9px; font-size:13px; color:#7DA7FF;">Missing a repo? Configure on GitHub</div>

          <!-- Worktree & Name -->
          <div style="margin-top:12px; background:#202229; border-radius:16px; overflow:hidden;">
            <div style="min-height:48px; padding:0 14px; display:flex; align-items:center; justify-content:space-between;">
              <span style="font-size:15px; color:#F5F7FA;">Branch &amp; worktree</span>
              <span style="font-size:14px; color:#8A8E9B; display:inline-flex; align-items:center; gap:5px;">main · New worktree {ICONS['chev_updown']}</span>
            </div>
            <div class="divider"></div>
            <div style="min-height:48px; padding:0 14px; display:flex; align-items:center; justify-content:space-between;">
              <span style="font-size:15px; color:#F5F7FA;">Name</span>
              <input id="project-name-input" type="text" value="ledger-svc-cloud" style="text-align:right; font-size:14.5px; color:#A5AAB8; width:180px;" />
            </div>
          </div>

          <button data-testid="btn-submit-create-project" class="cta-periwinkle" style="margin-top:auto; margin-bottom:26px; height:54px; border-radius:27px;">
            <span id="create-proj-label">Create Project</span>
          </button>
        </div>
        """
        js = """
        let selectedRuntime = 'cloud';
        let selectedSource = 'github';
        let selectedRepo = 'acme/ledger-svc';

        document.querySelectorAll('.runtime-seg').forEach(btn => {
          btn.addEventListener('click', () => {
            selectedRuntime = btn.dataset.runtime;
            document.querySelectorAll('.runtime-seg').forEach(b => {
              const active = b === btn;
              b.style.background = active ? '#343741' : 'transparent';
              b.style.color = active ? '#F5F7FA' : '#A0A4B0';
              b.style.fontWeight = active ? '700' : '400';
            });
          });
        });
        document.querySelectorAll('.src-card').forEach(card => {
          card.addEventListener('click', () => {
            selectedSource = card.dataset.source;
            document.querySelectorAll('.src-card').forEach(c => {
              const active = c === card;
              c.style.borderColor = active ? '#8EB4FF' : 'transparent';
              c.style.background = active ? '#202431' : '#1F2027';
            });
          });
        });
        document.querySelectorAll('.repo-row').forEach(row => {
          row.addEventListener('click', () => {
            selectedRepo = row.dataset.repo;
            document.querySelectorAll('.repo-row .repo-chk').forEach(chk => chk.style.display = 'none');
            row.querySelector('.repo-chk').style.display = 'inline';
          });
        });
        document.querySelector("[data-testid='btn-submit-create-project']").addEventListener('click', async () => {
          const name = document.getElementById('project-name-input').value;
          const resp = await window.__AGY_RPC('CreateProjectWorkspace', {
            name,
            runtime: selectedRuntime,
            sourceType: selectedSource,
            repository: selectedRepo,
            branch: 'main',
            worktree: 'new'
          });
          document.body.dataset.createdProject = name;
          document.getElementById('create-proj-label').textContent = 'Created ' + name + ' ✓';
        });
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE06_AUTOMATIONS":
        body = f"""
        <div style="padding:56px 16px 0 16px; display:flex; flex-direction:column;">
          <div style="display:flex; justify-content:flex-end;">
            <button class="circle-icon-btn">{ICONS['filter_bars']}</button>
          </div>
          <h1 style="font-size:34px; font-weight:700; letter-spacing:-0.7px; margin-top:8px; color:#F5F7FA;">Automations</h1>

          <!-- NL Quick-Create Bar -->
          <div style="margin-top:12px; height:52px; border-radius:18px; background:#141519; border:1px solid rgba(255,255,255,0.08); padding:0 8px 0 13px; display:flex; align-items:center; gap:9px;">
            <span style="color:#8A8E9B; display:flex;">{ICONS['bolt']}</span>
            <input data-testid="automation-prompt-input" type="text" placeholder="Every weekday at 9, summarize" style="flex:1; height:48px; font-size:14.5px; color:#F5F7FA; min-width:0;" />
            <button data-testid="btn-create-automation-inline" style="height:36px; min-width:68px; padding:0 14px; border-radius:18px; background:#23252E; color:#F5F7FA; font-size:13.5px; font-weight:600; cursor:pointer;">Create</button>
          </div>

          <div id="scheduled-header" class="section-label" style="margin-top:18px; margin-bottom:8px;">SCHEDULED · 2</div>

          <!-- Scheduled Card 1 -->
          <div data-testid="automation-card-nightly" class="card-group" style="padding:15px;">
            <div style="display:flex; align-items:center; justify-content:space-between; gap:10px;">
              <div>
                <div style="font-size:16px; font-weight:700; color:#F5F7FA;">Nightly dependency audit</div>
                <div style="font-size:12.5px; color:#7D818D; margin-top:3px;">ledger-svc · Daily at 02:00 · Flash</div>
              </div>
              <button data-testid="btn-run-nightly" style="width:44px; height:44px; border-radius:22px; background:#1D2434; display:flex; align-items:center; justify-content:center; cursor:pointer; flex-shrink:0;">
                {ICONS['play']}
              </button>
            </div>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:12px;">
              <div style="background:#1B1C22; border-radius:12px; padding:10px 12px;">
                <div style="font-size:10.5px; font-weight:600; color:#7D818D; letter-spacing:0.5px;">NEXT RUN</div>
                <div style="font-size:14px; font-weight:500; color:#F5F7FA; margin-top:3px;">Tonight, 02:00</div>
              </div>
              <div style="background:#1B1C22; border-radius:12px; padding:10px 12px;">
                <div style="font-size:10.5px; font-weight:600; color:#7D818D; letter-spacing:0.5px;">LAST RUN</div>
                <div id="nightly-last-run" style="font-size:13.5px; color:#F5F7FA; margin-top:3px; display:flex; align-items:center; gap:5px;">
                  <span style="color:#57C88A;">✓</span><span>Succeeded · 22h ago</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Scheduled Card 2 -->
          <div data-testid="automation-card-flaky" class="card-group" style="padding:15px; margin-top:10px;">
            <div style="display:flex; align-items:center; justify-content:space-between; gap:10px;">
              <div>
                <div style="font-size:16px; font-weight:700; color:#F5F7FA;">Weekly flaky-test report</div>
                <div style="font-size:12.5px; color:#7D818D; margin-top:3px;">ledger-svc · Mondays at 09:00 · Pro</div>
              </div>
              <button style="width:44px; height:44px; border-radius:22px; background:#1D2434; display:flex; align-items:center; justify-content:center; flex-shrink:0;">
                {ICONS['play']}
              </button>
            </div>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:12px;">
              <div style="background:#1B1C22; border-radius:12px; padding:10px 12px;">
                <div style="font-size:10.5px; font-weight:600; color:#7D818D; letter-spacing:0.5px;">NEXT RUN</div>
                <div style="font-size:14px; font-weight:500; color:#F5F7FA; margin-top:3px;">Mon, 09:00</div>
              </div>
              <div style="background:rgba(235,179,101,0.12); border-radius:12px; padding:10px 12px;">
                <div style="font-size:10.5px; font-weight:700; color:#EBB365; letter-spacing:0.5px;">LAST RUN</div>
                <div style="font-size:13.5px; font-weight:500; color:#EBB365; margin-top:3px;">Needs review · 2d</div>
              </div>
            </div>
          </div>

          <div class="section-label" style="margin-top:16px; margin-bottom:8px;">ALWAYS ON · 1</div>
          <div data-testid="automation-card-always-on" class="card-group" style="padding:14px 15px; display:flex; align-items:center; justify-content:space-between;">
            <div style="display:flex; align-items:center; gap:11px;">
              <span class="green-halo"></span>
              <div>
                <div style="font-size:15.5px; font-weight:600; color:#F5F7FA;">Triage new pull requests</div>
                <div style="font-size:12.5px; color:#7D818D; margin-top:2px;">web-console · On PR opened · Flash Lite</div>
                <div style="font-size:12.5px; color:#9EA2B0; margin-top:2px;">Last run 14m ago</div>
              </div>
            </div>
            <span style="color:#7D818D;">{ICONS['chev_right']}</span>
          </div>

          <div id="paused-header" class="section-label" style="margin-top:14px; margin-bottom:7px;">PAUSED · 1</div>
          <div class="card-group" style="padding:12px 15px; display:flex; align-items:center; justify-content:space-between;">
            <div>
              <div style="font-size:15.5px; font-weight:600; color:#A0A4B0;">Bundle size watch</div>
              <div id="paused-sub" style="font-size:12px; color:#6D707D;">web-console · Daily at 08:00</div>
            </div>
            <button data-testid="btn-resume-paused" style="height:36px; padding:0 15px; border-radius:18px; background:#23252E; color:#D5D8E2; font-size:13.5px; font-weight:600; cursor:pointer; position:relative; z-index:45;">Resume</button>
          </div>
        </div>
        {_floating_tab_bar("automations", "fab-add-automation", "plus")}
        """
        js = """
        let schedCount = 2;
        document.querySelector("[data-testid='btn-create-automation-inline']").addEventListener('click', async () => {
          const inp = document.querySelector("[data-testid='automation-prompt-input']");
          const prompt = inp.value || 'Every weekday at 9, summarize';
          await window.__AGY_RPC('CreateAutomation', { prompt, project: 'ledger-svc' });
          schedCount += 1;
          document.getElementById('scheduled-header').textContent = 'SCHEDULED · ' + schedCount;
          document.body.dataset.createdAutomation = prompt;
          inp.value = '';
        });
        document.querySelector("[data-testid='btn-run-nightly']").addEventListener('click', async () => {
          await window.__AGY_RPC('TriggerAutomationNow', { automationId: 'auto-nightly-audit' });
          document.getElementById('nightly-last-run').innerHTML = '<span style="color:#7DA7FF;">●</span><span>Running now · triggered</span>';
          document.body.dataset.nightlyTriggered = 'true';
        });
        document.querySelector("[data-testid='btn-resume-paused']").addEventListener('click', async () => {
          await window.__AGY_RPC('ResumeAutomation', { automationId: 'auto-bundle-watch' });
          document.getElementById('paused-header').textContent = 'PAUSED · 0';
          document.getElementById('paused-sub').textContent = 'Active · Resumed';
          document.body.dataset.resumedPaused = 'true';
        });
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE07_CHAT_AND_COMPOSER":
        body = f"""
        <div style="padding:56px 16px 0 16px; display:flex; flex-direction:column; height:100%;">
          <!-- Top Bar -->
          <div style="display:flex; align-items:center; justify-content:space-between; gap:8px; padding-bottom:10px; border-bottom:1px solid rgba(255,255,255,0.06);">
            <div style="display:flex; align-items:center; gap:8px; min-width:0;">
              <span style="color:#8EB4FF; display:flex;">{ICONS['chev_left']}</span>
              <div style="min-width:0;">
                <div style="font-size:15.5px; font-weight:700; color:#F5F7FA; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">Add rate limiter to /tran...</div>
                <div style="font-size:11.5px; color:#7D818D;">ledger-svc · main · MacBook Pro</div>
              </div>
            </div>
            <div style="display:flex; align-items:center; gap:8px; flex-shrink:0;">
              <button data-testid="chat-diff-pill" class="mono" style="height:32px; padding:0 10px; border-radius:16px; background:#191B22; border:1px solid rgba(255,255,255,0.07); font-size:12.5px; font-weight:600; cursor:pointer;">
                <span style="color:#57C88A;">+128</span> <span style="color:#F07167;">-14</span>
              </button>
              <span style="color:#D5D8E2; display:flex;">{ICONS['dots']}</span>
            </div>
          </div>

          <!-- Clipped Previous User Message Peek -->
          <div style="align-self:flex-end; width:318px; height:24px; background:#1A1C23; border-radius:0 0 16px 16px; padding:0 12px; display:flex; align-items:flex-start; gap:8px; overflow:hidden; opacity:0.88;">
            <span class="mono" style="margin-top:-7px; font-size:12px; background:#252832; padding:3px 9px; border-radius:9px; color:#D5D8E2;">@transfers.go</span>
            <span style="margin-top:-7px; font-size:12px; background:#252832; padding:3px 9px; border-radius:9px; color:#D5D8E2;">Skill · go-testing</span>
          </div>

          <!-- Thought Row -->
          <button data-testid="row-thought-14s" data-expanded="false" style="margin-top:12px; min-height:30px; display:inline-flex; align-items:center; gap:7px; color:#8A8E9B; font-size:13.5px; cursor:pointer; align-self:flex-start;">
            <span>{ICONS['planet']}</span><span>Thought for 14s</span><span>{ICONS['chev_right']}</span>
          </button>
          <div id="thought-drawer" style="display:none; font-size:12px; color:#8A8E9B; background:#141519; padding:8px 10px; border-radius:10px; margin-top:4px;">
            Verified token-bucket middleware concurrency and staging vegeta rate ceiling.
          </div>

          <!-- Agent Prose -->
          <p style="font-size:15px; line-height:21.5px; color:#F0F2F7; margin-top:8px;">
            Plan approved with your 2 comments. Tests pass — next is a load test, which needs your OK.
          </p>

          <!-- Implementation Plan Card -->
          <div data-testid="card-artifact-plan" class="card-group" style="margin-top:12px; padding:11px 13px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
            <div style="display:flex; align-items:center; gap:11px;">
              <div style="width:36px; height:36px; border-radius:10px; background:#192236; color:#7DA7FF; display:flex; align-items:center; justify-content:center;">
                {ICONS['doc']}
              </div>
              <div>
                <div style="font-size:14.5px; font-weight:600; color:#F5F7FA;">Implementation Plan</div>
                <div style="font-size:12.5px; color:#8A8E9B; margin-top:1px;">Approved · 2 comments addressed</div>
              </div>
            </div>
            <span style="color:#7D818D;">{ICONS['chev_right']}</span>
          </div>

          <!-- 7-Segment Task Progress Card -->
          <div data-testid="card-task-progress-7seg" class="card-group" style="margin-top:10px; padding:13px 14px;">
            <div style="display:flex; justify-content:space-between; align-items:center;">
              <span style="font-size:14.5px; font-weight:700; color:#F5F7FA;">Task · 4 of 7 done</span>
              <span style="font-size:12.5px; color:#7D818D;">2m 41s</span>
            </div>
            <div style="display:grid; grid-template-columns:repeat(7, 1fr); gap:4px; margin-top:10px;">
              <span class="seg-bar" data-seg="1" style="height:4px; border-radius:2px; background:#7DA7FF;"></span>
              <span class="seg-bar" data-seg="2" style="height:4px; border-radius:2px; background:#7DA7FF;"></span>
              <span class="seg-bar" data-seg="3" style="height:4px; border-radius:2px; background:#7DA7FF;"></span>
              <span class="seg-bar" data-seg="4" style="height:4px; border-radius:2px; background:#7DA7FF;"></span>
              <span id="seg-5" class="seg-bar" data-seg="5" style="height:4px; border-radius:2px; background:#EBB365;"></span>
              <span class="seg-bar" data-seg="6" style="height:4px; border-radius:2px; background:#272A34;"></span>
              <span class="seg-bar" data-seg="7" style="height:4px; border-radius:2px; background:#272A34;"></span>
            </div>
            <div style="margin-top:11px; display:flex; flex-direction:column; gap:6px; font-size:13.5px;">
              <div style="display:flex; align-items:center; gap:8px; color:#8A8E9B;">
                <span style="color:#57C88A;">✓</span><span>Wire limiter into router</span>
              </div>
              <div style="display:flex; align-items:center; justify-content:space-between;">
                <div style="display:flex; align-items:center; gap:8px; color:#8A8E9B;">
                  <span style="color:#57C88A;">✓</span><span class="mono" style="font-size:12.5px;">go test ./internal/...</span>
                </div>
                <span style="color:#57C88A; font-size:13px; font-weight:500;">42 passed</span>
              </div>
              <div style="display:flex; align-items:center; gap:8px; color:#EBB365; font-weight:500;">
                <span style="width:7px; height:7px; border-radius:50%; background:#EBB365; margin-left:3px;"></span>
                <span id="task-step5-text">Load test with vegeta</span>
              </div>
            </div>
          </div>

          <!-- Command Approval Gate Card -->
          <div data-testid="card-command-approval" style="margin-top:10px; background:#171511; border:1px solid rgba(235,179,101,0.26); border-radius:18px; padding:13px 14px;">
            <div style="display:flex; align-items:center; gap:8px; color:#EBB365; font-size:14px; font-weight:600;">
              {ICONS['terminal']}<span>Run this command?</span>
            </div>
            <div class="mono" style="margin-top:10px; background:#0D0E11; border-radius:12px; padding:10px 12px; font-size:12px; line-height:17.5px; color:#E5E7EF;">
              vegeta attack -rate=2000/s -duration=30s \<br/>
              &nbsp;&nbsp;-targets=load/transfers.txt | vegeta<br/>
              report
            </div>
            <div style="display:grid; grid-template-columns:1fr 1.15fr; gap:10px; margin-top:11px;">
              <button data-testid="btn-command-deny" style="height:44px; border-radius:12px; background:#252422; color:#F5F7FA; font-size:14.5px; font-weight:600; cursor:pointer;">Deny</button>
              <button data-testid="btn-command-allow-faceid" style="height:44px; border-radius:12px; background:#EBB365; color:#0A0E17; font-size:14.5px; font-weight:700; display:flex; align-items:center; justify-content:center; gap:7px; cursor:pointer;">
                {ICONS['faceid']}<span id="allow-btn-label">Allow</span>
              </button>
            </div>
          </div>

          <!-- Turn Status Row -->
          <div style="margin-top:10px; display:flex; align-items:center; justify-content:space-between;">
            <div id="turn-status-label" style="display:flex; align-items:center; gap:7px; font-size:13px; color:#EBB365; font-weight:500;">
              <span style="width:7px; height:7px; border-radius:50%; background:#EBB365;"></span>
              <span>Waiting for your approval · Step 5 of 7</span>
            </div>
            <button data-testid="btn-stop-turn" style="height:32px; padding:0 12px; border-radius:16px; background:#1B1C22; color:#F5F7FA; font-size:12.5px; font-weight:600; display:inline-flex; align-items:center; gap:6px; cursor:pointer;">
              <span style="width:8px; height:8px; border-radius:2px; background:#F5F7FA;"></span>Stop
            </button>
          </div>

          <!-- User Sent Message Container (populated dynamically on Send) -->
          <div id="sent-messages-box" style="display:none; font-size:12px; color:#8EB4FF; margin-top:4px;"></div>

          <!-- Chat Composer -->
          <div style="margin-top:auto; margin-bottom:20px; background:#17181E; border:1px solid rgba(255,255,255,0.08); border-radius:24px; padding:11px 12px;">
            <div id="composer-chips-row" style="display:flex; align-items:center; gap:6px; margin-bottom:7px;">
              <span data-testid="composer-chip-ratelimit" class="mono" style="height:28px; padding:0 10px; border-radius:14px; background:#252730; font-size:12px; color:#D5D8E2; display:inline-flex; align-items:center; gap:6px;">
                @ratelimit.go <span style="color:#8A8E9B;">×</span>
              </span>
            </div>
            <textarea id="composer-input" data-testid="composer-text-input" rows="2" style="width:100%; resize:none; font-size:15px; line-height:20px; color:#F5F7FA;">Use 1000/s instead — staging is smaller than prod.</textarea>
            <div style="display:flex; align-items:center; justify-content:space-between; margin-top:8px;">
              <div style="display:flex; align-items:center; gap:7px;">
                <button data-testid="composer-btn-add-context" style="width:36px; height:36px; border-radius:18px; background:#252730; color:#E5E7EF; display:flex; align-items:center; justify-content:center; cursor:pointer;">{ICONS['plus']}</button>
                <button data-testid="composer-pill-mode" style="height:34px; padding:0 12px; border-radius:17px; background:#252730; color:#F5F7FA; font-size:13px; font-weight:600; display:inline-flex; align-items:center; gap:5px; cursor:pointer;">Planning {ICONS['chev_down']}</button>
                <button data-testid="composer-pill-model" style="height:34px; padding:0 12px; border-radius:17px; background:#252730; color:#D5D8E2; font-size:13px; font-weight:500; display:inline-flex; align-items:center; gap:5px; cursor:pointer;">Gemini 3.1 Pro {ICONS['chev_down']}</button>
              </div>
              <div style="display:flex; align-items:center; gap:10px;">
                <span style="color:#9EA2B0; display:flex;">{ICONS['mic']}</span>
                <button data-testid="composer-btn-send" style="width:38px; height:38px; border-radius:19px; background:#8EB4FF; color:#0A0E17; display:flex; align-items:center; justify-content:center; cursor:pointer;">{ICONS['arrow_up']}</button>
              </div>
            </div>
          </div>
        </div>
        """
        js = """
        const thoughtBtn = document.querySelector("[data-testid='row-thought-14s']");
        thoughtBtn.addEventListener('click', () => {
          const next = thoughtBtn.dataset.expanded !== 'true';
          thoughtBtn.dataset.expanded = String(next);
          document.getElementById('thought-drawer').style.display = next ? 'block' : 'none';
        });
        document.querySelector("[data-testid='btn-command-allow-faceid']").addEventListener('click', async () => {
          const resp = await window.__AGY_RPC('HandleCascadeUserInteraction', {
            interaction: {
              trajectoryId: 'cas-rate-limiter',
              stepIndex: 5,
              biometricConfirmed: true,
              runCommand: {
                confirm: true,
                commandLine: 'vegeta attack -rate=2000/s -duration=30s -targets=load/transfers.txt | vegeta report'
              }
            }
          }, { 'X-FaceID-Signature': 'LAContext-FaceID-Signed-Step5' });
          document.body.dataset.commandStatus = 'running';
          document.getElementById('allow-btn-label').textContent = 'Approved ✓';
          document.getElementById('seg-5').style.background = '#7DA7FF';
          document.getElementById('turn-status-label').style.color = '#7DA7FF';
          document.getElementById('turn-status-label').innerHTML = '<span style="width:7px;height:7px;border-radius:50%;background:#7DA7FF;"></span><span>Running · Step 5 of 7 · Approved via Face ID</span>';
        });
        document.querySelector("[data-testid='composer-btn-send']").addEventListener('click', async () => {
          const input = document.getElementById('composer-input');
          const text = input.value.trim();
          await window.__AGY_RPC('SendUserCascadeMessage', {
            cascadeId: 'cas-rate-limiter',
            text,
            contextChips: ['@ratelimit.go']
          });
          document.body.dataset.lastSentMessage = text;
          const sentBox = document.getElementById('sent-messages-box');
          sentBox.style.display = 'block';
          sentBox.textContent = 'Sent: ' + text;
          input.value = '';
          const chip = document.querySelector("[data-testid='composer-chip-ratelimit']");
          if (chip) chip.style.display = 'none';
        });
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE08_ADD_CONTEXT":
        body = f"""
        <div style="position:absolute; top:65px; left:0; right:0; bottom:0; background:#16171C; border-radius:28px 28px 0 0; border-top:1px solid rgba(255,255,255,0.08); display:flex; flex-direction:column;">
          <div style="padding:0 16px;">
            <div class="sheet-grabber"></div>
            <div style="height:48px; display:flex; align-items:center; justify-content:space-between; margin-top:4px;">
              <span style="width:34px;"></span>
              <span style="font-size:17.5px; font-weight:700; color:#F5F7FA;">Add Context</span>
              <button style="width:34px; height:34px; border-radius:17px; background:#262831; color:#D5D8E2; display:flex; align-items:center; justify-content:center;">{ICONS['close']}</button>
            </div>

            <!-- Search Bar -->
            <div style="margin-top:8px; height:44px; border-radius:13px; background:#202229; padding:0 13px; display:flex; align-items:center; gap:9px;">
              <span style="color:#7D818D; display:flex;">{ICONS['search']}</span>
              <input data-testid="context-search-input" type="text" placeholder="Search files, folders, skills..." style="flex:1; height:44px; font-size:15px; color:#F5F7FA;" />
            </div>

            <!-- 5 Category Tiles -->
            <div style="display:grid; grid-template-columns:repeat(5, 1fr); gap:8px; margin-top:14px;">
              <button data-testid="tile-files" data-cat="files" class="ctx-tile" style="height:68px; border-radius:15px; background:#202229; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:6px; font-size:12px; font-weight:600; color:#E5E7EF; cursor:pointer;">
                {ICONS['doc']}<span>Files</span>
              </button>
              <button data-testid="tile-folder" data-cat="folder" class="ctx-tile" style="height:68px; border-radius:15px; background:#202229; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:6px; font-size:12px; font-weight:600; color:#E5E7EF; cursor:pointer;">
                {ICONS['folder']}<span>Folder</span>
              </button>
              <button data-testid="tile-mentions" data-cat="mentions" class="ctx-tile" style="height:68px; border-radius:15px; background:#202229; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:6px; font-size:12px; font-weight:600; color:#E5E7EF; cursor:pointer;">
                {ICONS['at']}<span>Mentions</span>
              </button>
              <button data-testid="tile-actions" data-cat="actions" class="ctx-tile" style="height:68px; border-radius:15px; background:#202229; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:6px; font-size:12px; font-weight:600; color:#E5E7EF; cursor:pointer;">
                {ICONS['bolt']}<span>Actions</span>
              </button>
              <button data-testid="tile-skills" data-cat="skills" class="ctx-tile" style="height:68px; border-radius:15px; background:#202229; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:6px; font-size:12px; font-weight:600; color:#E5E7EF; cursor:pointer;">
                {ICONS['cube']}<span>Skills</span>
              </button>
            </div>

            <!-- FILES & FOLDERS -->
            <div class="section-label" style="margin-top:16px; margin-bottom:7px;">FILES &amp; FOLDERS</div>
            <div style="background:#202229; border-radius:16px; overflow:hidden;">
              <div data-testid="ctx-row-ratelimit" data-item="ratelimit.go" data-selected="true" class="ctx-select-row" style="min-height:56px; padding:9px 14px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
                <div style="display:flex; align-items:center; gap:11px;">
                  <span style="color:#9EA2B0;">{ICONS['doc']}</span>
                  <div>
                    <div class="mono" style="font-size:14px; color:#F5F7FA;">ratelimit.go</div>
                    <div style="font-size:12px; color:#7D818D; margin-top:2px;">internal/middleware · changed this turn</div>
                  </div>
                </div>
                <span class="ctx-circle" style="width:23px; height:23px; border-radius:12px; background:#8EB4FF; color:#0A0E17; display:flex; align-items:center; justify-content:center;">{ICONS['check']}</span>
              </div>
              <div class="divider"></div>
              <div data-item="load/" data-selected="false" class="ctx-select-row" style="min-height:54px; padding:9px 14px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
                <div style="display:flex; align-items:center; gap:11px;">
                  <span style="color:#9EA2B0;">{ICONS['folder']}</span>
                  <div>
                    <div class="mono" style="font-size:14px; color:#F5F7FA;">load/</div>
                    <div style="font-size:12px; color:#7D818D; margin-top:2px;">Folder · 3 files</div>
                  </div>
                </div>
                <span class="ctx-circle" style="width:23px; height:23px; border-radius:12px; border:1.5px solid #4A4E5B;"></span>
              </div>
            </div>

            <!-- MENTIONS -->
            <div class="section-label" style="margin-top:14px; margin-bottom:7px;">MENTIONS</div>
            <div style="background:#202229; border-radius:16px; overflow:hidden;">
              <div data-testid="ctx-row-payouts" data-item="Idempotency keys for payouts" data-selected="true" class="ctx-select-row" style="min-height:56px; padding:9px 14px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
                <div style="display:flex; align-items:center; gap:11px;">
                  <span style="color:#9EA2B0;">{ICONS['comment']}</span>
                  <div>
                    <div style="font-size:14.5px; font-weight:500; color:#F5F7FA;">Idempotency keys for payouts</div>
                    <div style="font-size:12px; color:#7D818D; margin-top:2px;">Conversation · ledger-svc</div>
                  </div>
                </div>
                <span class="ctx-circle" style="width:23px; height:23px; border-radius:12px; background:#8EB4FF; color:#0A0E17; display:flex; align-items:center; justify-content:center;">{ICONS['check']}</span>
              </div>
              <div class="divider"></div>
              <div data-item="Terminal · last test run" data-selected="false" class="ctx-select-row" style="min-height:54px; padding:9px 14px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
                <div style="display:flex; align-items:center; gap:11px;">
                  <span style="color:#9EA2B0;">{ICONS['terminal']}</span>
                  <div>
                    <div style="font-size:14.5px; color:#F5F7FA;">Terminal · last test run</div>
                    <div style="font-size:12px; color:#7D818D; margin-top:2px;">Output · 214 lines</div>
                  </div>
                </div>
                <span class="ctx-circle" style="width:23px; height:23px; border-radius:12px; border:1.5px solid #4A4E5B;"></span>
              </div>
            </div>

            <!-- ACTIONS & SKILLS -->
            <div class="section-label" style="margin-top:14px; margin-bottom:7px;">ACTIONS &amp; SKILLS</div>
            <div style="background:#202229; border-radius:16px; overflow:hidden;">
              <div style="min-height:52px; padding:8px 14px; display:flex; align-items:center; justify-content:space-between;">
                <div style="display:flex; align-items:center; gap:11px;">
                  <span style="color:#9EA2B0;">{ICONS['bolt']}</span>
                  <div>
                    <div class="mono" style="font-size:14px; color:#F5F7FA;">/boost</div>
                    <div style="font-size:12px; color:#7D818D; margin-top:1px;">Action · extra multi-agent reasoning pass</div>
                  </div>
                </div>
                <span style="color:#8A8E9B;">{ICONS['plus']}</span>
              </div>
              <div class="divider"></div>
              <div data-testid="ctx-row-go-testing" data-item="go-testing" data-selected="true" class="ctx-select-row" style="min-height:54px; padding:8px 14px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
                <div style="display:flex; align-items:center; gap:11px;">
                  <span style="color:#9EA2B0;">{ICONS['cube']}</span>
                  <div>
                    <div style="font-size:14.5px; font-weight:500; color:#F5F7FA;">go-testing</div>
                    <div style="font-size:12px; color:#7D818D; margin-top:1px;">Skill · table-driven tests, -race, golden files</div>
                  </div>
                </div>
                <span class="ctx-circle" style="width:23px; height:23px; border-radius:12px; background:#8EB4FF; color:#0A0E17; display:flex; align-items:center; justify-content:center;">{ICONS['check']}</span>
              </div>
            </div>
          </div>

          <!-- Bottom Sticky Bar -->
          <div style="margin-top:auto; border-top:1px solid rgba(255,255,255,0.07); padding:12px 16px 24px 16px; display:flex; align-items:center; justify-content:space-between;">
            <span id="ctx-selected-label" style="font-size:14.5px; color:#9EA2B0;">3 selected</span>
            <button data-testid="btn-add-to-message" class="cta-periwinkle" style="min-height:46px; padding:0 22px; border-radius:23px;">
              <span id="add-ctx-btn-label">Add to message</span>
            </button>
          </div>
        </div>
        """
        js = f"""
        const checkHtml = `{ICONS['check']}`;
        function updateCtxCount() {{
          const selected = Array.from(document.querySelectorAll('.ctx-select-row'))
            .filter(r => r.dataset.selected === 'true')
            .map(r => r.dataset.item);
          document.getElementById('ctx-selected-label').textContent = selected.length + ' selected';
          return selected;
        }}
        document.querySelectorAll('.ctx-tile').forEach(tile => {{
          tile.addEventListener('click', () => {{
            document.body.dataset.activeCategory = tile.dataset.cat;
            document.querySelectorAll('.ctx-tile').forEach(t => t.style.outline = t === tile ? '1.5px solid #8EB4FF' : 'none');
          }});
        }});
        document.querySelectorAll('.ctx-select-row').forEach(row => {{
          row.addEventListener('click', () => {{
            const next = row.dataset.selected !== 'true';
            row.dataset.selected = String(next);
            const c = row.querySelector('.ctx-circle');
            if (next) {{
              c.style.background = '#8EB4FF';
              c.style.border = 'none';
              c.style.color = '#0A0E17';
              c.innerHTML = checkHtml;
            }} else {{
              c.style.background = 'transparent';
              c.style.border = '1.5px solid #4A4E5B';
              c.innerHTML = '';
            }}
            updateCtxCount();
          }});
        }});
        document.querySelector("[data-testid='btn-add-to-message']").addEventListener('click', () => {{
          const items = updateCtxCount();
          document.body.dataset.injectedChips = items.join(',');
          document.getElementById('add-ctx-btn-label').textContent = 'Added ' + items.length + ' items ✓';
        }});
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE09_MODEL_AND_MODE":
        body = f"""
        <!-- Subtle Dimmed Chat Shapes Above Sheet -->
        <div style="padding:70px 16px 0 16px; opacity:0.25;">
          <div style="height:44px; border-radius:14px; background:#191B22;"></div>
          <div style="height:54px; width:260px; margin-left:auto; margin-top:18px; border-radius:18px; background:#1D2028;"></div>
        </div>

        <div style="position:absolute; top:177px; left:0; right:0; bottom:0; background:#16171C; border-radius:28px 28px 0 0; border-top:1px solid rgba(255,255,255,0.08); padding:0 16px;">
          <div class="sheet-grabber"></div>
          <div style="height:48px; display:flex; align-items:center; justify-content:space-between; margin-top:4px;">
            <span style="width:54px;"></span>
            <span style="font-size:17.5px; font-weight:700; color:#F5F7FA;">Model &amp; Mode</span>
            <button data-testid="btn-model-done" style="min-width:54px; min-height:44px; text-align:right; font-size:16px; font-weight:700; color:#8EB4FF; cursor:pointer;">Done</button>
          </div>

          <!-- Mode Cards -->
          <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:10px;">
            <button data-testid="mode-card-planning" data-mode="Planning" class="mode-card" style="padding:14px; border-radius:18px; background:#202533; border:1.5px solid #8EB4FF; text-align:left; cursor:pointer;">
              <div style="display:flex; align-items:center; gap:7px; font-size:15.5px; font-weight:700; color:#F5F7FA;">
                <span style="color:#8EB4FF;">{ICONS['doc']}</span><span>Planning</span>
              </div>
              <p style="font-size:12.5px; line-height:17.5px; color:#A5AAB8; margin-top:8px;">
                Plans first and writes artifacts for you to review
              </p>
            </button>
            <button data-testid="mode-card-fast" data-mode="Fast" class="mode-card" style="padding:14px; border-radius:18px; background:#202229; border:1.5px solid transparent; text-align:left; cursor:pointer;">
              <div style="display:flex; align-items:center; gap:7px; font-size:15.5px; font-weight:700; color:#F5F7FA;">
                <span style="color:#9EA2B0;">{ICONS['bolt']}</span><span>Fast</span>
              </div>
              <p style="font-size:12.5px; line-height:17.5px; color:#8A8E9B; margin-top:8px;">
                Acts directly — best for small, local edits
              </p>
            </button>
          </div>

          <div class="section-label" style="margin-top:18px; margin-bottom:8px;">MODEL</div>
          <div style="background:#202229; border-radius:16px; overflow:hidden;">
            <div data-testid="model-row-gemini-pro" data-model="Gemini 3.1 Pro" class="model-row" style="min-height:58px; padding:10px 15px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <div>
                <div style="font-size:15.5px; font-weight:700; color:#F5F7FA;">Gemini 3.1 Pro</div>
                <div style="font-size:12.5px; color:#8A8E9B; margin-top:2px;">Deep reasoning for long, multi-step tasks</div>
              </div>
              <span class="model-chk" style="color:#8EB4FF;">{ICONS['check']}</span>
            </div>
            <div class="divider"></div>
            <div data-testid="model-row-gemini-flash" data-model="Gemini 3.8 Flash" class="model-row" style="min-height:58px; padding:10px 15px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <div>
                <div style="font-size:15.5px; font-weight:500; color:#F5F7FA;">Gemini 3.8 Flash</div>
                <div style="font-size:12.5px; color:#8A8E9B; margin-top:2px;">Fastest responses, lowest cost</div>
              </div>
              <span class="model-chk" style="color:#8EB4FF; display:none;">{ICONS['check']}</span>
            </div>
            <div class="divider"></div>
            <div data-testid="model-row-claude-opus" data-model="Claude Opus 5.5" class="model-row" style="min-height:58px; padding:10px 15px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <div>
                <div style="display:flex; align-items:center; gap:7px;">
                  <span style="font-size:15.5px; font-weight:500; color:#F5F7FA;">Claude Opus 5.5</span>
                  <span style="font-size:11px; font-weight:600; padding:2px 7px; border-radius:6px; background:#2E313B; color:#B8BCC8;">Thinking</span>
                </div>
                <div style="font-size:12.5px; color:#8A8E9B; margin-top:2px;">Requires Google AI Pro or Ultra</div>
              </div>
              <span class="model-chk" style="color:#8EB4FF; display:none;">{ICONS['check']}</span>
            </div>
            <div class="divider"></div>
            <div data-testid="model-row-claude-sonnet" data-model="Claude Sonnet 5.5" class="model-row" style="min-height:58px; padding:10px 15px; display:flex; align-items:center; justify-content:space-between; cursor:pointer;">
              <div>
                <div style="display:flex; align-items:center; gap:7px;">
                  <span style="font-size:15.5px; font-weight:500; color:#F5F7FA;">Claude Sonnet 5.5</span>
                  <span style="font-size:11px; font-weight:600; padding:2px 7px; border-radius:6px; background:#2E313B; color:#B8BCC8;">Thinking</span>
                </div>
                <div style="font-size:12.5px; color:#8A8E9B; margin-top:2px;">Requires Google AI Pro or Ultra</div>
              </div>
              <span class="model-chk" style="color:#8EB4FF; display:none;">{ICONS['check']}</span>
            </div>
          </div>

          <div style="font-size:12.5px; color:#7D818D; margin-top:9px;">A new model takes effect on the next turn.</div>

          <div class="section-label" style="margin-top:16px; margin-bottom:9px;">AGENT</div>
          <div style="display:flex; flex-wrap:wrap; gap:8px;">
            <button data-testid="agent-pill-default" data-agent="Default" class="agent-pill" style="height:38px; padding:0 16px; border-radius:19px; background:#FFFFFF; color:#0A0E17; font-size:14px; font-weight:700; cursor:pointer;">Default</button>
            <button data-testid="agent-pill-go-reviewer" data-agent="go-reviewer" class="agent-pill mono" style="height:38px; padding:0 16px; border-radius:19px; background:#22242C; color:#D5D8E2; font-size:13.5px; cursor:pointer;">go-reviewer</button>
            <button data-testid="agent-pill-release-captain" data-agent="release-captain" class="agent-pill mono" style="height:38px; padding:0 16px; border-radius:19px; background:#22242C; color:#D5D8E2; font-size:13.5px; cursor:pointer;">release-captain</button>
          </div>
        </div>
        """
        js = """
        let activeMode = 'Planning';
        let activeModel = 'Gemini 3.1 Pro';
        let activeAgent = 'Default';
        document.querySelectorAll('.mode-card').forEach(card => {
          card.addEventListener('click', () => {
            activeMode = card.dataset.mode;
            document.querySelectorAll('.mode-card').forEach(c => {
              const on = c === card;
              c.style.borderColor = on ? '#8EB4FF' : 'transparent';
              c.style.background = on ? '#202533' : '#202229';
            });
          });
        });
        document.querySelectorAll('.model-row').forEach(row => {
          row.addEventListener('click', () => {
            activeModel = row.dataset.model;
            document.querySelectorAll('.model-row .model-chk').forEach(chk => chk.style.display = 'none');
            row.querySelector('.model-chk').style.display = 'inline';
          });
        });
        document.querySelectorAll('.agent-pill').forEach(pill => {
          pill.addEventListener('click', () => {
            activeAgent = pill.dataset.agent;
            document.querySelectorAll('.agent-pill').forEach(p => {
              const on = p === pill;
              p.style.background = on ? '#FFFFFF' : '#22242C';
              p.style.color = on ? '#0A0E17' : '#D5D8E2';
              p.style.fontWeight = on ? '700' : '400';
            });
          });
        });
        document.querySelector("[data-testid='btn-model-done']").addEventListener('click', () => {
          document.body.dataset.selectedMode = activeMode;
          document.body.dataset.selectedModel = activeModel;
          document.body.dataset.selectedAgent = activeAgent;
        });
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE10_STRUCTURED_QUESTION":
        body = f"""
        <div style="padding:58px 16px 0 16px; display:flex; flex-direction:column; height:100%;">
          <!-- Top Bar -->
          <div style="display:flex; align-items:center; justify-content:space-between; padding-bottom:12px; border-bottom:1px solid rgba(255,255,255,0.06);">
            <div style="display:flex; align-items:center; gap:9px;">
              <span style="color:#8EB4FF; display:flex;">{ICONS['chev_left']}</span>
              <div>
                <div style="font-size:16px; font-weight:700; color:#F5F7FA;">Audit log for admin actions</div>
                <div style="font-size:12px; color:#7D818D; margin-top:1px;">ledger-svc · Planning · Gemini 3.1 Pro</div>
              </div>
            </div>
            <span style="color:#D5D8E2;">{ICONS['dots']}</span>
          </div>

          <!-- Agent Elicitation Intro -->
          <div style="display:flex; align-items:flex-start; gap:10px; margin-top:16px;">
            <span style="color:#8A8E9B; margin-top:3px;">{ICONS['planet']}</span>
            <p style="font-size:15px; line-height:22px; color:#E8EAF0;">
              Before I draft the plan I need three decisions. Tap to answer — you can also reply in your own words.
            </p>
          </div>

          <!-- Structured Multi-Select Card -->
          <div class="card-group" style="margin-top:16px; padding:16px; border-radius:22px;">
            <div style="display:grid; grid-template-columns:repeat(3, 1fr); gap:8px;">
              <button data-testid="q-step-1-storage" style="height:36px; border-radius:12px; background:#202229; color:#A5AAB8; font-size:12.5px; font-weight:600; display:flex; align-items:center; justify-content:center; gap:5px;">
                <span style="color:#57C88A;">✓</span><span>1 Storage</span>
              </button>
              <button data-testid="q-step-2-actions" style="height:36px; border-radius:12px; background:#FFFFFF; color:#0A0E17; font-size:12.5px; font-weight:700; display:flex; align-items:center; justify-content:center; gap:5px;">
                <span id="step2-label">2 Actions</span>
              </button>
              <button data-testid="q-step-3-retention" style="height:36px; border-radius:12px; background:#202229; color:#A5AAB8; font-size:12.5px; font-weight:600; display:flex; align-items:center; justify-content:center;">
                3 Retention
              </button>
            </div>

            <div id="q-step-caption" style="font-size:12.5px; color:#7D818D; margin-top:14px;">Question 2 of 3 · Select all that apply</div>
            <h2 id="q-title" style="font-size:19px; font-weight:700; line-height:25px; color:#F5F7FA; margin-top:4px;">Which admin actions should be audited?</h2>

            <div style="display:flex; flex-direction:column; gap:10px; margin-top:14px;">
              <div data-testid="q-opt-freeze" data-checked="true" data-label="Account freeze / unfreeze" class="q-opt-row" style="min-height:52px; padding:0 14px; border-radius:14px; background:#1B2230; border:1.5px solid #8EB4FF; display:flex; align-items:center; gap:12px; cursor:pointer;">
                <span class="q-box" style="width:22px; height:22px; border-radius:6px; background:#8EB4FF; color:#0A0E17; display:flex; align-items:center; justify-content:center;">{ICONS['check']}</span>
                <span style="font-size:15px; font-weight:600; color:#F5F7FA;">Account freeze / unfreeze</span>
              </div>

              <div data-testid="q-opt-limit" data-checked="true" data-label="Limit changes" class="q-opt-row" style="min-height:52px; padding:0 14px; border-radius:14px; background:#1B2230; border:1.5px solid #8EB4FF; display:flex; align-items:center; gap:12px; cursor:pointer;">
                <span class="q-box" style="width:22px; height:22px; border-radius:6px; background:#8EB4FF; color:#0A0E17; display:flex; align-items:center; justify-content:center;">{ICONS['check']}</span>
                <span style="font-size:15px; font-weight:600; color:#F5F7FA;">Limit changes</span>
              </div>

              <div data-testid="q-opt-manual" data-checked="true" data-label="Manual ledger adjustments" class="q-opt-row" style="min-height:52px; padding:0 14px; border-radius:14px; background:#1B2230; border:1.5px solid #8EB4FF; display:flex; align-items:center; gap:12px; cursor:pointer;">
                <span class="q-box" style="width:22px; height:22px; border-radius:6px; background:#8EB4FF; color:#0A0E17; display:flex; align-items:center; justify-content:center;">{ICONS['check']}</span>
                <span style="font-size:15px; font-weight:600; color:#F5F7FA;">Manual ledger adjustments</span>
              </div>

              <div data-testid="q-opt-role" data-checked="false" data-label="Role & permission changes" class="q-opt-row" style="min-height:52px; padding:0 14px; border-radius:14px; background:#1B1C22; border:1.5px solid transparent; display:flex; align-items:center; gap:12px; cursor:pointer;">
                <span class="q-box" style="width:22px; height:22px; border-radius:6px; border:1.5px solid #4A4E5B; display:flex; align-items:center; justify-content:center;"></span>
                <span style="font-size:15px; font-weight:500; color:#E5E7EF;">Role &amp; permission changes</span>
              </div>

              <div style="min-height:50px; padding:0 14px; border-radius:14px; border:1.5px dashed rgba(255,255,255,0.14); display:flex; align-items:center; gap:10px;">
                <span style="color:#7D818D; display:flex;">{ICONS['pencil']}</span>
                <input data-testid="q-input-something-else" type="text" placeholder="Something else..." style="flex:1; height:46px; font-size:14.5px; color:#F5F7FA;" />
              </div>
            </div>

            <div style="display:flex; gap:10px; margin-top:16px;">
              <button data-testid="q-btn-back" style="width:84px; height:48px; border-radius:24px; background:#23252E; color:#F5F7FA; font-size:15px; font-weight:600; cursor:pointer;">Back</button>
              <button data-testid="q-btn-next" class="cta-periwinkle" style="flex:1; height:48px; border-radius:24px;">
                <span id="q-next-label">Next</span>
              </button>
            </div>
          </div>

          <!-- Freeform Reply Bar -->
          <div data-testid="composer-freeform-reply" style="margin-top:auto; margin-bottom:24px; height:50px; border-radius:25px; background:#16171D; border:1px solid rgba(255,255,255,0.06); padding:0 8px 0 18px; display:flex; align-items:center; justify-content:space-between;">
            <span style="font-size:15px; color:#7D818D;">Reply in your own words</span>
            <span style="width:36px; height:36px; border-radius:18px; background:#242630; color:#D5D8E2; display:flex; align-items:center; justify-content:center;">{ICONS['mic']}</span>
          </div>
        </div>
        """
        js = f"""
        const checkSvg = `{ICONS['check']}`;
        let currentStep = 2;
        document.querySelectorAll('.q-opt-row').forEach(row => {{
          row.addEventListener('click', () => {{
            const next = row.dataset.checked !== 'true';
            row.dataset.checked = String(next);
            row.style.background = next ? '#1B2230' : '#1B1C22';
            row.style.borderColor = next ? '#8EB4FF' : 'transparent';
            const box = row.querySelector('.q-box');
            if (next) {{
              box.style.background = '#8EB4FF';
              box.style.border = 'none';
              box.style.color = '#0A0E17';
              box.innerHTML = checkSvg;
            }} else {{
              box.style.background = 'transparent';
              box.style.border = '1.5px solid #4A4E5B';
              box.innerHTML = '';
            }}
          }});
        }});
        document.querySelector("[data-testid='q-btn-next']").addEventListener('click', async () => {{
          const selected = Array.from(document.querySelectorAll('.q-opt-row'))
            .filter(r => r.dataset.checked === 'true')
            .map(r => r.dataset.label);
          const custom = document.querySelector("[data-testid='q-input-something-else']").value.trim();
          if (currentStep === 2) {{
            currentStep = 3;
            document.body.dataset.currentStep = '3';
            const s2 = document.querySelector("[data-testid='q-step-2-actions']");
            const s3 = document.querySelector("[data-testid='q-step-3-retention']");
            s2.style.background = '#202229';
            s2.style.color = '#A5AAB8';
            s2.innerHTML = '<span style="color:#57C88A;">✓</span><span>2 Actions</span>';
            s3.style.background = '#FFFFFF';
            s3.style.color = '#0A0E17';
            s3.style.fontWeight = '700';
            document.getElementById('q-step-caption').textContent = 'Question 3 of 3 · Retention policy';
            document.getElementById('q-title').textContent = 'How long should audit entries be retained?';
            document.getElementById('q-next-label').textContent = 'Submit';
          }} else {{
            await window.__AGY_RPC('HandleCascadeUserInteraction', {{
              interaction: {{
                trajectoryId: 'cas-audit-log',
                stepIndex: 3,
                askQuestion: {{
                  selectedOptions: selected,
                  customText: custom
                }}
              }}
            }});
            document.body.dataset.questionSubmitted = 'true';
            document.getElementById('q-next-label').textContent = 'Submitted ✓';
          }}
        }});
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE11_PLAN_REVIEW":
        body = f"""
        <div style="padding:56px 16px 0 16px; display:flex; flex-direction:column; height:100%;">
          <!-- Top Bar -->
          <div style="display:flex; align-items:center; justify-content:space-between;">
            <div style="display:flex; align-items:center; gap:9px;">
              <span style="color:#8EB4FF; display:flex;">{ICONS['chev_left']}</span>
              <div>
                <div style="font-size:16px; font-weight:700; color:#F5F7FA;">Implementation Plan</div>
                <div style="font-size:12px; color:#7D818D;">Fix flaky TestSettlementBatch · v2</div>
              </div>
            </div>
            <div style="display:flex; align-items:center; gap:10px;">
              <span data-testid="plan-comments-badge" style="height:34px; padding:0 12px; border-radius:17px; background:#1C1E26; color:#F5F7FA; font-size:13.5px; font-weight:600; display:inline-flex; align-items:center; gap:6px;">
                {ICONS['comment']} <span id="plan-comment-count">2</span>
              </span>
              <span style="color:#D5D8E2;">{ICONS['dots']}</span>
            </div>
          </div>

          <!-- Paused Amber Banner -->
          <div data-testid="plan-paused-banner" style="margin-top:14px; background:rgba(235,179,101,0.12); border:1px solid rgba(235,179,101,0.18); border-radius:14px; padding:11px 14px; display:flex; align-items:center; gap:10px;">
            <span style="width:8px; height:8px; border-radius:50%; background:#EBB365; flex-shrink:0;"></span>
            <span id="plan-banner-text" style="font-size:13.5px; line-height:18.5px; color:#EBB365; font-weight:500;">
              Agent is paused until you review. Long-press any text to comment.
            </span>
          </div>

          <h1 style="font-size:23px; font-weight:700; line-height:29px; letter-spacing:-0.4px; color:#F5F7FA; margin-top:18px;">
            Isolate the fake clock in settlement tests
          </h1>

          <p style="font-size:14.5px; line-height:21.5px; color:#B5B9C6; margin-top:10px;">
            TestSettlementBatch fails in ~3% of CI runs. Parallel subtests share one fake clock, so <code class="mono" style="background:#1A1C23; padding:2px 6px; border-radius:5px; font-size:13px; color:#E5E7EF;">Advance()</code> in one subtest moves time for the others.
          </p>

          <h2 style="font-size:17px; font-weight:700; color:#F5F7FA; margin-top:18px;">Proposed changes</h2>

          <!-- File 1: MODIFY settlement/batch.go -->
          <div style="margin-top:11px;">
            <div style="display:flex; align-items:center; gap:8px;">
              <span style="font-size:10.5px; font-weight:700; padding:2px 7px; border-radius:5px; background:rgba(235,179,101,0.16); color:#EBB365;">MODIFY</span>
              <span class="mono" style="font-size:13.5px; color:#E5E7EF;">settlement/batch.go</span>
            </div>
            <p style="font-size:14.5px; line-height:21px; color:#C5C9D6; margin-top:6px;">
              Accept a <code class="mono" style="background:#1A1C23; padding:1px 5px; border-radius:4px; font-size:13px;">clock.Clock</code> through BatchOptions<br/><span style="background:rgba(235,179,101,0.18); border-bottom:1.5px solid #EBB365; color:#F5F7FA; padding:1px 2px;">instead of calling time.Now() directly</span>.
            </p>
          </div>

          <!-- Pending Inline Comment Card -->
          <div data-testid="plan-pending-comment-card" style="margin-top:10px; margin-left:10px; background:#16181F; border:1px solid rgba(255,255,255,0.07); border-radius:16px; padding:12px 14px;">
            <div style="display:flex; align-items:center; gap:8px;">
              <span style="width:22px; height:22px; border-radius:11px; background:#2D303B; font-size:10px; font-weight:700; color:#E5E7EF; display:inline-flex; align-items:center; justify-content:center;">WL</span>
              <span style="font-size:13.5px; font-weight:700; color:#F5F7FA;">You</span>
              <span style="font-size:12.5px; color:#7D818D;">Pending</span>
            </div>
            <p style="font-size:13.5px; line-height:19.5px; color:#D5D8E2; margin-top:7px;">
              Default to the real clock when Clock is nil, so existing callers don't break.
            </p>
          </div>

          <!-- File 2 with Floating Text Selection Callout -->
          <div style="margin-top:14px; position:relative;">
            <div style="position:absolute; top:-22px; left:96px; background:#F4F5F8; color:#0A0E17; border-radius:12px; box-shadow:0 10px 26px rgba(0,0,0,0.65); display:inline-flex; align-items:center; overflow:hidden; z-index:20;">
              <button data-testid="selection-callout-comment" style="height:38px; padding:0 13px; display:inline-flex; align-items:center; gap:6px; font-size:13.5px; font-weight:700; color:#0A0E17; cursor:pointer;">
                {ICONS['comment']}<span>Comment</span>
              </button>
              <span style="width:1px; height:20px; background:rgba(0,0,0,0.14);"></span>
              <button style="height:38px; padding:0 13px; font-size:13.5px; font-weight:600; color:#0A0E17;">Copy</button>
            </div>

            <div style="display:flex; align-items:center; gap:8px;">
              <span style="font-size:10.5px; font-weight:700; padding:2px 7px; border-radius:5px; background:rgba(235,179,101,0.16); color:#EBB365;">MODIFY</span>
              <span class="mono" style="font-size:13.5px; color:#E5E7EF;">settlement/batch_test.go</span>
            </div>
            <p style="font-size:14.5px; line-height:21px; color:#C5C9D6; margin-top:6px;">
              Create one clock per subtest; <span style="background:rgba(125,167,255,0.28); color:#F5F7FA; padding:1px 3px; border-radius:3px;">remove the package-level clk variable</span>.
            </p>
          </div>

          <!-- File 3: NEW testutil/clock.go -->
          <div style="margin-top:12px;">
            <div style="display:flex; align-items:center; gap:8px;">
              <span style="font-size:10.5px; font-weight:700; padding:2px 7px; border-radius:5px; background:rgba(87,200,138,0.16); color:#57C88A;">NEW</span>
              <span class="mono" style="font-size:13.5px; color:#E5E7EF;">testutil/clock.go</span>
            </div>
            <p style="font-size:14px; line-height:20px; color:#B5B9C6; margin-top:5px;">
              NewTestClock(t) helper, released with t.Cleanup.
            </p>
          </div>

          <h2 style="font-size:17px; font-weight:700; color:#F5F7FA; margin-top:16px;">Verification</h2>

          <!-- Bottom Bar -->
          <div style="margin-top:auto; margin-bottom:22px; display:flex; gap:12px;">
            <button data-testid="btn-plan-proceed" style="flex:1; height:50px; border-radius:25px; background:#1D1F27; color:#F5F7FA; font-size:15.5px; font-weight:700; cursor:pointer;">Proceed</button>
            <button data-testid="btn-plan-send-comments" class="cta-periwinkle" style="flex:1.28; height:50px; border-radius:25px;">
              <span id="send-plan-comments-label">Send 2 comments</span>
            </button>
          </div>
        </div>
        """
        js = """
        let commentCount = 2;
        document.querySelector("[data-testid='selection-callout-comment']").addEventListener('click', () => {
          commentCount += 1;
          document.getElementById('plan-comment-count').textContent = String(commentCount);
          document.getElementById('send-plan-comments-label').textContent = 'Send ' + commentCount + ' comments';
          document.body.dataset.commentCount = String(commentCount);
        });
        document.querySelector("[data-testid='btn-plan-send-comments']").addEventListener('click', async () => {
          await window.__AGY_RPC('SubmitReviewComments', {
            artifact: 'implementation_plan.md',
            count: commentCount,
            comments: ['Default to real clock when nil', 'Isolate subtest clk variable']
          });
          document.body.dataset.planCommentsSent = 'true';
          document.getElementById('plan-banner-text').textContent = 'Sent ' + commentCount + ' comments to agent ✓';
        });
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE12_TURN_DIFF_REVIEW":
        body = f"""
        <div style="padding:56px 0 0 0; display:flex; flex-direction:column; height:100%;">
          <!-- Top Bar -->
          <div style="padding:0 16px; display:flex; align-items:center; justify-content:space-between;">
            <div style="display:flex; align-items:center; gap:9px;">
              <span style="color:#8EB4FF; display:flex;">{ICONS['chev_left']}</span>
              <div>
                <div style="font-size:16px; font-weight:700; color:#F5F7FA;">Review changes</div>
                <div style="font-size:12px; color:#7D818D;">Add rate limiter to /transfers</div>
              </div>
            </div>
            <div style="display:flex; align-items:center; gap:10px;">
              <button data-testid="btn-accept-all-diffs" style="height:36px; padding:0 14px; border-radius:18px; background:#1D1F27; color:#F5F7FA; font-size:13.5px; font-weight:600; cursor:pointer;">Accept all</button>
              <span style="color:#D5D8E2; display:flex;">{ICONS['sliders']}</span>
            </div>
          </div>

          <!-- Turn Pills -->
          <div style="padding:12px 16px 0 16px; display:flex; align-items:center; gap:8px;">
            <button style="height:34px; padding:0 13px; border-radius:17px; background:#17181E; color:#B5B9C6; font-size:13px; font-weight:500;">Turn 1</button>
            <button style="height:34px; padding:0 13px; border-radius:17px; background:#17181E; color:#B5B9C6; font-size:13px; font-weight:500;">Turn 2</button>
            <button data-testid="turn-pill-3-latest" style="height:34px; padding:0 14px; border-radius:17px; background:#FFFFFF; color:#0A0E17; font-size:13px; font-weight:700;">Turn 3 · latest</button>
            <button style="height:34px; padding:0 13px; border-radius:17px; background:#17181E; color:#B5B9C6; font-size:13px; font-weight:500;">All</button>
          </div>

          <!-- File Pager Card -->
          <div data-testid="file-pager-card" style="margin:12px 16px 0 16px; height:54px; border-radius:16px; background:#141519; border:1px solid rgba(255,255,255,0.06); padding:0 14px; display:flex; align-items:center; justify-content:space-between;">
            <span style="color:#8A8E9B;">{ICONS['chev_right'].replace('M5 3L9 7L5 11', 'M9 3L5 7L9 11')}</span>
            <div style="text-align:center;">
              <div class="mono" style="font-size:13.5px; font-weight:600; color:#F5F7FA;">middleware/ratelimit.go</div>
              <div style="font-size:12px; color:#7D818D; margin-top:1px;">File 1 of 4 · <span style="color:#57C88A; font-weight:600;">+96</span> <span style="color:#F07167; font-weight:600;">-4</span></div>
            </div>
            <span style="color:#8A8E9B;">{ICONS['chev_right']}</span>
          </div>

          <!-- Hunk Header -->
          <div style="margin-top:10px; background:#121318; border-top:1px solid rgba(255,255,255,0.05); border-bottom:1px solid rgba(255,255,255,0.05); padding:7px 16px; display:flex; align-items:center; justify-content:space-between;">
            <span class="mono" style="font-size:12px; color:#8A8E9B;">@@ -18,9 +18,27 @@ Allow</span>
            <button data-testid="btn-revert-hunk" style="font-size:12.5px; font-weight:600; color:#D5D8E2; cursor:pointer;">Revert hunk</button>
          </div>

          <!-- Syntax Diff Surface -->
          <div class="mono" style="font-size:12px; line-height:20.5px; overflow:hidden;">
            <div style="padding:0 14px; color:#C8CCD8;"><span style="color:#656976; margin-right:16px;">18</span><span style="color:#C792EA;">type</span> bucket <span style="color:#C792EA;">struct</span> {{</div>
            <div style="padding:0 14px; color:#C8CCD8;"><span style="color:#656976; margin-right:16px;">19</span>&nbsp;&nbsp;&nbsp;&nbsp;tokens <span style="color:#82AAFF;">float64</span></div>
            <div style="padding:0 14px; color:#C8CCD8;"><span style="color:#656976; margin-right:16px;">20</span>&nbsp;&nbsp;&nbsp;&nbsp;last&nbsp;&nbsp;&nbsp;time.<span style="color:#82AAFF;">Time</span></div>
            <div style="padding:0 14px; background:rgba(87,200,138,0.14); color:#E5E7EF;"><span style="color:#57C88A; margin-right:6px;">21 +</span>&nbsp;&nbsp;&nbsp;&nbsp;mu&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;sync.<span style="color:#82AAFF;">Mutex</span></div>
            <div style="padding:0 14px; color:#C8CCD8;"><span style="color:#656976; margin-right:16px;">22</span>}}</div>
            <div style="padding:0 14px; color:#656976;">23</div>
            <div style="padding:0 14px; background:rgba(240,113,103,0.15); color:#F3C6C3;"><span style="color:#F07167; margin-right:6px;">24 -</span><span style="color:#C792EA;">const</span> ttl = <span style="background:rgba(240,113,103,0.30); padding:1px 3px; border-radius:3px;">5 * time.Minute</span></div>
            <div style="padding:0 14px; background:rgba(87,200,138,0.14); color:#D8F3E3;"><span style="color:#57C88A; margin-right:6px;">24 +</span><span style="color:#C792EA;">const</span> ttl = <span style="background:rgba(87,200,138,0.28); padding:1px 3px; border-radius:3px;">cfg.BucketTTL</span></div>
            <div style="padding:0 14px; color:#656976;">25</div>
            <div style="padding:0 14px; color:#C8CCD8; white-space:nowrap;"><span style="color:#656976; margin-right:16px;">26</span><span style="color:#C792EA;">func</span> (l *Limiter) Allow(tenant <span style="color:#82AAFF;">string</span>) <span style="color:#82AAFF;">bool</span> {{</div>
            <div style="padding:0 14px; background:rgba(87,200,138,0.14); color:#E5E7EF;"><span style="color:#57C88A; margin-right:6px;">27 +</span>&nbsp;&nbsp;&nbsp;&nbsp;b := l.bucketFor(tenant)</div>
            <div style="padding:0 14px; background:rgba(87,200,138,0.14); color:#E5E7EF;"><span style="color:#57C88A; margin-right:6px;">28 +</span>&nbsp;&nbsp;&nbsp;&nbsp;b.mu.Lock(); <span style="color:#C792EA;">defer</span> b.mu.Unlock()</div>
            <div data-testid="diff-line-29" style="padding:1px 14px; background:#1B2846; color:#F5F7FA; cursor:pointer;"><span style="color:#8EB4FF; margin-right:6px;">29 +</span>&nbsp;&nbsp;&nbsp;&nbsp;now := time.Now()</div>
          </div>

          <!-- Inline Comment Composer on Line 29 -->
          <div data-testid="line-comment-composer" style="margin:8px 12px; background:#17181F; border:1px solid rgba(255,255,255,0.09); border-radius:18px; padding:12px 14px;">
            <div style="font-size:12px; color:#8A8E9B;">Comment on line 29</div>
            <textarea id="line29-comment-input" rows="2" style="width:100%; resize:none; margin-top:6px; font-size:14.5px; line-height:20px; color:#F5F7FA;">Use l.clock.Now() — the plan says to inject the clock so tests can control time.</textarea>
            <div style="display:flex; justify-content:flex-end; gap:8px; margin-top:8px;">
              <button data-testid="btn-add-to-review" style="height:36px; padding:0 14px; border-radius:18px; background:#252731; color:#F5F7FA; font-size:13px; font-weight:600; cursor:pointer;">Add to review</button>
              <button data-testid="btn-send-to-agent" style="height:36px; padding:0 15px; border-radius:18px; background:#8EB4FF; color:#0A0E17; font-size:13px; font-weight:700; cursor:pointer;">Send to agent</button>
            </div>
          </div>

          <div class="mono" style="font-size:12px; line-height:20.5px; overflow:hidden;">
            <div style="padding:0 14px; background:rgba(87,200,138,0.14); color:#E5E7EF; white-space:nowrap;"><span style="color:#57C88A; margin-right:6px;">30 +</span>&nbsp;&nbsp;&nbsp;&nbsp;elapsed := now.Sub(b.last).Seconds()</div>
            <div style="padding:0 14px; background:rgba(87,200,138,0.14); color:#E5E7EF; white-space:nowrap;"><span style="color:#57C88A; margin-right:6px;">31 +</span>&nbsp;&nbsp;&nbsp;&nbsp;b.tokens = min(l.burst, b.tokens+elapsed*l</div>
          </div>

          <!-- Bottom Review Bar -->
          <div style="margin-top:auto; padding:10px 16px 22px 16px; display:flex; align-items:center; justify-content:space-between; gap:10px;">
            <button data-testid="checkbox-viewed" data-viewed="false" style="min-height:44px; display:inline-flex; align-items:center; gap:9px; cursor:pointer;">
              <span id="viewed-box" style="width:20px; height:20px; border-radius:5px; background:#FFFFFF; display:inline-flex; align-items:center; justify-content:center; color:#0A0E17;"></span>
              <span style="font-size:14.5px; color:#C5C9D6;">Viewed</span>
            </button>
            <div style="display:flex; gap:10px;">
              <button data-testid="btn-revert-file" style="height:46px; padding:0 20px; border-radius:23px; background:#1D1F27; color:#F5F7FA; font-size:14.5px; font-weight:700; cursor:pointer;">Revert file</button>
              <button data-testid="btn-accept-file" class="cta-periwinkle" style="min-height:46px; padding:0 22px; border-radius:23px;">
                <span id="accept-file-label">Accept file</span>
              </button>
            </div>
          </div>
        </div>
        """
        js = f"""
        const checkSvg = `{ICONS['check']}`;
        document.querySelector("[data-testid='diff-line-29']").addEventListener('click', () => {{
          document.getElementById('line29-comment-input').focus();
          document.body.dataset.line29Selected = 'true';
        }});
        document.querySelector("[data-testid='btn-send-to-agent']").addEventListener('click', async () => {{
          const txt = document.getElementById('line29-comment-input').value.trim();
          await window.__AGY_RPC('SubmitReviewComments', {{
            file: 'middleware/ratelimit.go',
            line: 29,
            comments: [txt]
          }});
          document.body.dataset.lineCommentSent = 'true';
          document.querySelector("[data-testid='btn-send-to-agent']").textContent = 'Sent ✓';
        }});
        const viewedBtn = document.querySelector("[data-testid='checkbox-viewed']");
        viewedBtn.addEventListener('click', () => {{
          const next = viewedBtn.dataset.viewed !== 'true';
          viewedBtn.dataset.viewed = String(next);
          const box = document.getElementById('viewed-box');
          box.style.background = next ? '#8EB4FF' : '#FFFFFF';
          box.innerHTML = next ? checkSvg : '';
        }});
        document.querySelector("[data-testid='btn-accept-file']").addEventListener('click', () => {{
          document.body.dataset.fileAccepted = 'true';
          document.getElementById('accept-file-label').textContent = 'Accepted ✓';
        }});
        """
        return _wrap_mobile_page(state_id, body, js, selectors, rpc_port)

    if state_id == "UE13_LIVE_ACTIVITY_SPEC":
        body = f"""
        <div style="width:800px; height:500px; padding:24px 26px; display:flex; flex-direction:column; justify-content:space-between;">
          <!-- Header -->
          <div>
            <h1 style="font-size:21px; font-weight:800; letter-spacing:-0.4px; color:#14161B;">Live Activity · 灵动岛</h1>
            <div style="display:flex; justify-content:space-between; align-items:flex-end; margin-top:5px;">
              <p style="font-size:10.5px; line-height:16px; color:#5A5E6B; max-width:460px;">
                一个 Live Activity 对应一个正在运行的会话。锁屏卡片聚合多个 Agent；需要批准时，灵动岛从“进度”切换为“琥珀色待办”，并可在展开态直接批准（必须 Face ID）。
              </p>
              <div style="display:flex; align-items:center; gap:12px; font-size:10.5px; color:#4A4E5A;">
                <span style="display:inline-flex; align-items:center; gap:5px;"><span style="width:7.5px; height:7.5px; border-radius:50%; background:#7DA7FF;"></span>运行中</span>
                <span style="display:inline-flex; align-items:center; gap:5px;"><span style="width:7.5px; height:7.5px; border-radius:50%; background:#EBB365;"></span>等你处理</span>
                <span style="display:inline-flex; align-items:center; gap:5px;"><span style="width:7.5px; height:7.5px; border-radius:50%; background:#57C88A;"></span>完成</span>
              </div>
            </div>
          </div>

          <!-- Row 1: 4 Compact & Minimal Dynamic Island Variants -->
          <div style="display:grid; grid-template-columns:repeat(4, 1fr); gap:14px;">
            <!-- 1. Compact Running -->
            <div>
              <div style="height:68px; border-radius:14px; background:#D4D8DF; display:flex; align-items:center; justify-content:center;">
                <div data-testid="di-compact-running" style="width:146px; height:26px; border-radius:13px; background:#000000; padding:0 8px; display:flex; align-items:center; justify-content:space-between;">
                  <span style="width:16px; height:16px; border-radius:8px; border:1.5px solid #4F75C8; color:#7DA7FF; display:inline-flex; align-items:center; justify-content:center;">
                    <span style="display:flex; transform:scale(0.68);">{ICONS['planet']}</span>
                  </span>
                  <span class="mono" style="font-size:10px; font-weight:700; color:#7DA7FF;">4/7</span>
                </div>
              </div>
              <div style="font-size:10.5px; font-weight:700; color:#1E2028; margin-top:7px;">Compact · 运行中</div>
              <div style="font-size:9.5px; line-height:14px; color:#636875; margin-top:2px;">左：进度环；右：步骤计数。轻点进入会话。</div>
            </div>

            <!-- 2. Compact Waiting -->
            <div>
              <div style="height:68px; border-radius:14px; background:#D4D8DF; display:flex; align-items:center; justify-content:center;">
                <div data-testid="di-compact-waiting" style="width:148px; height:26px; border-radius:13px; background:#000000; padding:0 9px; display:flex; align-items:center; justify-content:space-between;">
                  <span style="width:13px; height:13px; border-radius:7px; background:rgba(235,179,101,0.25); display:inline-flex; align-items:center; justify-content:center;">
                    <span style="width:6.5px; height:6.5px; border-radius:4px; background:#EBB365;"></span>
                  </span>
                  <span style="font-size:10px; font-weight:700; color:#EBB365;">Approve</span>
                </div>
              </div>
              <div style="font-size:10.5px; font-weight:700; color:#1E2028; margin-top:7px;">Compact · 待批准</div>
              <div style="font-size:9.5px; line-height:14px; color:#636875; margin-top:2px;">命令执行 / 计划审阅 / 问答时切换，伴随一次轻触感反馈。</div>
            </div>

            <!-- 3. Minimal Ring -->
            <div>
              <div style="height:68px; border-radius:14px; background:#D4D8DF; display:flex; align-items:center; justify-content:center; gap:5px;">
                <div style="width:74px; height:26px; border-radius:13px; background:#000000;"></div>
                <div data-testid="di-minimal-ring" style="width:26px; height:26px; border-radius:13px; background:#000000; display:flex; align-items:center; justify-content:center;">
                  {ICONS['spinner_blue']}
                </div>
              </div>
              <div style="font-size:10.5px; font-weight:700; color:#1E2028; margin-top:7px;">Minimal · 与其他活动并存</div>
              <div style="font-size:9.5px; line-height:14px; color:#636875; margin-top:2px;">只保留进度环；有待批准时环变琥珀色。</div>
            </div>

            <!-- 4. Compact Done -->
            <div>
              <div style="height:68px; border-radius:14px; background:#D4D8DF; display:flex; align-items:center; justify-content:center;">
                <div data-testid="di-compact-done" style="width:148px; height:26px; border-radius:13px; background:#000000; padding:0 9px; display:flex; align-items:center; justify-content:space-between;">
                  <span style="width:14px; height:14px; border-radius:7px; background:rgba(87,200,138,0.2); color:#57C88A; font-size:9px; display:inline-flex; align-items:center; justify-content:center;">✓</span>
                  <span class="mono" style="font-size:9.5px; font-weight:700; color:#57C88A;">+128 -14</span>
                </div>
              </div>
              <div style="font-size:10.5px; font-weight:700; color:#1E2028; margin-top:7px;">Compact · 完成</div>
              <div style="font-size:9.5px; line-height:14px; color:#636875; margin-top:2px;">显示本轮改动行数，停留 8 秒后收起，进入通知。</div>
            </div>
          </div>

          <!-- Row 2: 2 Expanded Dynamic Islands + 1 Lock Screen Multi-Agent Card -->
          <div style="display:grid; grid-template-columns:repeat(3, 1fr); gap:14px;">
            <!-- 5. Expanded Running -->
            <div>
              <div style="height:172px; border-radius:16px; background:#D4D8DF; padding:11px; display:flex; align-items:center; justify-content:center;">
                <div data-testid="di-expanded-running" style="width:100%; background:#000000; border-radius:24px; padding:12px 13px; color:#F5F7FA;">
                  <div style="display:flex; align-items:center; justify-content:space-between; gap:6px;">
                    <div style="display:flex; align-items:center; gap:7px; min-width:0;">
                      <span style="width:22px; height:22px; border-radius:11px; background:#172238; color:#7DA7FF; display:inline-flex; align-items:center; justify-content:center; flex-shrink:0;">{ICONS['planet']}</span>
                      <div style="min-width:0;">
                        <div style="font-size:9.5px; font-weight:700; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">Add rate limiter to /transfers</div>
                        <div style="font-size:8.5px; color:#8A8E9B;">ledger-svc · MacBook Pro</div>
                      </div>
                    </div>
                    <span class="mono" style="font-size:9.5px; color:#8A8E9B; flex-shrink:0;">2:41</span>
                  </div>
                  <div class="mono" style="font-size:9.5px; color:#7DA7FF; margin-top:8px;">go test ./internal/...</div>
                  <div style="display:grid; grid-template-columns:repeat(7, 1fr); gap:3px; margin-top:6px;">
                    <span style="height:3px; border-radius:2px; background:#7DA7FF;"></span>
                    <span style="height:3px; border-radius:2px; background:#7DA7FF;"></span>
                    <span style="height:3px; border-radius:2px; background:#7DA7FF;"></span>
                    <span style="height:3px; border-radius:2px; background:#7DA7FF;"></span>
                    <span style="height:3px; border-radius:2px; background:#2B2E38;"></span>
                    <span style="height:3px; border-radius:2px; background:#2B2E38;"></span>
                    <span style="height:3px; border-radius:2px; background:#2B2E38;"></span>
                  </div>
                  <div style="display:grid; grid-template-columns:1fr 1fr; gap:8px; margin-top:10px;">
                    <span style="height:26px; border-radius:13px; background:#22242C; color:#F5F7FA; font-size:9.5px; font-weight:600; display:flex; align-items:center; justify-content:center;">Stop</span>
                    <span style="height:26px; border-radius:13px; background:#8EB4FF; color:#0A0E17; font-size:9.5px; font-weight:700; display:flex; align-items:center; justify-content:center;">Open</span>
                  </div>
                </div>
              </div>
              <div style="font-size:10.5px; font-weight:700; color:#1E2028; margin-top:7px;">Expanded · 运行中（长按）</div>
              <div style="font-size:9.5px; line-height:14px; color:#636875; margin-top:2px;">当前命令 + 7 段进度条 + 用时。Stop 不需要验证，Open 深链到会话。</div>
            </div>

            <!-- 6. Expanded Waiting (Face ID) -->
            <div>
              <div style="height:172px; border-radius:16px; background:#D4D8DF; padding:11px; display:flex; align-items:center; justify-content:center;">
                <div data-testid="di-expanded-waiting" style="width:100%; background:#000000; border-radius:24px; padding:12px 13px; color:#F5F7FA;">
                  <div style="display:flex; align-items:center; gap:8px;">
                    <span style="width:22px; height:22px; border-radius:7px; background:#261E13; color:#EBB365; display:inline-flex; align-items:center; justify-content:center;">{ICONS['terminal']}</span>
                    <div>
                      <div style="font-size:10px; font-weight:700; color:#EBB365;">Run this command?</div>
                      <div style="font-size:8.5px; color:#8A8E9B;">Add rate limiter · step 5 of 7</div>
                    </div>
                  </div>
                  <div class="mono" style="margin-top:8px; background:#16171C; border-radius:8px; padding:6px 8px; font-size:8.8px; color:#E5E7EF; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
                    vegeta attack -rate=2000/s -duration=30s
                  </div>
                  <div style="display:grid; grid-template-columns:1fr 1.1fr; gap:8px; margin-top:10px;">
                    <span style="height:26px; border-radius:13px; background:#22242C; color:#F5F7FA; font-size:9.5px; font-weight:600; display:flex; align-items:center; justify-content:center;">Deny</span>
                    <span style="height:26px; border-radius:13px; background:#EBB365; color:#0A0E17; font-size:9.5px; font-weight:700; display:flex; align-items:center; justify-content:center; gap:4px;">
                      <span style="display:flex; transform:scale(0.75);">{ICONS['faceid']}</span>Allow
                    </span>
                  </div>
                </div>
              </div>
              <div style="font-size:10.5px; font-weight:700; color:#1E2028; margin-top:7px;">Expanded · 待批准</div>
              <div style="font-size:9.5px; line-height:14px; color:#636875; margin-top:2px;">Allow 走 App Intent + Face ID，签名后经配对通道回传桌面；Deny 可直接点。</div>
            </div>

            <!-- 7. Lock Screen Multi-Agent Aggregation -->
            <div>
              <div style="height:172px; border-radius:16px; background:#252834; padding:11px; display:flex; flex-direction:column; justify-content:flex-end;">
                <div data-testid="lockscreen-multi-agent-card" style="background:rgba(19,20,25,0.92); border:1px solid rgba(255,255,255,0.08); border-radius:16px; padding:10px 11px; color:#F5F7FA;">
                  <div style="display:flex; align-items:center; gap:5px; font-size:8.8px; color:#9EA2B0;">
                    <span style="display:flex; transform:scale(0.78);">{ICONS['planet']}</span>
                    <span>Agents · 2 running · 1 needs you</span>
                  </div>
                  <div style="display:flex; align-items:center; justify-content:space-between; gap:8px; margin-top:7px;">
                    <div style="display:flex; align-items:center; gap:7px; min-width:0;">
                      <span style="width:6.5px; height:6.5px; border-radius:50%; background:#EBB365; flex-shrink:0;"></span>
                      <div style="min-width:0;">
                        <div style="font-size:9.4px; font-weight:700; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">Add rate limiter to /transfers</div>
                        <div style="font-size:8.5px; color:#EBB365;">Approve: vegeta attack...</div>
                      </div>
                    </div>
                    <span style="height:22px; padding:0 9px; border-radius:11px; background:#EBB365; color:#0A0E17; font-size:8.8px; font-weight:700; display:inline-flex; align-items:center; flex-shrink:0;">Review</span>
                  </div>
                  <div style="display:flex; align-items:center; justify-content:space-between; margin-top:7px;">
                    <div style="display:flex; align-items:center; gap:7px;">
                      <span style="width:6.5px; height:6.5px; border-radius:50%; background:#7DA7FF;"></span>
                      <div>
                        <div style="font-size:9.8px; font-weight:600;">Dark mode for settings page</div>
                        <div style="font-size:8.5px; color:#8A8E9B;">Cloud · step 2 of 5</div>
                      </div>
                    </div>
                    <span class="mono" style="font-size:8.5px; color:#8A8E9B;">12:04</span>
                  </div>
                </div>
              </div>
              <div style="font-size:10.5px; font-weight:700; color:#1E2028; margin-top:7px;">Lock Screen · 多 Agent 聚合</div>
              <div style="font-size:9.5px; line-height:14px; color:#636875; margin-top:2px;">待处理排最前；本地会话随电脑在线，云端会话合盖后继续推送。</div>
            </div>
          </div>
        </div>
        """
        return _wrap_spec_board_page(state_id, body, selectors, rpc_port)

    raise ValueError(f"Unknown state_id: {state_id}")
