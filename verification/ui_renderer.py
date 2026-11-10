#!/usr/bin/env python3
"""iOS 18 / iPhone 16 Pro (393x852pt @3x) Native Design System Renderer & AX Geometry Probe.

Renders the 8 normative ESDD states defined in `specs/esdd-ir.json` using the exact
Antigravity Obsidian & Liquid Glass tokens (`#090B10` canvas, `#111520` elevated surface,
`#161B29` card, `#6366F1`->`#8B5CF6` cosmic indigo-violet accent, 5-tier typography,
iOS 18 Status Bar + Dynamic Island + Home Indicator), captures @3x (1179x2556) PNG
screenshots via Headless Chromium, and reports exact computed bounding boxes (`ax_tree`)
back to the ESDD verifier.
"""

COMMON_CSS = """
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
  -webkit-font-smoothing: antialiased;
}
html, body {
  width: 393px;
  max-width: 393px;
  height: 852px;
  max-height: 852px;
  overflow: hidden;
  background: #090B10;
  color: #F8FAFC;
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Inter', system-ui, sans-serif;
  position: relative;
}
.mono {
  font-family: 'SF Mono', 'JetBrains Mono', ui-monospace, Menlo, monospace;
}
.ambient-glow {
  position: absolute;
  top: -70px;
  left: 36px;
  width: 321px;
  height: 210px;
  background: radial-gradient(circle, rgba(99, 102, 241, 0.24) 0%, rgba(139, 92, 246, 0.09) 48%, rgba(9, 11, 16, 0) 75%);
  pointer-events: none;
  z-index: 0;
}
.ios-status-bar {
  position: relative;
  z-index: 20;
  height: 59px;
  padding: 15px 22px 0 26px;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  font-size: 15px;
  font-weight: 600;
  letter-spacing: -0.2px;
  color: #F8FAFC;
}
.dynamic-island {
  position: absolute;
  top: 11px;
  left: 50%;
  transform: translateX(-50%);
  width: 126px;
  height: 36px;
  background: #000000;
  border-radius: 20px;
  border: 1px solid rgba(255, 255, 255, 0.09);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 12px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.75);
}
.di-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #38BDF8;
  box-shadow: 0 0 8px #38BDF8;
}
.di-cam {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #111622;
  border: 1.5px solid #1E293B;
}
.status-icons {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
}
.screen-body {
  position: relative;
  z-index: 10;
  width: 393px;
  max-width: 393px;
  height: 759px;
  padding: 8px 16px 12px 16px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  overflow: hidden;
}
.screen-body > * {
  min-width: 0;
  max-width: 100%;
}
.card-surface, .elevated-surface, .glass-bar {
  min-width: 0;
  max-width: 100%;
}
.home-indicator-area {
  position: relative;
  z-index: 20;
  width: 393px;
  height: 34px;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  padding-bottom: 8px;
}
.home-indicator-pill {
  width: 138px;
  height: 5px;
  border-radius: 3px;
  background: rgba(248, 250, 252, 0.36);
}
/* 5-Tier Typography */
.tier-reading { font-size: 15px; line-height: 21px; font-weight: 400; color: #F8FAFC; }
.tier-evidence { font-size: 13.5px; line-height: 18px; font-weight: 600; color: #E2E8F0; }
.tier-process { font-size: 12.5px; line-height: 17px; font-weight: 400; color: #94A3B8; }
.tier-metadata { font-size: 11px; line-height: 14px; font-weight: 400; color: #64748B; }
.tier-chrome { font-size: 12.5px; line-height: 17px; font-weight: 500; color: #94A3B8; }

.glass-bar {
  background: rgba(22, 27, 41, 0.84);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.10);
  border-radius: 20px;
}
.card-surface {
  background: #161B29;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 16px;
}
.elevated-surface {
  background: #111520;
  border: 1px solid rgba(255, 255, 255, 0.06);
  border-radius: 14px;
}
.btn-primary {
  min-height: 48px;
  min-width: 48px;
  padding: 0 16px;
  border-radius: 14px;
  background: linear-gradient(135deg, #6366F1 0%, #8B5CF6 100%);
  border: 1px solid rgba(255, 255, 255, 0.18);
  color: #F8FAFC;
  font-size: 13.5px;
  font-weight: 600;
  white-space: nowrap;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  box-shadow: 0 6px 20px rgba(99, 102, 241, 0.28);
}
.btn-secondary {
  min-height: 48px;
  min-width: 48px;
  padding: 0 14px;
  border-radius: 14px;
  background: #161B29;
  border: 1px solid rgba(255, 255, 255, 0.10);
  color: #E2E8F0;
  font-size: 13px;
  font-weight: 500;
  white-space: nowrap;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}
.badge {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 3px 8px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 600;
  white-space: nowrap;
}
.badge-waiting { background: rgba(245, 158, 11, 0.16); color: #F59E0B; border: 1px solid rgba(245, 158, 11, 0.35); }
.badge-running { background: rgba(56, 189, 248, 0.16); color: #38BDF8; border: 1px solid rgba(56, 189, 248, 0.35); }
.badge-done { background: rgba(16, 185, 129, 0.16); color: #10B981; border: 1px solid rgba(16, 185, 129, 0.35); }
.badge-indigo { background: rgba(99, 102, 241, 0.18); color: #A5B4FC; border: 1px solid rgba(99, 102, 241, 0.35); }
"""

QR_SVG = """
<svg width="112" height="112" viewBox="0 0 112 112" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="4" y="4" width="104" height="104" rx="14" fill="#0B0E17" stroke="#6366F1" stroke-width="1.5" stroke-dasharray="6 4"/>
  <!-- Top-left finder -->
  <rect x="16" y="16" width="24" height="24" rx="4" stroke="#E2E8F0" stroke-width="3"/>
  <rect x="22" y="22" width="12" height="12" rx="2" fill="#8B5CF6"/>
  <!-- Top-right finder -->
  <rect x="72" y="16" width="24" height="24" rx="4" stroke="#E2E8F0" stroke-width="3"/>
  <rect x="78" y="22" width="12" height="12" rx="2" fill="#8B5CF6"/>
  <!-- Bottom-left finder -->
  <rect x="16" y="72" width="24" height="24" rx="4" stroke="#E2E8F0" stroke-width="3"/>
  <rect x="22" y="78" width="12" height="12" rx="2" fill="#8B5CF6"/>
  <!-- Data modules -->
  <rect x="48" y="18" width="6" height="6" rx="1.5" fill="#E2E8F0"/>
  <rect x="58" y="24" width="6" height="14" rx="1.5" fill="#A5B4FC"/>
  <rect x="46" y="46" width="20" height="20" rx="5" fill="#6366F1"/>
  <circle cx="56" cy="56" r="4" fill="#F8FAFC"/>
  <rect x="18" y="48" width="18" height="6" rx="1.5" fill="#94A3B8"/>
  <rect x="74" y="50" width="20" height="6" rx="1.5" fill="#E2E8F0"/>
  <rect x="48" y="74" width="6" height="20" rx="1.5" fill="#A5B4FC"/>
  <rect x="62" y="72" width="14" height="6" rx="1.5" fill="#E2E8F0"/>
  <rect x="74" y="84" width="20" height="10" rx="2" fill="#38BDF8"/>
  <!-- Laser scan line -->
  <line x1="10" y1="56" x2="102" y2="56" stroke="#38BDF8" stroke-width="2" stroke-opacity="0.85"/>
</svg>
"""


def wrap_ios_frame(state_id: str, body_html: str, selectors: list) -> str:
    selectors_json = str(selectors).replace("'", '"')
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=393, initial-scale=1, maximum-scale=1, user-scalable=no" />
<title>{state_id}</title>
<style>{COMMON_CSS}</style>
</head>
<body>
  <div class="ambient-glow"></div>
  <div class="ios-status-bar">
    <span>9:41</span>
    <div class="dynamic-island">
      <div class="di-dot"></div>
      <span class="mono" style="font-size:10px;color:#94A3B8;">AGY · 18ms</span>
      <div class="di-cam"></div>
    </div>
    <div class="status-icons">
      <span>5G</span>
      <span>100%</span>
    </div>
  </div>
  <div class="screen-body">
    {body_html}
  </div>
  <div class="home-indicator-area">
    <div class="home-indicator-pill"></div>
  </div>
  <script>
    window.addEventListener('load', () => {{
      const selectors = {selectors_json};
      const elements = {{}};
      for (const sel of selectors) {{
        const el = document.querySelector(sel);
        if (el) {{
          const r = el.getBoundingClientRect();
          elements[sel] = {{
            exists: true,
            x: Math.round(r.x * 10) / 10,
            y: Math.round(r.y * 10) / 10,
            width: Math.round(r.width * 10) / 10,
            height: Math.round(r.height * 10) / 10,
            text: (el.innerText || '').trim().slice(0, 120)
          }};
        }} else {{
          elements[sel] = {{ exists: false }};
        }}
      }}
      const bodyRect = document.body.getBoundingClientRect();
      const report = {{
        stateId: "{state_id}",
        viewportWidth: Math.round(bodyRect.width),
        viewportHeight: Math.round(bodyRect.height),
        scrollWidth: document.body.scrollWidth,
        scrollHeight: document.body.scrollHeight,
        elements
      }};
      fetch('/__esdd_ax_report', {{
        method: 'POST',
        headers: {{ 'Content-Type': 'application/json' }},
        body: JSON.stringify(report)
      }}).catch(() => {{}});
    }});
  </script>
</body>
</html>"""


def render_scene_html(state_id: str, selectors: list) -> str:
    if state_id == "S01_PAIRING_QR":
        body = f"""
        <div style="display:flex;flex-direction:column;gap:14px;">
          <div style="display:flex;align-items:center;justify-content:space-between;">
            <div>
              <div class="badge badge-indigo" style="margin-bottom:6px;">ANTIGRAVITY REMOTE v2.30.0</div>
              <h1 style="font-size:21px;font-weight:700;letter-spacing:-0.4px;">Pair Host Device</h1>
            </div>
            <div class="glass-bar" style="width:44px;height:44px;display:flex;align-items:center;justify-content:center;font-size:17px;">⌘</div>
          </div>
          <p class="tier-process">Open <b>Settings → Application → Remote Control</b> in Antigravity Desktop or run <span class="mono" style="color:#E2E8F0;">agy remote-control start</span>.</p>

          <!-- Camera QR Viewfinder -->
          <div id="qr-viewfinder" class="elevated-surface" style="height:236px;padding:14px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;border:1px solid rgba(99,102,241,0.38);background:radial-gradient(circle at center, #161D31 0%, #0C0F18 100%);">
            {QR_SVG}
            <span class="badge badge-done">QR LOCKED · TLS 1.3 VERIFIED</span>
            <div class="mono" style="font-size:10.5px;color:#94A3B8;white-space:nowrap;">antigravity.google.com/r/lt74xt6l0m-golden-star</div>
          </div>

          <!-- Detected Host Card -->
          <div id="detected-host-card" class="card-surface" style="padding:14px;display:flex;flex-direction:column;gap:10px;">
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <div style="display:flex;align-items:center;gap:8px;">
                <span style="width:9px;height:9px;border-radius:50%;background:#10B981;display:inline-block;"></span>
                <span class="tier-evidence mono">lt74xt6l0m-golden-star</span>
              </div>
              <span class="badge badge-indigo">Hub LS · v2.30.0</span>
            </div>
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <span class="tier-process">Transport: Connect-RPC + WebSocket</span>
              <span class="mono" style="font-size:11.5px;color:#10B981;font-weight:600;">18ms RTT</span>
            </div>
          </div>
        </div>

        <div style="display:flex;flex-direction:column;gap:10px;">
          <div id="btn-connect-relay" class="btn-primary">
            <span>Connect via Google Cloud Relay</span>
          </div>
          <div id="btn-connect-direct" class="btn-secondary">
            <span>Connect via Direct LAN / Tailscale</span>
          </div>
        </div>
        """
        return wrap_ios_frame(state_id, body, selectors)

    if state_id == "S02_WORKSPACE_HOME":
        body = """
        <div style="display:flex;flex-direction:column;gap:12px;">
          <!-- Top Glass Header -->
          <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">
            <div id="host-status-pill" class="glass-bar" style="min-height:46px;padding:0 12px;display:flex;align-items:center;gap:8px;flex:1;">
              <span style="width:8px;height:8px;border-radius:50%;background:#10B981;flex-shrink:0;"></span>
              <div style="overflow:hidden;">
                <div class="tier-chrome" style="color:#F8FAFC;white-space:nowrap;">lt74xt6l0m-golden-star</div>
                <div class="tier-metadata mono" style="white-space:nowrap;">Hub v2.30.0 · 18ms RTT</div>
              </div>
            </div>
            <div id="btn-new-cascade" class="btn-primary" style="min-height:46px;padding:0 14px;border-radius:23px;flex-shrink:0;">
              <span>＋ New</span>
            </div>
          </div>

          <!-- Worktree Filter Bar -->
          <div id="worktree-filter-bar" class="elevated-surface" style="min-height:44px;padding:4px;display:flex;align-items:center;justify-content:space-between;gap:4px;overflow:hidden;">
            <div style="flex:1;text-align:center;padding:6px 8px;border-radius:9px;background:#1E2638;color:#F8FAFC;font-size:11.5px;font-weight:600;white-space:nowrap;">⎇ main (3)</div>
            <div style="flex:1;text-align:center;padding:6px 8px;border-radius:9px;color:#94A3B8;font-size:11.5px;white-space:nowrap;">⎇ connect-rpc</div>
            <div style="flex:1;text-align:center;padding:6px 8px;border-radius:9px;color:#94A3B8;font-size:11.5px;white-space:nowrap;">⎇ live-activity</div>
          </div>

          <!-- Section Header: Pinned & Active -->
          <div style="display:flex;align-items:center;justify-content:space-between;padding:2px 4px;">
            <span class="tier-metadata mono" style="letter-spacing:0.6px;color:#94A3B8;">PINNED CASCADES · JETBOX STREAM</span>
            <span class="tier-metadata mono" style="color:#10B981;">SQLITE &lt;10MS</span>
          </div>

          <!-- Row 1: WAITING -->
          <div id="session-row-waiting" class="card-surface" style="min-height:92px;padding:13px 14px;display:flex;flex-direction:column;gap:7px;border-left:3px solid #F59E0B;">
            <div style="display:flex;align-items:center;justify-content:space-between;gap:6px;">
              <span class="tier-evidence" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Native Connect-RPC &amp; Live Activity</span>
              <span class="badge badge-waiting">WAITING · #24</span>
            </div>
            <div class="tier-process" style="color:#FBBF24;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">⚠️ RequestedInteraction: Approve esdd-verify.py</div>
            <div class="tier-metadata mono" style="display:flex;justify-content:space-between;">
              <span>⎇ feat/connect-rpc-client</span>
              <span>Just now · +184 -22</span>
            </div>
          </div>

          <!-- Row 2: RUNNING -->
          <div id="session-row-running" class="card-surface" style="min-height:86px;padding:13px 14px;display:flex;flex-direction:column;gap:7px;border-left:3px solid #38BDF8;">
            <div style="display:flex;align-items:center;justify-content:space-between;gap:6px;">
              <span class="tier-evidence" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">CoreText 120fps Streaming Layout</span>
              <span class="badge badge-running">RUNNING · #14</span>
            </div>
            <div class="tier-process" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">✦ Thinking (3.4s) · Inspecting CTFrame line origins</div>
            <div class="tier-metadata mono" style="display:flex;justify-content:space-between;">
              <span>⎇ feat/live-activity</span>
              <span>12s ago · 2 Artifacts</span>
            </div>
          </div>

          <!-- Row 3: DONE (>600 binary protobuf steps) -->
          <div class="card-surface" style="min-height:80px;padding:13px 14px;display:flex;flex-direction:column;gap:6px;">
            <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">
              <span class="tier-evidence" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Binary Protobuf Trajectory (&gt;600 Steps)</span>
              <span class="badge badge-done" style="flex-shrink:0;">DONE · 642</span>
            </div>
            <div class="tier-metadata mono" style="display:flex;justify-content:space-between;">
              <span>⎇ main · application/proto</span>
              <span>4m ago · Verified</span>
            </div>
          </div>
        </div>

        <!-- Bottom Workspace Summary Footer -->
        <div class="glass-bar" style="min-height:48px;padding:0 14px;display:flex;align-items:center;justify-content:space-between;">
          <span class="tier-chrome" style="color:#E2E8F0;white-space:nowrap;">Safe Auto-Accept: Read-Only</span>
          <span class="tier-metadata mono" style="color:#A5B4FC;white-space:nowrap;">Jetbox Synced ✓</span>
        </div>
        """
        return wrap_ios_frame(state_id, body, selectors)

    if state_id == "S03_CASCADE_STREAMING":
        body = """
        <div style="display:flex;flex-direction:column;gap:10px;">
          <!-- TaskBoundary Header Banner -->
          <div id="task-boundary-banner" class="elevated-surface" style="padding:11px 14px;border-left:3px solid #6366F1;display:flex;flex-direction:column;gap:4px;">
            <div style="display:flex;align-items:center;justify-content:space-between;">
              <span class="tier-metadata mono" style="color:#A5B4FC;font-weight:600;">TASK BOUNDARY · PHASE 2 OF 4</span>
              <span class="badge badge-running">STREAMING 120FPS</span>
            </div>
            <div class="tier-evidence">Connect-RPC Streaming &amp; ESDD Verification</div>
            <div class="tier-process">Executing 5-byte Connect framing &amp; binary Protobuf checks</div>
          </div>

          <!-- User Prompt Bubble -->
          <div class="card-surface" style="align-self:flex-end;max-width:92%;padding:10px 14px;background:#1E2438;">
            <div class="tier-reading">Implement ConnectEnvelope.swift and run the ESDD verification suite with screenshot assertions.</div>
          </div>

          <!-- Step 22: Collapsible Thinking Capsule -->
          <div id="step-thinking-capsule" class="elevated-surface" style="min-height:44px;padding:0 12px;display:flex;align-items:center;justify-content:space-between;gap:8px;">
            <div style="display:flex;align-items:center;gap:8px;overflow:hidden;">
              <span style="color:#8B5CF6;font-size:14px;flex-shrink:0;">✦</span>
              <span class="tier-process" style="color:#E2E8F0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Thought for 3.4s · Verified field 56 RequestedInteraction</span>
            </div>
            <span class="tier-metadata mono" style="flex-shrink:0;">▾</span>
          </div>

          <!-- Agent Prose Response (Reading Tier) -->
          <div class="tier-reading" style="padding:2px 4px;">
            I have wired <span class="mono" style="color:#A5B4FC;font-size:13.5px;">ConnectEnvelope.swift</span> and <span class="mono" style="color:#A5B4FC;font-size:13.5px;">ProtobufStepDecoder.swift</span> to decode all 21 step types and &gt;600 step trajectories.
          </div>

          <!-- Step 23: Grouped File Evidence Block -->
          <div id="step-file-evidence-group" class="card-surface" style="min-height:52px;padding:10px 14px;display:flex;align-items:center;justify-content:space-between;">
            <div>
              <div class="tier-evidence mono">ConnectEnvelope.swift + 3 files</div>
              <div class="tier-process">5-byte Connect streaming parser &amp; binary Protobuf</div>
            </div>
            <div style="display:flex;align-items:center;gap:6px;">
              <span class="mono" style="font-size:12px;color:#10B981;font-weight:600;">+184</span>
              <span class="mono" style="font-size:12px;color:#F43F5E;font-weight:600;">-22</span>
              <span class="tier-metadata">›</span>
            </div>
          </div>

          <!-- Step 24: Native Terminal Card -->
          <div id="step-terminal-card" class="elevated-surface" style="padding:10px 14px;display:flex;flex-direction:column;gap:5px;background:#0C0F17;">
            <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">
              <span class="mono tier-metadata" style="color:#E2E8F0;white-space:nowrap;">$ python3 verification/esdd-verify.py</span>
              <span class="badge badge-done" style="flex-shrink:0;">EXIT 0 · 1.4s</span>
            </div>
            <div class="mono tier-process" style="font-size:11px;color:#94A3B8;white-space:nowrap;">
              PASS [Spec-DAG] 8/8 states, 9/9 events verified<br/>
              PASS [Connect-RPC] 5B framing &amp; 605 binary steps OK
            </div>
          </div>
        </div>

        <!-- Bottom Liquid Glass Composer -->
        <div id="liquid-glass-composer" class="glass-bar" style="padding:10px 12px;display:flex;flex-direction:column;gap:8px;border:1px solid rgba(99,102,241,0.4);">
          <div style="display:flex;align-items:center;justify-content:space-between;">
            <span class="tier-process" style="color:#94A3B8;padding-left:4px;">Message Antigravity or type /plan, @file...</span>
          </div>
          <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">
            <div id="composer-model-pill" class="elevated-surface" style="min-height:44px;padding:0 12px;border-radius:22px;display:flex;align-items:center;gap:6px;">
              <span style="width:7px;height:7px;border-radius:50%;background:#8B5CF6;"></span>
              <span class="tier-chrome" style="color:#E2E8F0;">Claude Sonnet 4.5 · High · Planning</span>
            </div>
            <div id="composer-send-btn" class="btn-primary" style="width:46px;height:46px;padding:0;border-radius:23px;font-size:18px;">↑</div>
          </div>
        </div>
        """
        return wrap_ios_frame(state_id, body, selectors)

    if state_id == "S04_PERMISSION_GATE":
        body = """
        <div style="display:flex;flex-direction:column;gap:10px;opacity:0.45;">
          <div class="elevated-surface" style="padding:12px;">
            <div class="tier-evidence">Cascade · Implement Native Connect-RPC</div>
            <div class="tier-process">Step 24 paused on CORTEX_STEP_STATUS_WAITING (9)</div>
          </div>
        </div>

        <!-- Native Liquid Glass Permission Gate Sheet -->
        <div id="permission-gate-sheet" class="card-surface" style="padding:18px;border-radius:24px;border:1px solid rgba(245,158,11,0.45);box-shadow:0 -12px 40px rgba(0,0,0,0.75);display:flex;flex-direction:column;gap:13px;">
          <div style="display:flex;align-items:center;justify-content:space-between;">
            <span class="badge badge-waiting">PERMISSION GATE · FIELD 56 ONEOF</span>
            <span class="tier-metadata mono">Step #24</span>
          </div>

          <div>
            <h2 style="font-size:17.5px;font-weight:700;color:#F8FAFC;margin-bottom:4px;">Approve Command Execution</h2>
            <p class="tier-process">Antigravity requests permission to execute a verification command in your workspace:</p>
          </div>

          <div id="permission-resource-box" class="elevated-surface" style="padding:12px;background:#0B0E16;display:flex;flex-direction:column;gap:5px;overflow:hidden;">
            <div class="mono" style="font-size:10.5px;color:#FBBF24;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">$ python3 verification/esdd-verify.py --suite all</div>
            <div class="tier-metadata mono" style="white-space:nowrap;">cwd: ~/venciallee/iOSAntigravity</div>
            <div class="tier-metadata mono" style="color:#A5B4FC;white-space:nowrap;">turnGrants: execute(verification/*)</div>
          </div>

          <!-- Safe Auto-Accept Toggle Row (>=44pt) -->
          <div id="toggle-safe-auto-accept" class="elevated-surface" style="min-height:48px;padding:0 14px;display:flex;align-items:center;justify-content:space-between;gap:8px;">
            <div>
              <div class="tier-chrome" style="color:#E2E8F0;">Safe Auto-Accept Read-Only Steps</div>
              <div class="tier-metadata">Auto-approves workspace file reads &amp; searches</div>
            </div>
            <div style="width:44px;height:26px;border-radius:13px;background:#10B981;padding:2px;display:flex;justify-content:flex-end;flex-shrink:0;">
              <div style="width:22px;height:22px;border-radius:50%;background:#FFFFFF;"></div>
            </div>
          </div>

          <div id="btn-allow-turn-grant" class="btn-primary">
            <span>Always Allow in Turn (turnGrants)</span>
          </div>

          <div style="display:flex;gap:10px;">
            <div id="btn-allow-once" class="btn-secondary" style="flex:1;">
              <span>Allow Once</span>
            </div>
            <div id="btn-reject-permission" class="btn-secondary" style="flex:1;color:#F43F5E;border-color:rgba(244,63,94,0.3);">
              <span>Reject</span>
            </div>
          </div>
        </div>
        """
        return wrap_ios_frame(state_id, body, selectors)

    if state_id == "S05_ASK_QUESTION_MODAL":
        body = """
        <div style="display:flex;flex-direction:column;gap:10px;opacity:0.45;">
          <div class="elevated-surface" style="padding:12px;">
            <div class="tier-evidence">Agent Elicitation · ask_question</div>
            <div class="tier-process">Waiting for user design decision before scaffolding</div>
          </div>
        </div>

        <div id="ask-question-sheet" class="card-surface" style="padding:18px;border-radius:24px;border:1px solid rgba(139,92,246,0.45);display:flex;flex-direction:column;gap:12px;">
          <div style="display:flex;align-items:center;justify-content:space-between;">
            <span class="badge badge-indigo">CLARIFICATION NEEDED · 1 OF 1</span>
            <span class="tier-metadata mono">Single-Select</span>
          </div>

          <div class="tier-reading" style="font-weight:600;">
            Which transport channel should be prioritized when pairing a new iOS device with Antigravity Desktop?
          </div>

          <div id="option-card-0" class="elevated-surface" style="min-height:56px;padding:11px 14px;border:1.5px solid #6366F1;background:rgba(99,102,241,0.12);display:flex;align-items:center;justify-content:space-between;">
            <div>
              <div class="tier-evidence" style="color:#F8FAFC;">(Recommended) Dual-Channel Hybrid</div>
              <div class="tier-process">Zero-config Google Cloud Relay + Direct LAN upgrade</div>
            </div>
            <span style="color:#6366F1;font-size:18px;font-weight:700;">●</span>
          </div>

          <div id="option-card-1" class="elevated-surface" style="min-height:52px;padding:10px 14px;display:flex;align-items:center;justify-content:space-between;">
            <div>
              <div class="tier-evidence">Google Cloud Relay Only</div>
              <div class="tier-process">Connect exclusively via antigravity.google.com/r/&lt;id&gt;</div>
            </div>
            <span style="color:#64748B;font-size:18px;">○</span>
          </div>

          <div id="option-card-2" class="elevated-surface" style="min-height:52px;padding:10px 14px;display:flex;align-items:center;justify-content:space-between;">
            <div>
              <div class="tier-evidence">Direct LAN / Tailscale Sidecar Only</div>
              <div class="tier-process">Connect directly to local language_server HTTPS port</div>
            </div>
            <span style="color:#64748B;font-size:18px;">○</span>
          </div>

          <div id="btn-submit-answer" class="btn-primary">
            <span>Submit Answer to Cascade</span>
          </div>
        </div>
        """
        return wrap_ios_frame(state_id, body, selectors)

    if state_id == "S06_ARTIFACT_PLAN_REVIEW":
        body = """
        <div style="display:flex;flex-direction:column;gap:12px;">
          <!-- Artifact Header -->
          <div id="artifact-header" class="glass-bar" style="min-height:48px;padding:10px 14px;display:flex;align-items:center;justify-content:space-between;">
            <div>
              <div class="tier-evidence mono">implementation_plan.md</div>
              <div class="tier-metadata">Artifact Snapshot v3 · RequestFeedback=true</div>
            </div>
            <span class="badge badge-waiting">REVIEW REQUIRED</span>
          </div>

          <!-- GitHub Alert Callout -->
          <div id="artifact-alert-important" class="elevated-surface" style="padding:12px 14px;border-left:3px solid #8B5CF6;display:flex;flex-direction:column;gap:4px;">
            <div class="mono" style="font-size:11px;font-weight:700;color:#A5B4FC;">[!IMPORTANT] DIRECT CONNECT-RPC ARCHITECTURE</div>
            <div class="tier-process" style="color:#E2E8F0;">Bypasses the 9MB desktop React web bundle and connects Swift 6 directly to <span class="mono">LanguageServerService</span>.</div>
          </div>

          <!-- Mermaid Architecture Diagram Card -->
          <div id="artifact-mermaid-diagram" class="card-surface" style="padding:14px;display:flex;flex-direction:column;gap:10px;">
            <div class="tier-metadata mono" style="color:#94A3B8;">MERMAID ARCHITECTURE DIAGRAM · RENDERED NATIVELY</div>
            <div style="display:flex;align-items:center;justify-content:space-between;gap:6px;text-align:center;">
              <div class="elevated-surface" style="flex:1;padding:10px 6px;">
                <div class="tier-chrome" style="color:#F8FAFC;">iOS Swift 6</div>
                <div class="tier-metadata">CoreText 120fps</div>
              </div>
              <span class="mono" style="color:#6366F1;">⇄</span>
              <div class="elevated-surface" style="flex:1;padding:10px 6px;border-color:rgba(99,102,241,0.4);">
                <div class="tier-chrome" style="color:#A5B4FC;">Connect-RPC</div>
                <div class="tier-metadata">5B Frame + Proto</div>
              </div>
              <span class="mono" style="color:#6366F1;">⇄</span>
              <div class="elevated-surface" style="flex:1;padding:10px 6px;">
                <div class="tier-chrome" style="color:#10B981;">Hub LS v2.30</div>
                <div class="tier-metadata">Jetbox SQLite</div>
              </div>
            </div>
          </div>

          <!-- Plan Checklist -->
          <div class="card-surface" style="padding:12px 14px;display:flex;flex-direction:column;gap:8px;">
            <div class="tier-evidence">Verification Deliverables</div>
            <div class="tier-process">☑ <span class="mono" style="color:#E2E8F0;">ConnectEnvelope.swift</span> 5-byte framing</div>
            <div class="tier-process">☑ <span class="mono" style="color:#E2E8F0;">ProtobufStepDecoder.swift</span> &gt;600 step support</div>
            <div class="tier-process">☑ <span class="mono" style="color:#E2E8F0;">specs/esdd-ir.json</span> 8-state visual verification</div>
          </div>
        </div>

        <div style="display:flex;gap:10px;">
          <div id="btn-proceed-plan" class="btn-primary" style="flex:1.35;">
            <span>Proceed with Plan</span>
          </div>
          <div id="btn-edit-plan" class="btn-secondary" style="flex:1;">
            <span>Request Changes</span>
          </div>
        </div>
        """
        return wrap_ios_frame(state_id, body, selectors)

    if state_id == "S07_TURN_DIFF_INSPECTOR":
        body = """
        <div style="display:flex;flex-direction:column;gap:12px;">
          <!-- File Tabs Header (>=44pt) -->
          <div id="diff-file-tabs" class="glass-bar" style="min-height:48px;padding:6px 12px;display:flex;align-items:center;justify-content:space-between;">
            <div style="display:flex;align-items:center;gap:8px;">
              <span class="tier-evidence mono">ConnectEnvelope.swift</span>
              <span class="badge badge-indigo">1 of 4 files</span>
            </div>
            <div class="mono" style="font-size:12px;">
              <span style="color:#10B981;font-weight:600;">+184</span>
              <span style="color:#F43F5E;font-weight:600;margin-left:4px;">-22</span>
            </div>
          </div>

          <!-- Unified Word-Level Diff Surface -->
          <div id="diff-code-surface" class="elevated-surface mono" style="padding:12px;background:#0B0E17;display:flex;flex-direction:column;gap:4px;font-size:11px;line-height:16px;">
            <div style="color:#8B5CF6;padding:2px 4px;">@@ -12,6 +12,21 @@ public struct ConnectEnvelopeFrame</div>
            <div style="color:#94A3B8;padding:2px 4px;"> 12  12   public let flags: Flags</div>
            <div style="background:rgba(244,63,94,0.16);color:#FDA4AF;padding:3px 6px;border-radius:6px;"> 13   · - public let rawJSON: <span style="background:rgba(244,63,94,0.35);padding:0 3px;border-radius:3px;">String</span></div>
            <div style="background:rgba(16,185,129,0.16);color:#6EE7B7;padding:3px 6px;border-radius:6px;">  ·  13 + public let payload: <span style="background:rgba(16,185,129,0.35);padding:0 3px;border-radius:3px;">Data</span></div>
            <div style="background:rgba(16,185,129,0.16);color:#6EE7B7;padding:3px 6px;border-radius:6px;">  ·  14 + public static let endStream = Flags(rawValue: 0x02)</div>
            <div style="background:rgba(16,185,129,0.16);color:#6EE7B7;padding:3px 6px;border-radius:6px;">  ·  15 + public func encode() -&gt; Data {</div>
            <div style="background:rgba(16,185,129,0.16);color:#6EE7B7;padding:3px 6px;border-radius:6px;">  ·  16 +   var lengthBE = UInt32(payload.count).bigEndian</div>
            <div style="background:rgba(16,185,129,0.16);color:#6EE7B7;padding:3px 6px;border-radius:6px;">  ·  17 +   return header + payload</div>
            <div style="background:rgba(16,185,129,0.16);color:#6EE7B7;padding:3px 6px;border-radius:6px;">  ·  18 + }</div>
            <div style="color:#94A3B8;padding:2px 4px;"> 14  19 }</div>
          </div>

          <div class="card-surface" style="padding:12px 14px;display:flex;align-items:center;justify-content:space-between;">
            <span class="tier-process">Word-level diff via <span class="mono" style="color:#E2E8F0;">GetTurnDiff</span></span>
            <span class="badge badge-done">CLEAN TREE</span>
          </div>
        </div>

        <div style="display:flex;gap:10px;">
          <div id="btn-accept-patch" class="btn-primary" style="flex:1.3;">
            <span>Accept Turn Patch</span>
          </div>
          <div id="btn-revert-patch" class="btn-secondary" style="flex:1;color:#F43F5E;">
            <span>Revert Hunk</span>
          </div>
        </div>
        """
        return wrap_ios_frame(state_id, body, selectors)

    if state_id == "S08_LIVE_ACTIVITY_LOCKSCREEN":
        body = """
        <div style="display:flex;flex-direction:column;gap:16px;">
          <!-- iOS 18 Lock Screen Clock Header -->
          <div style="text-align:center;padding:8px 0 4px 0;">
            <div style="font-size:13px;font-weight:500;color:#94A3B8;">Tuesday, November 10</div>
            <div style="font-size:64px;font-weight:700;letter-spacing:-2px;line-height:68px;color:#F8FAFC;">09:41</div>
          </div>

          <!-- Expanded Dynamic Island Showcase -->
          <div id="dynamic-island-expanded" style="background:#000000;border-radius:32px;padding:15px 16px;border:1px solid rgba(255,255,255,0.14);box-shadow:0 12px 32px rgba(0,0,0,0.8);display:flex;flex-direction:column;gap:10px;overflow:hidden;">
            <div style="display:flex;align-items:center;justify-content:space-between;gap:6px;">
              <div style="display:flex;align-items:center;gap:7px;">
                <span style="width:9px;height:9px;border-radius:50%;background:#F59E0B;box-shadow:0 0 8px #F59E0B;flex-shrink:0;"></span>
                <span class="tier-evidence" style="white-space:nowrap;">Antigravity · Island</span>
              </div>
              <span class="mono tier-metadata" style="color:#FBBF24;white-space:nowrap;flex-shrink:0;">#24/28 · 01:24</span>
            </div>
            <div class="tier-process" style="color:#E2E8F0;white-space:nowrap;">Waiting on <span class="mono">lt74xt6l0m-golden-star</span></div>
            <div style="height:6px;background:#1E293B;border-radius:3px;overflow:hidden;">
              <div style="width:85%;height:100%;background:linear-gradient(90deg,#6366F1,#F59E0B);"></div>
            </div>
          </div>

          <!-- Lock Screen Live Activity Notification Card -->
          <div id="lockscreen-live-activity-card" class="glass-bar" style="padding:16px;border-radius:24px;border:1px solid rgba(245,158,11,0.4);display:flex;flex-direction:column;gap:12px;overflow:hidden;">
            <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">
              <span class="badge badge-waiting">LIVE ACTIVITY · WAITING</span>
              <span class="tier-metadata mono" style="white-space:nowrap;">⎇ feat/connect-rpc</span>
            </div>
            <div>
              <div class="tier-evidence" style="font-size:14.5px;color:#F8FAFC;white-space:nowrap;">Native Connect-RPC &amp; Live Activity</div>
              <div class="mono tier-process" style="font-size:10.5px;color:#FBBF24;margin-top:4px;white-space:nowrap;">$ python3 verification/esdd-verify.py --suite all</div>
            </div>
            <div style="display:flex;gap:10px;">
              <div id="btn-live-activity-approve" class="btn-primary" style="flex:1.3;">
                <span>Approve via AppIntent</span>
              </div>
              <div id="btn-live-activity-open" class="btn-secondary" style="flex:1;">
                <span>Open Cascade</span>
              </div>
            </div>
          </div>
        </div>

        <div class="tier-metadata" style="text-align:center;color:#94A3B8;">
          Synced with Apple Watch Smart Stack (supplementalActivityFamilies: .small)
        </div>
        """
        return wrap_ios_frame(state_id, body, selectors)

    raise ValueError(f"Unknown state_id: {state_id}")
