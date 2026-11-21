# Auto-Generated PRD & Gap Analysis — Antigravity v2.34.0

# Antigravity Upstream Documentation Delta (v2.33.0 → v2.34.0)

- **Checked (UTC)**: `2026-11-21T15:49:11.283405+00:00`
- **App Version**: `v2.33.0` → `v2.34.0`
- **CLI Version**: `v1.5.11` → `v1.5.14`
- **Stale CDN Guard Triggered**: `False`
- **Meaningful Delta**: `True` (max tier: `tier3`)
- **Changed Sources**: `changelog`, `cli_changelog`, `cli_releases_atom`, `sdk_releases_atom`, `docs/features`, `docs/models`, `docs/permissions`, `docs/remote-control`, `docs/remote-agents`, `docs/review-changes`, `docs/side-panel`, `docs/voice-mode`, `docs/browser`, `docs/ssh`, `docs/dynamic-workflows`, `docs/swarm`, `docs/teamwork`, `docs/plugins`, `docs/mcp`, `docs/sidecars`

## Classified Requirements Delta

| Tier | Source | Summary | Rationale |
| :--- | :--- | :--- | :--- |
| `TIER1` | `changelog` | Changelog2-0Antigravity AppDocumentationChangelog Antigravity App DocumentationAntigravity App | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Track new features, improvements, and bug fixes across Google Antigravity surfaces, including the Antigravity App, Antigravity CLI, the Antigravity SDK, and Antigravity IDE. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | New versions roll out gradually and may take a few days to reach all users. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | November 20, 2026 | General Antigravity 2.0 capability or UX update |
| `TIER2` | `changelog` | This release brings MCP App support and Gemini 4 Neon to eligible paid consumer plans. It includes 15 improvements and 24 fixes. | Matched protocol/RPC/orchestration keyword `mcp` (Draft PR + Protocol Probe) |
| `TIER1` | `changelog` | Improvements(15) | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Gemini 4 Neon and Orchestrator (Neon) are now available for eligible paid consumer plans, and Gemini 4 Neon is available with Gemini API keys and Application Default Credentials. Enterprise and Application Default Credentials accounts also now support the Orch | Matched client/catalog/UI keyword `gemini 4` (Auto-implementable Ready PR) |
| `TIER1` | `changelog` | You can now choose whether Enter or Ctrl+Enter (Cmd+Enter on macOS) sends messages under Settings > General > Input Box. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Diff views now use a single-column line-number gutter with color-coded change strips, giving code more horizontal room before wrapping. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | You can now drag conversation tabs from the side panel directly into the message box to reference them in a prompt. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | URLs typed or pasted into the message box are now automatically formatted as interactive links. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Selecting a skill pill in a conversation now opens its skill definition file in the side panel. | General Antigravity 2.0 capability or UX update |
| `TIER2` | `changelog` | Added Clerk, Docusign, and TestMu AI partner plugins to the Marketplace. | Matched protocol/RPC/orchestration keyword `plugin` (Draft PR + Protocol Probe) |
| `TIER2` | `changelog` | The Installed tab in Customizations now shows the first two bundles above a See more toggle so your plugins stay near the top. | Matched protocol/RPC/orchestration keyword `plugin` (Draft PR + Protocol Probe) |
| `TIER2` | `changelog` | Sign out buttons for plugin accounts and plugin MCP servers now show a loading indicator while sign-out finishes. | Matched protocol/RPC/orchestration keyword `mcp` (Draft PR + Protocol Probe) |
| `TIER1` | `changelog` | The model selector effort submenu now includes a Thinking effort header with a tooltip explaining latency and quota tradeoffs. | Matched client/catalog/UI keyword `model` (Auto-implementable Ready PR) |
| `TIER1` | `changelog` | Improved Git status refresh speed in large repositories by reusing recent status checks and limiting diffs to changed files. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Notifications now skip the banner and sound when you are already viewing the conversation that finished or asked for input. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Your reading position now stays anchored after approving a command prompt instead of jumping when the approval card collapses. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where desktop Antigravity sessions missing a required authentication scope were not signed out when idle so you could sign back in with the required permissions. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where a transient background status poll error could clear your loaded account state and display No Model Selected. | Matched client/catalog/UI keyword `model` (Auto-implementable Ready PR) |
| `TIER1` | `changelog` | Fixed an issue where scrolling up past the top of a long agent response could bounce the view back down. | General Antigravity 2.0 capability or UX update |
| `TIER2` | `changelog` | Fixed an issue where a failed step update or subagent wakeup could cause the turn step checklist to flash or disappear. | Matched protocol/RPC/orchestration keyword `subagent` (Draft PR + Protocol Probe) |
| `TIER1` | `changelog` | Fixed an issue where canceled agent responses kept animating indefinitely and retried stream errors could show discarded partial text. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where streamed Chinese, Japanese, and other spaceless-script text appeared in abrupt chunks instead of fading in word by word. | General Antigravity 2.0 capability or UX update |
| `TIER2` | `changelog` | Fixed an issue where plugins whose manifest file started with a UTF-8 byte order mark installed without error but failed to load. | Matched protocol/RPC/orchestration keyword `plugin` (Draft PR + Protocol Probe) |
| `TIER1` | `changelog` | Fixed an issue where skills without a name field in their frontmatter could collide with each other instead of taking their folder name. | Matched client/catalog/UI keyword `frontmatter` (Auto-implementable Ready PR) |
| `TIER1` | `changelog` | Fixed an issue where number or arrow keys could select disabled options in permission and question prompts. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where exiting an IME composition without a standard end event could cause follow-up keystrokes in the message box to be ignored. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where selecting a quote chip did not scroll to the quoted message in longer paginated conversations. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where a fade gradient in the title bar painted over the overview button even when the side panel was closed. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where the focus outline around the search bar in Settings > Shortcuts was cut off on the sides. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where the Learn more link in the Google Cloud project picker pointed to a broken page. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where newly opened file and artifact tabs showed their inner sidebar expanded by default. | Matched client/catalog/UI keyword `sidebar` (Auto-implementable Ready PR) |
| `TIER1` | `changelog` | Fixed an issue where Settings > General could show an empty Advanced Settings toggle when no nested options were visible. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where stopping voice dictation immediately after starting it could leave the microphone active. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Fixed an issue where loading older messages in long conversations showed no loading indicator or error feedback. | General Antigravity 2.0 capability or UX update |
| `TIER2` | `changelog` | Fixed an issue where Trello and Zoho Books plugin icons appeared tiny or low-contrast in dark themes. | Matched protocol/RPC/orchestration keyword `plugin` (Draft PR + Protocol Probe) |
| `TIER1` | `changelog` | Model launch·November 18, 2026 | Matched client/catalog/UI keyword `model` (Auto-implementable Ready PR) |
| `TIER1` | `changelog` | Gemini 4 Neon is now available on Google AI Ultra, Google AI Pro, and Gemini Enterprise, and it's the default model if you haven't chosen one, with four thinking levels and Orchestrator (Neon) for planning with Gemini 4 Neon and implementing with Gemini 4 Hydr | Matched client/catalog/UI keyword `model` (Auto-implementable Ready PR) |
| `TIER1` | `changelog` | Gemini 4 Neon: Read on the Antigravity blog | Matched client/catalog/UI keyword `gemini 4` (Auto-implementable Ready PR) |
| `TIER1` | `changelog` | November 17, 2026 | General Antigravity 2.0 capability or UX update |
| `TIER2` | `changelog` | This release adds SSH host connections for running projects and agents on remote Linux machines, along with live GitHub pull request status pills, hover cards, and an Overview Pull Requests section. It also brings in-page Cmd/Ctrl+F search to the built-in brow | Matched protocol/RPC/orchestration keyword `plugin` (Draft PR + Protocol Probe) |
| `TIER1` | `changelog` | Improvements(16) | General Antigravity 2.0 capability or UX update |
| `TIER3` | `changelog` | You can now connect the Antigravity App to a remote 64-bit Linux machine over SSH from the sidebar, the project menu (SSH Host...), or the command palette (Connect to SSH Host...). Antigravity installs its remote server automatically over OpenSSH using your ~/ | Matched heavy native/infra keyword `openssh` (RFC + Design + Test Plan only) |
| `TIER2` | `changelog` | GitHub pull request links in chat and URL artifact cards now render as live status pills with hover cards, alongside a new Pull Requests section in the Overview panel and an optional conversation sidebar indicator. | Matched protocol/RPC/orchestration keyword `pull request` (Draft PR + Protocol Probe) |
| `TIER2` | `changelog` | Finished /btw side-question answers now include an Insert into main conversation action, and you can start a side question from selected subagent text or promote a subagent tab to Full View when running /btw. | Matched protocol/RPC/orchestration keyword `/btw` (Draft PR + Protocol Probe) |
| `TIER1` | `changelog` | You can now search within pages in the built-in browser with Cmd/Ctrl+F from either the browser toolbar or the page itself, while web apps with their own search keep handling the shortcut. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | You can now choose the Nord dark theme and matching syntax palette in Settings > Appearance. | Matched client/catalog/UI keyword `theme` (Auto-implementable Ready PR) |
| `TIER1` | `changelog` | Added syntax highlighting for R and R Markdown (.R, .Rmd, .Rprofile, .Renviron, and NAMESPACE), including YAML frontmatter and inline or fenced R code chunks. | Matched client/catalog/UI keyword `markdown` (Auto-implementable Ready PR) |
| `TIER2` | `changelog` | Business and enterprise accounts can now use /swarm and open UI plugin panels from the side panel, Overview, New Tab, and title bar when allowed by organization admin settings. | Matched protocol/RPC/orchestration keyword `plugin` (Draft PR + Protocol Probe) |
| `TIER2` | `changelog` | Added Cloudflare, Grafana Cloud, SonarQube, incident.io, Better Stack, Tavily, and Levels.fyi to the partner plugin marketplace, and updated the Gemini API plugin and 15 partner plugins. | Matched protocol/RPC/orchestration keyword `plugin` (Draft PR + Protocol Probe) |
| `TIER1` | `changelog` | You can now open and play audio and video files up to 200 MB in the side panel instead of hitting a 20 MB limit, and attach .amr voice recordings in Gemini conversations. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Text-heavy and dense PDFs now open and scroll faster in the side panel by deferring text-layer rendering, with a toolbar toggle to turn text selection on for very large documents. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Settings > Shortcuts now lists additional navigation, conversation, and layout shortcuts for customization and stops showing false conflict warnings for inactive bindings. | Matched client/catalog/UI keyword `layout` (Auto-implementable Ready PR) |
| `TIER2` | `changelog` | Messages sent immediately while the agent is working now appear as sent without pulsing and keep the turn above them steady on delivery. Agent response actions are now left-aligned below the status line, and a single running subagent opens from the status line | Matched protocol/RPC/orchestration keyword `subagent` (Draft PR + Protocol Probe) |
| `TIER1` | `changelog` | Improved performance when switching conversations, typing in long chats, scrolling large file diffs in Review, reverting turns, and playing the welcome intro. | General Antigravity 2.0 capability or UX update |
| `TIER1` | `changelog` | Selected conversations now have stronger contrast in light themes, disabled Download and Export actions stay visible with a reason when a file cannot load, and shell commands run in the first listed project folder. | Matched client/catalog/UI keyword `theme` (Auto-implementable Ready PR) |
| `TIER2` | `changelog` | Device management policies in admin_settings.json can now lock sign-in and project settings, enforce permission ceilings, disable remote control, and restrict plugins or marketplace access. | Matched protocol/RPC/orchestration keyword `plugin` (Draft PR + Protocol Probe) |
| `TIER2` | `changelog` | If you use remote agents, editing env-setup.sh now shows Saved setup routine with an Open in settings link, project setup scripts are labeled Environment, and multiple open windows share a single cloud polling loop. | Matched protocol/RPC/orchestration keyword `remote agent` (Draft PR + Protocol Probe) |

## Delivery Triage Summary
- **Tier 1 (Auto Ready PR)**: 3933 item(s)
- **Tier 2 (Draft PR + Protocol Probe)**: 1343 item(s)
- **Tier 3 (RFC Issue Only)**: 96 item(s)
