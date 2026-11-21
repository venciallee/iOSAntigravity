# Auto-Generated Technical Design — Antigravity v2.34.0

## Module Mapping
- `Packages/AntigravityData/`: Pure Swift 6 domain models (`ResilientStringEnum`), RPC payloads (`HostCapabilityRegistry`), Protobuf decoding (zero UIKit/WebKit/AVFoundation).
- `iOS/`: SwiftUI views & sheets bound to `AntigravitySessionStore` (dual-track live vs `--ui-verify`, using `performLiveCapabilityWrite`).
- `verification/`: `mock_language_server.py`, `verify-v233-capabilities.py`, `verify-compat-matrix.py`, and `esdd-verify.py`.

## Bidirectional Compatibility Checklist
- [ ] Register any newly added Connect-RPC methods in `HostCapabilityRegistry.swift`.
- [ ] Conform all newly added `String, Codable` model enums to `ResilientStringEnum`.
- [ ] Mirror any new enum downgrade mappings between `HostCapabilityRegistry.swift` and `scripts/mac-companion-bridge.py`.
- [ ] Use `performLiveCapabilityWrite(...)` for mutating Store RPCs (zero silent `try?`).

## Tier 2 Protocol Probe Checklist
- [ ] Capture live `LanguageServerService` schema for: This release brings MCP App support and Gemini 4 Neon to eligible paid consumer plans. It includes 15 improvements and 24 fixes.
- [ ] Capture live `LanguageServerService` schema for: Added Clerk, Docusign, and TestMu AI partner plugins to the Marketplace.
- [ ] Capture live `LanguageServerService` schema for: The Installed tab in Customizations now shows the first two bundles above a See more toggle so your plugins stay near the top.
- [ ] Capture live `LanguageServerService` schema for: Sign out buttons for plugin accounts and plugin MCP servers now show a loading indicator while sign-out finishes.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where a failed step update or subagent wakeup could cause the turn step checklist to flash or disappear.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where plugins whose manifest file started with a UTF-8 byte order mark installed without error but failed to load.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where Trello and Zoho Books plugin icons appeared tiny or low-contrast in dark themes.
- [ ] Capture live `LanguageServerService` schema for: This release adds SSH host connections for running projects and agents on remote Linux machines, along with live GitHub pull request status pills, hover cards, and an Overview Pull Requests section. It also brings in-page Cmd/Ctrl+F search to the built-in brow
- [ ] Capture live `LanguageServerService` schema for: GitHub pull request links in chat and URL artifact cards now render as live status pills with hover cards, alongside a new Pull Requests section in the Overview panel and an optional conversation sidebar indicator.
- [ ] Capture live `LanguageServerService` schema for: Finished /btw side-question answers now include an Insert into main conversation action, and you can start a side question from selected subagent text or promote a subagent tab to Full View when running /btw.
- [ ] Capture live `LanguageServerService` schema for: Business and enterprise accounts can now use /swarm and open UI plugin panels from the side panel, Overview, New Tab, and title bar when allowed by organization admin settings.
- [ ] Capture live `LanguageServerService` schema for: Added Cloudflare, Grafana Cloud, SonarQube, incident.io, Better Stack, Tavily, and Levels.fyi to the partner plugin marketplace, and updated the Gemini API plugin and 15 partner plugins.
- [ ] Capture live `LanguageServerService` schema for: Messages sent immediately while the agent is working now appear as sent without pulsing and keep the turn above them steady on delivery. Agent response actions are now left-aligned below the status line, and a single running subagent opens from the status line
- [ ] Capture live `LanguageServerService` schema for: Device management policies in admin_settings.json can now lock sign-in and project settings, enforce permission ceilings, disable remote control, and restrict plugins or marketplace access.
- [ ] Capture live `LanguageServerService` schema for: If you use remote agents, editing env-setup.sh now shows Saved setup routine with an Open in settings link, project setup scripts are labeled Environment, and multiple open windows share a single cloud polling loop.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where custom file viewers from plugins and MCP apps still showed non-working Preview, Raw, Word Wrap, and Export as PDF controls in the side panel.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where remote MCP servers using OAuth signed you out after an hour when tokens refreshed, where configured MCP headers were sent across cross-origin redirects, and where OAuth sign-in callbacks failed on IPv6-only machines.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where empty internal plugin projects appeared in project pickers, where Create with Prompt on the Automations page could target a remote project instead of This Computer, and where /learn appended past rule file size limits.
- [ ] Capture live `LanguageServerService` schema for: This release brings multi-turn /btw side-question tabs with read-only tool access to the Antigravity App and fixes an issue that could truncate diagnostic logs. It includes 1 improvement and 1 fix.
- [ ] Capture live `LanguageServerService` schema for: Side questions (/btw) now open in a dedicated Side Question tab in the side panel where you can ask multi-turn follow-up questions and let the agent read files, search your workspace, and run read-only commands without interrupting the main conversation.
- [ ] Capture live `LanguageServerService` schema for: This release adds Dynamic Workflows, letting agents orchestrate parallel subagents and multi-step tasks in Python using the runtime bundled with the app. It also introduces Everforest Light and Dark themes, prompt navigation shortcuts, and stronger protections
- [ ] Capture live `LanguageServerService` schema for: You can now use Dynamic Workflows to orchestrate parallel subagents and multi-step tasks in Python using the Python runtime bundled with the app.
- [ ] Capture live `LanguageServerService` schema for: Installed plugin cards and detail headers now display MCP server startup errors when a connection fails to start.
- [ ] Capture live `LanguageServerService` schema for: If you use remote agents, you can now clone Cloud GitHub repositories locally from the workspace picker and sign in to pull request links directly from the app.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where full-page plugin views turned blank or broke open tabs after restarting or updating a plugin.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where filtering by Automations in the sidebar could hide plugin conversations.
- [ ] Capture live `LanguageServerService` schema for: You can now use /swarm to coordinate multiple subagents over a message board to complete long-horizon tasks.
- [ ] Capture live `LanguageServerService` schema for: Installing a plugin or skill from a plugin card in the agent's latest reply now resumes the conversation automatically.
- [ ] Capture live `LanguageServerService` schema for: If you use remote agents, creating a project now offers a This Computer or Remote choice in one wizard instead of a separate New Remote Project item.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where plugin panels showed blank in pinned side panel tabs, covered the edges of the side panel, or stayed on screen over a maximized side panel.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where a plugin's context providers were missing after you added it from its full-page details screen.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where a plugin that declared extra fields in its manifest lost all of its context providers.
- [ ] Capture live `LanguageServerService` schema for: Fixed an issue where plugin panels could not play sound until you interacted with them.
- [ ] Capture live `LanguageServerService` schema for: When you first sign in, Antigravity now asks what best describes your work, such as Software Engineering, Knowledge Work, Data & Analytics, Science, or Design, and sets up a matching layout. Home then suggests ways to start, and selecting one adds any plugin i
- [ ] Capture live `LanguageServerService` schema for: Remote agents have finished rolling out to Google AI Ultra subscribers and to Google AI Pro subscribers on a paid plan. The GitHub repository picker for cloud projects also has a new Configure on GitHub link for giving Antigravity access to more of your reposi
- [ ] Capture live `LanguageServerService` schema for: Antigravity can now bring over your MCP servers, skills, custom commands, subagents, and instruction files from coding agents such as Claude Code, Codex, and Cursor into a plugin you own. Ask the agent to import your setup to get started.
- [ ] Capture live `LanguageServerService` schema for: The permission preset you pick in the message box now applies only to that conversation, so changing it no longer affects your other conversations. This doesn't apply to business and enterprise accounts.
- [ ] Capture live `LanguageServerService` schema for: The Auto permission preset is no longer marked Preview, and business accounts without admin controls now get it too, along with the updated permissions system that other accounts already use and a notice that explains the change. Accounts with admin controls k
- [ ] Capture live `LanguageServerService` schema for: Notices that a background task finished or that a subagent sent a message now appear inside the turn's Worked for section, so conversations stay compact.
- [ ] Capture live `LanguageServerService` schema for: Plugins you mention with @ in a message now show their logo, and you can hover over one to see its description.
- _...and 1303 additional Tier 2 item(s) recorded in `delta-report.json`._
