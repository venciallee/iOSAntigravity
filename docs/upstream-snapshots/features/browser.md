Browser use2-0Antigravity AppFeaturesBrowser use Antigravity App FeaturesAntigravity AppAntigravity CLIIDE ExtensionsAntigravity IDE

Available on:Antigravity AppAntigravity CLIIDE extensionsAntigravity IDE

# Browser use
Section titled “Browser use”

In Google Antigravity, the agent can open web pages, interact with your running application, inspect console errors and failed network requests, take screenshots, and verify visual fixes before finishing a task.

Browser use in the Antigravity App: ask the agent to playtest a local checkout page, watch the browser subagent open localhost:5174/checkout in the built-in browser and reproduce a calculation error, inspect the Review diff after the code fix, and verify the updated total with zero console errors.

## Start a browser task
Section titled “Start a browser task”

- Antigravity App

- Antigravity CLI

### Antigravity App
Section titled “Antigravity App”

### Ask in plain language or run /browser
Section titled “Ask in plain language or run /browser”

When signed in with a personal Google Account (v2.30.0+), you don’t need to set up Chrome or type a slash command first. Describe what you want verified, tested, or researched in the message box, and the main agent starts a browser subagent automatically in the built-in browser:

Playtest Annual billing with promo code LAUNCH15 on http://localhost:5174/checkout, fix any bug you hit, and verify the updated total in the browser.

You can also invoke /browser explicitly whenever you want to direct a request straight to the browser subagent:

/browser Open http://localhost:3000, switch to a 390px mobile viewport, verify that the navigation drawer opens and closes cleanly, and report any console errors.

For quick questions answered by static documentation text, the agent reads pages directly without opening a browser tab. It delegates to the browser subagent when a task needs live rendering, clicks or form input, responsive layout checks, visual screenshots, console or network inspection, or pages where you’re signed in.

### Model usage
Section titled “Model usage”

Each browser subagent runs in its own isolated context window so page snapshots and screenshots don’t crowd your main conversation:

- Default model: Browser subagents run on a Gemini Flash model by default to keep UI interactions fast and conserve higher-tier quota. To run the browser subagent on a specific model from your model picker, ask for it in your prompt.

- Quota fallback: If Gemini Flash quota runs out or isn’t available, the agent stops and asks how you want to proceed instead of switching to another model automatically.

### Antigravity CLI
Section titled “Antigravity CLI”

### Connect Chrome and run /browser
Section titled “Connect Chrome and run /browser”

In the Antigravity CLI, the browser subagent drives your local Google Chrome (version 144 or later) on the same machine through the Chrome DevTools MCP server (launched with npx):

-
Make sure Node.js (npx on your PATH) and Google Chrome (v144+) are installed on the machine where agy is running.

-
Open Google Chrome and go to chrome://inspect/#remote-debugging.

-
Turn on Allow remote debugging for this browser instance.

-
In your agy session, run /browser followed by the task and a clear completion check:

/browser Open http://localhost:3000/dashboard, verify that the analytics charts render, and report any console or failed network requests.

-
When Chrome prompts you to allow remote debugging, click Allow within 60 seconds.

-
Run /agents or press Alt + J to monitor the browser subagent or respond to site permission prompts, or press Ctrl + K to approve a pending request from your main conversation.

For the full list of DevTools profiling, Lighthouse, and emulation capabilities in Chrome, refer to the Browser command (/browser) guide.

## Watch, browse alongside, and take over
Section titled “Watch, browse alongside, and take over”

In the Antigravity App, the built-in browser lives in the side panel right next to your conversation so you can see every click, scroll, and input as it happens:

- Tab and cursor indicators: While an agent controls a tab, the tab’s icon changes to an agent cursor arrow (with a spinning ring while a page loads). On the page, an animated cursor moves between targets, adapts for scrolling and typing, and displays a status pill describing the current step (or Thinking… while the subagent plans its next move).

- No focus theft: Browser subagents run without taking keyboard focus away from your conversation box or other tabs. Scrolling or clicking inside an agent-controlled tab doesn’t abort the run, and opening a manual tab of your own keeps working normally.

- Foreground tab protection: If you’re actively reading a tab in the side panel when the agent starts browsing, new browser subagents open their own tabs in the background instead of navigating away from the page you’re viewing.

### Run parallel browser tabs
Section titled “Run parallel browser tabs”

For multi-page audits, environment comparisons, or broad documentation sweeps, the agent can launch multiple browser subagents concurrently. Each subagent owns its own dedicated tab in the side panel and cannot navigate, inspect, or close another subagent’s tab or tabs that you opened yourself.

Parallel browser subagents in the Antigravity App: three browser subagents open Pricing, Docs, and Changelog tabs simultaneously to spot a quota mismatch while you type a follow-up prompt in the conversation without losing focus.

### Pause, take over, and sign in
Section titled “Pause, take over, and sign in”

- Stop and take over: Click the red Stop button at the bottom of any agent-controlled tab to halt that browser subagent immediately and return the tab to your manual control (Browser: you took over). Stopping the main conversation also stops its active browser subagents.

- Sign in and resume: The built-in browser keeps an isolated, persistent cookie profile for each account you sign in with in Antigravity—separate from your Chrome profile—so your site sessions stay signed in across tabs and app restarts. When a browser task hits Google Sign-In, a third-party OAuth or SSO provider (such as Microsoft, Apple, Okta, or Auth0), multi-factor authentication, a passkey prompt, or a CAPTCHA:
- The agent leaves the login page open in the built-in browser tab, pauses, and asks you to finish signing in.

- Sign in directly in that tab (or sign in ahead of time in any built-in browser tab).

- Reply in the conversation—for example, Signed in, continue—and the browser subagent reclaims the authenticated tab and picks up where it stopped.

## Use the built-in browser manually
Section titled “Use the built-in browser manually”

You can use the Antigravity App’s built-in browser on any desktop account to preview local servers, read docs next to your code, and send page context back to the agent:

- Open a page or tab:
- Click a link in an agent response or artifact to open it in the built-in browser.

- Hold Cmd (macOS) or Ctrl (Windows and Linux) while clicking a link—or middle-click it—to open it in a background built-in browser tab (v2.30.0+). Hold Cmd + Shift (macOS) or Ctrl + Shift (Windows and Linux) to open it in a new foreground tab.

- Hold Shift (or Option on macOS / Alt on Windows and Linux) while clicking a link to open it in your system’s default external browser (v2.30.0+).

- Press Cmd + T (macOS) or Ctrl + T (Windows and Linux), or click New Tab (+) in the side panel, and choose Browser (or type a URL or search query directly into Search or enter a URL). For local HTTP servers, include http://, such as http://localhost:3000.

- Toolbar controls: Use Back, Forward, and Reload to navigate; click the connection security icon in the address bar to check TLS certificate details or choose Delete cookies and site data for that site (v2.30.0+); open Downloads to view downloaded files; click Add screenshot to conversation (the camera icon) to attach a snapshot of the visible viewport to your prompt; or click Open in external browser.

- Comment or quote selected text: Select text on a page and right-click to choose Comment or Quote (v2.30.0+):
- Comment (or press C): Attaches feedback anchored to the passage and sends it with your next message.

- Quote (or press Cmd + L on macOS / Ctrl + L on Windows and Linux): Inserts the selected passage and page URL into your message box.

- Connect hardware devices (v2.30.0+): During manual browsing, sites that use WebUSB, WebHID, or Web Serial display a device picker below the address bar so you can choose a device and click Connect.

## Permissions and safety guardrails
Section titled “Permissions and safety guardrails”

Browser subagents combine your permission preset with dedicated site, upload, download, and page-isolation protections:

- Site navigation approvals (execute_url): Under the Request Review, Default, and Auto presets, navigating to an unapproved site pauses with Allow executing actions on this URL? so you can choose Yes, allow this time, Yes, allowdomainin this conversation, or Yes, always allowdomain (or edit the domain target before approving). Every cross-origin redirect hop is checked before the agent reads or interacts with the destination:
- Per-port localhost isolation: Loopback addresses (localhost, 127.0.0.1, [::1]) are isolated by port—approving localhost:3000 doesn’t grant access to localhost:8080. To allow every port on localhost, enter localhost without a port in Browser Actuation Rules.

- Sensitive Google subdomains: Sensitive Google properties—such as mail.google.com, docs.google.com, drive.google.com, calendar.google.com, chat.google.com, and console.cloud.google.com—are never covered by a general google.com or cloud.google.com grant and always require their own explicit rule.

- One-time file upload confirmation: A browser subagent cannot attach arbitrary files from disk. Only files staged for the task (up to 20 files, 50 MiB each, 100 MiB total) can be selected, and every upload pauses with Allow uploadingfilestoorigin? (Yes, allow this time)—even under the Turbo preset.

- File download approvals (download_url): Pre-configure Download files rules in Browser Actuation Rules (v2.30.0+). When the built-in browser subagent triggers a file download (v2.31.0+), the download pauses on Allow the browser agent to download a file?, showing the file name, origin, any redirect source, MIME type, and destination folder. You can allow downloads from that domain for the current run, for the conversation, or always (data: and blob: downloads require one-time approval, including under Turbo):
- Approved downloads save to your configured Download Location, appear with an Agent badge in the Downloads drawer (Show in folder only, so agent downloads cannot be launched with a click), and make safe exported files readable to the subagent.

- Executable, installer, script, and active markup downloads—including .exe, .dmg, .pkg, .msi, .bat, .cmd, .ps1, .sh, .dll, .so, .dylib, .html, .svg, .xml, and .wasm—are automatically blocked for agent-controlled tabs.

- What the Turbo preset changes: Turbo automatically approves general execute_url site navigation and standard HTTP(S) download_url downloads, except for sites on your Deny list or outside your administrator’s allowed domains. File uploads, data:/blob: downloads, sign-in pages, payment surfaces, and blocked file types remain gated or blocked even in Turbo.

- Always-on protections:
- No credential, payment, or CAPTCHA entry: Identity provider pages (accounts.google.com, myaccount.google.com, Microsoft, Apple, Okta, Auth0) and payment processors (such as Stripe, PayPal, Adyen, Braintree, and Google Pay) are blocked from agent actuation. Payment, sign-in, and unapproved cross-origin iframes are automatically masked out of screenshots and snapshots before reaching the model.

- Isolated browser actions and scrubbed logs: In the built-in browser, the subagent acts through structured browser actions inside an isolated worker with no workspace/shell tools and no arbitrary in-page JavaScript evaluation, and network diagnostics strip cookies, Authorization headers, and OAuth/JWT tokens.

- No fullscreen, pointer lock, or local-network hijacks: Agent-controlled pages cannot enter fullscreen, lock your mouse pointer or keyboard (v2.31.0+), redirect external sites to localhost or private LAN IPs, or reach cloud metadata and link-local addresses.

## Configure browser settings
Section titled “Configure browser settings”

In the Antigravity App (v2.30.0+), open Settings > Browser to manage both the built-in browser and the browser subagent:

### Built-in Browser
Section titled “Built-in Browser”

- Open Links In: Choose whether clicking web links in chat opens them in the Built-in Browser (default) or your External Browser.

- Download Location: View, Change…, or Reset the folder where built-in browser downloads are saved (~/Downloads by default).

- Browsing History: Click Clear to remove visited URLs and address-bar autocomplete suggestions. (To clear cookies and storage for a specific site, click the security icon in that site’s address bar and choose Delete cookies and site data.)

### Browser Subagent
Section titled “Browser Subagent”

- Browser Actuation Rules: Click Edit to open Browser Actuation Permissions, where you can add Allow, Ask, or Deny rules under Execute URLs (sites the subagent may open) and Download files (sites the subagent may download from). For matching rules and enterprise domain restrictions, refer to Allowlist and denylist.

- Browser Javascript Execution Policy(shown when using Chrome DevTools MCP): Controls whether the Chrome-based /browser subagent asks before running evaluate_script (Request Review, default), runs without asking (Always Proceed), or blocks custom in-page scripts (Disabled). When the built-in browser agent is active, arbitrary in-page JavaScript execution isn’t used, so this setting is hidden.

- Organization controls: If your organization’s administrator disables the browser subagent, the Browser Subagent section shows a notice instead of these controls. For IDE browser settings (Antigravity > Open Settings > Browser), refer to the IDE browser overview.

## Compare browser modes across surfaces
Section titled “Compare browser modes across surfaces”

CapabilityAntigravity App (built-in browser, personal accounts v2.30.0+)Antigravity CLI & App business/enterprise (/browser)Antigravity IDE v2.6.0+ & VS Code v1.9.0+ (IDE browser)

Browser engine & setupBuilt-in side-panel browser (zero external browser or Node.js setup)Local Google Chrome (v144+) via Chrome DevTools MCP (npx / Node.js in CLI; bundled runtime in App)Local Google Chrome (v144+) via Chrome DevTools MCP (npx / Node.js; local workspaces)

How to startPlain-language prompts (auto-invoked) or /browser <task>/browser <task>/browser <task>

Parallel browser subagentsYes, each in its own isolated built-in browser tabSingle active Chrome debugging connection per instanceSingle active Chrome debugging connection per instance

Cookie and sign-in profileIsolated persistent profile per Antigravity account, with pause-and-resume login handoffYour running Google Chrome profileYour running Google Chrome profile

Visual playback and artifactsWatch live in the side panel with animated cursor and Stop button; ask the agent to save screenshots as artifactsScreenshots in subagent steps and optional session recordings (MP4 in Antigravity CLI v1.5.9+)Screenshots and optional WebM browser recordings

DevTools profiling & LighthouseConsole errors and sanitized failed/recent network requestsFull DevTools performance traces, Lighthouse audits, heap snapshots, network/CPU throttling, and evaluate_scriptFull DevTools performance traces, Lighthouse audits, console/network logs, throttling, and evaluate_script (per JS policy)

## Next steps
Section titled “Next steps”

- Browser command (/browser): Set up Chrome remote debugging and explore Chrome DevTools MCP capabilities and example prompts.

- Allowlist and denylist: Pre-configure site and file-download rules in Browser Actuation Rules.

- Agent permissions: Learn how permission presets, read_url, execute_url, and download_url work together.

- Side panel and Overview panel: Manage browser, file, artifact, and review tabs side by side with your conversation.

- Screenshots: Save browser screenshots as artifacts and leave region comments for the agent.
