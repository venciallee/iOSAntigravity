Permissions2-0Antigravity AppFeaturesPermissions Antigravity App FeaturesAntigravity AppAntigravity CLIIDE ExtensionsAntigravity IDE

Available on:Antigravity AppAntigravity CLIIDE extensionsAntigravity IDE

# Agent permissions
Section titled “Agent permissions”

Antigravity uses a unified fine-grained permission engine to evaluate sensitive tool operations across Deny, Ask, and Allow access lists. If you are using Antigravity with Gemini Enterprise, see Antigravity in Gemini Enterprise.

- Antigravity App

- Antigravity CLI

## Antigravity App
Section titled “Antigravity App”

### Updated permission settings
Section titled “Updated permission settings”

Antigravity uses a robust, unified permission engine to secure your environment while enabling autonomous workflows. Every sensitive operation the agent performs is represented as a permission resource formatted as action(target).

Permissions are evaluated across three distinct access lists:

- Deny: The action is blocked immediately.

- Ask: The agent pauses and prompts for your explicit approval before proceeding.

- Allow: The action is allowed without prompting.

#### Permission presets
Section titled “Permission presets”

The permission preset controls how agent actions are approved. Your configured allow, deny, and ask rules are layered on top of the preset and always take precedence:

PresetTerminal sandboxTerminal CommandsFile AccessMCP & Web

Request ReviewDisabledAlways askWorkspace onlyAsk

Default(default)EnabledAllowed in sandbox; ask outsideWorkspace + temp dirsAsk

AutoEnabledAllowed in sandbox; checked automatically outsideWorkspace + temp dirsAsk

TurboDisabledAllowed (unrestricted)Full filesystemAllowed

The two presets that use the sandbox work as follows:

- Default (“Ask before sensitive operations.”; default): Terminal commands run inside the isolated Terminal sandbox with access restricted to your workspace and temp directories and no network access. When a command needs network connectivity or host resources, the agent requests to run it outside the sandbox—prompting for your approval unless covered by a command(...) allow rule.

- Auto (“Automatically decide if commands run.”): Commands also run inside the terminal sandbox by default. When a command needs to run outside the sandbox, Antigravity automatically evaluates it so safe, reversible commands run without prompting, while risky or irreversible commands still ask for your approval.

Refer to Agent settings for more detail on each preset.

#### Change your permission preset
Section titled “Change your permission preset”

You can set a preset for all projects, override it for a single project, or switch presets from the message box.
For all projectsSection titled “For all projects”

To change the preset for all projects, open Settings > General > Global Permissions > Permission Preset (Permissions > This Computer if remote agents are available to you):

The checkmark marks your current global preset.
For a single projectSection titled “For a single project”

To override the global preset for a single project, change the project’s preset under Settings > Projects. New projects default to Inherit Global, which follows your global preset.
From the message boxSection titled “From the message box”

In v2.23.0+, you can also choose a preset from the permissions picker in the message box:

The picker changes your global preset, or the project’s preset if the project overrides it. To remove a project override, choose Use Global Settings.

#### Supported actions and matching rules
Section titled “Supported actions and matching rules”

The following table lists the supported permission actions, their target formats, and their default behavior:

ActionTarget FormatDefault Fallback

read_fileread_file(/path), read_file(dir), or read_file(*)Ask (Allowed in workspace)

write_filewrite_file(/path) or write_file(*)Ask (Allowed in workspace)

read_urlread_url(domain) or read_url(*)Ask

execute_urlexecute_url(domain) or execute_url(*)Ask

download_urldownload_url(domain) or download_url(*)Ask

commandcommand(prefix), command(regex:pattern), or command(*)Ask (Allowed in sandbox under the Default and Auto presets)

mcpmcp(server/tool), mcp(server/*), or mcp(*)Ask

Each action matches its target as follows:

- read_file: Matches absolute paths or paths relative to project workspace roots. Grants recursive read access to all contained files and folders. Using read_file(*) matches all files on the system.

- write_file: Same as read_file. Implicitly grants read_file for the exact same target path.

- read_url: Matches hostnames and subdomains (for example, google.com covers mail.google.com). Ignores URL path segments. Using read_url(*) matches any domain.

- execute_url: Covers the browser subagent opening or redirecting to a page on a domain. Matches hostnames and regular subdomains and ignores URL path segments, while isolating localhost by :port (for example, localhost:3000 is separate from localhost:8080) and requiring explicit rules for sensitive Google subdomains (such as mail.google.com, docs.google.com, drive.google.com, and console.cloud.google.com). A read_url grant doesn’t cover it.

- download_url: Covers the built-in browser agent in the Antigravity App downloading files from a domain (configurable under Browser Actuation Rules in v2.30.0+, with interactive download prompts in v2.31.0+). Uses the same domain, localhost:port, and sensitive Google subdomain matching rules as execute_url (data: and blob: downloads always ask once, and executable or active-markup file types are blocked). Refer to Browser use permissions and safety guardrails.

- command: Matches by exact word or token prefix literally by default. To match by regular expression, start the target with the regex: prefix (each whitespace-separated token is evaluated as an anchored regular expression ^(?:pattern)$, for example, command(regex:npm run (build.*))). Covers execution both inside and outside the sandbox.

- mcp: Matches exact MCP tools or all tools on a specified server (applies equally to local and remote MCP servers). Using mcp(*) matches any tool.
When commands require an exact matchSection titled “When commands require an exact match”

Certain shell constructs can hide arbitrary command execution behind an otherwise benign prefix—for example, command or process substitution ($(...), backticks, <(...)), arithmetic contexts ($((...))), brace expansion ({a,b}), non-literal command names, network or file descriptor redirections, and developer-tool flags that execute subcommands (such as git -c core.pager=<cmd> or tar --to-command). When Antigravity detects any of these (or cannot cleanly parse the command), it disables prefix matching for the entire command line: the command runs without prompting only if a rule matches the full line character-for-character (or across the full raw line for regex: rules), and otherwise falls back to Ask.

Standard shell composition still prefix-matches normally: pipelines, &&/||/; chains, quoted literals, plain $VAR arguments, simple file redirects, and transparent wrappers (timeout, nohup, nice, env, whose inner command is evaluated on its own). For example, with command(git) in your Allow list, git status && git log runs without prompting, while git log $(whoami) prompts for approval.
Understanding read_url and execute_url across the platformSection titled “Understanding read_url and execute_url across the platform”

Antigravity checks read_url and execute_url in three areas:

- Web page reading: When the agent fetches web page Markdown for research, it checks your read_url grants.

- Browser subagent: When the browser subagent opens a page or triggers a file download, it checks your execute_url and download_url grants for that domain, not read_url (and every file upload requires one-time approval, even in Turbo). For details, refer to Browser use and Allowlist and denylist.

- Terminal sandboxing: Any domain granted under read_url is compiled directly into the sandbox’s outbound network allowlist, permitting commands like curl or npm to connect to authorized hosts.
Cross-platform command and path matchingSection titled “Cross-platform command and path matching”

Antigravity ensures your permission rules work consistently whether you’re developing on macOS, Linux, or Windows. On macOS and Linux, paths use standard forward slashes (/). On Windows, Antigravity automatically normalizes paths prior to rule evaluation by stripping drive letters (for example, C:) and converting all backslashes (\) to forward slashes (/).

#### Implicit permission rules
Section titled “Implicit permission rules”

Antigravity applies the following implicit permission rules:

- Write implies read: Allowing write_file on a path automatically grants read_file on that path.

- Deny read implies deny write: Denying read_file on a path immediately blocks write_file on that path.

#### Interactive permission prompts
Section titled “Interactive permission prompts”

When the agent encounters an operation requiring approval (Ask mode), an interactive card appears in your editor. Before clicking Allow for file, URL, or MCP permissions, you can directly edit the target string in the prompt card to expand the granted scope (for example, broadening a single file request like /project/file.txt to the parent directory /project). Antigravity validates that your edited target safely covers the operation and applies the expanded grant for the remainder of the turn, preventing repeated prompts for related operations. (Note: Scope editing isn’t supported for terminal commands).

#### Terminal commands and the sandbox
Section titled “Terminal commands and the sandbox”

Under the Auto and Default presets, the agent runs terminal commands inside an isolated Terminal sandbox, which by default has access only to your workspace and system temp directories, and no network access. Commands can run without manual approval in the sandbox, and your permission grants can further shape what the sandbox can reach:

- Paths granted under read_file dynamically populate the sandbox’s read-only filesystem allowlist.

- Paths granted under write_file dynamically populate the sandbox’s read-write filesystem allowlist.

- Domains granted under read_url define outbound network access policies.

Because some commands cannot run in the sandbox—for example, those requiring network access—the agent can still choose to run commands outside the sandbox:

- Default(default): Commands outside the sandbox prompt for your approval unless already allowed or denied by a command rule.

- Auto: Antigravity automatically evaluates commands that need to run outside the sandbox so safe, reversible commands proceed without prompting, while risky or irreversible commands still require approval.

#### Default system behaviors and guardrails
Section titled “Default system behaviors and guardrails”

When an action isn’t explicitly listed in your Allow, Deny, or Ask lists, Antigravity falls back to secure system defaults:

- Commands: Under the Default preset, commands run without prompting inside the sandbox and require approval to run outside it. Under Auto, safe commands outside the sandbox run without prompting, while sensitive or irreversible commands pause for approval.

- Workspace files: Reading and writing files inside your active project directory is allowed without prompting, while non-workspace files require approval.

- Web browsing defaults to Ask: Actions for read_url and execute_url default to Ask. Before the agent reads or opens a web page, it pauses and prompts for your explicit approval unless an allow rule is configured.

- MCP tools default to Ask: Unconfigured MCP tool calls prompt for approval.

#### Configuration examples
Section titled “Configuration examples”

The following examples show rules for the Allow list, which defines actions that run without prompting:

command(git) # Standard git commandscommand(regex:npm run (build|lint|test)) # Allow safe npm scripts using regexcommand(git push) # Allow git push, inside or outside the sandboxread_file(/var/log/app) # Read external log pathswrite_file(src/) # Edit relative src/ folderread_url(google.com) # Fetch Google subdomainsmcp(linter/*) # Run linter MCP tools

The following examples show rules for the Deny list, which defines actions that are permanently blocked:

command(rm -rf) # Block destructive deletionscommand(regex:curl .*) # Block unvetted curl downloadscommand(sudo) # Block sudo privilegeswrite_file(.git/) # Safeguard Git historywrite_file(/home/user/.ssh) # Safeguard SSH keys

The following examples show rules for the Ask list, which defines actions that pause for manual confirmation:

command(*) # Prompt all commandsexecute_url(aws.amazon.com) # Prompt before opening AWS pagesmcp(sql/execute_mutation) # Prompt modifying SQL queries

### Previous permission settings
Section titled “Previous permission settings”

Antigravity uses a robust, unified permission engine to secure your environment while enabling autonomous workflows. Every sensitive operation the agent performs is represented as a permission resource formatted as action(target).

Permissions are evaluated across three distinct access lists:

- Deny: The action is blocked immediately.

- Ask: The agent pauses and prompts for your explicit approval before proceeding.

- Allow: The action is allowed without prompting.

#### Supported actions and matching rules
Section titled “Supported actions and matching rules”

The following table lists the supported permission actions in the previous permission settings, their target formats, and their default behavior:

ActionTarget FormatDefault Fallback

read_fileread_file(/path), read_file(dir), or read_file(*)Ask (Allowed in workspace)

write_filewrite_file(/path) or write_file(*)Ask (Allowed in workspace)

read_urlread_url(domain) or read_url(*)Ask

execute_urlexecute_url(domain) or execute_url(*)Ask

download_urldownload_url(domain) or download_url(*)Ask

commandcommand(prefix), command(regex:pattern), or command(*)Ask

unsandboxedunsandboxed(prefix), unsandboxed(regex:pattern), or unsandboxed(*)Ask

mcpmcp(server/tool), mcp(server/*), or mcp(*)Ask

Each action matches its target as follows:

- read_file: Matches absolute paths or paths relative to project workspace roots. Grants recursive read access to all contained files and folders. Using read_file(*) matches all files on the system.

- write_file: Same as read_file. Implicitly grants read_file for the exact same target path.

- read_url: Matches hostnames and subdomains (for example, google.com covers mail.google.com). Ignores URL path segments. Using read_url(*) matches any domain.

- execute_url: Covers the browser subagent opening or redirecting to a page on a domain. Matches hostnames and regular subdomains and ignores URL path segments, while isolating localhost by :port (for example, localhost:3000 is separate from localhost:8080) and requiring explicit rules for sensitive Google subdomains (such as mail.google.com, docs.google.com, drive.google.com, and console.cloud.google.com). A read_url grant doesn’t cover it.

- download_url: Covers the built-in browser agent in the Antigravity App downloading files from a domain (configurable under Browser Actuation Rules in v2.30.0+, with interactive download prompts in v2.31.0+). Uses the same domain, localhost:port, and sensitive Google subdomain matching rules as execute_url (data: and blob: downloads always ask once, and executable or active-markup file types are blocked). Refer to Browser use permissions and safety guardrails.

- command: Matches by exact word or token prefix literally by default. To match by regular expression, start the target with the regex: prefix (each whitespace-separated token is evaluated as an anchored regular expression ^(?:pattern)$, for example, command(regex:npm run (build.*))).

- unsandboxed: Matches command prefixes word-by-word literally by default (or with regex:). Commands matching this grant execute outside container isolation when terminal sandboxing is enabled.

- mcp: Matches exact MCP tools or all tools on a specified server (applies equally to local and remote MCP servers). Using mcp(*) matches any tool.
When commands require an exact matchSection titled “When commands require an exact match”

Certain shell constructs can hide arbitrary command execution behind an otherwise benign prefix—for example, command or process substitution ($(...), backticks, <(...)), arithmetic contexts ($((...))), brace expansion ({a,b}), non-literal command names, network or file descriptor redirections, and developer-tool flags that execute subcommands (such as git -c core.pager=<cmd> or tar --to-command). On Windows shells like PowerShell or Command Prompt, commands whose syntax cannot be cleanly split into separate words also fall into this category. When Antigravity detects any of these, it disables prefix matching for the entire command line: the command runs without prompting only if a rule matches the full line character-for-character (or across the full raw line for regex: rules, such as command(regex:git .*)), and otherwise falls back to Ask.

Standard shell composition still prefix-matches normally: pipelines, &&/||/; chains, quoted literals, plain $VAR arguments, simple file redirects, and transparent wrappers (timeout, nohup, nice, env, whose inner command is evaluated on its own). For example, with command(git) in your Allow list, git status && git log runs without prompting, while git log $(whoami) prompts for approval.
Understanding read_url and execute_url across the platformSection titled “Understanding read_url and execute_url across the platform”

Antigravity checks read_url and execute_url in three areas:

- Web page reading: When the agent fetches web page Markdown for research, it checks your read_url grants.

- Browser subagent: When the browser subagent opens a page or triggers a file download, it checks your execute_url and download_url grants for that domain, not read_url (and every file upload requires one-time approval, even in Turbo). For details, refer to Browser use and Allowlist and denylist.

- Terminal sandboxing: In sandbox mode, any domain granted under read_url is compiled directly into the container’s outbound network allowlist (AllowedDomains), permitting commands like curl or npm to connect to authorized hosts.
Cross-platform command and path matchingSection titled “Cross-platform command and path matching”

Antigravity ensures your permission rules work consistently whether you’re developing on macOS, Linux, or Windows. On macOS and Linux, paths use standard forward slashes (/). On Windows, Antigravity automatically normalizes paths prior to rule evaluation by stripping drive letters (for example, C:) and converting all backslashes (\) to forward slashes (/).

#### Implicit permission rules
Section titled “Implicit permission rules”

Antigravity applies the following implicit permission rules:

- Write implies read: Allowing write_file on a path automatically grants read_file on that path.

- Deny read implies deny write: Denying read_file on a path immediately blocks write_file on that path.

#### Interactive permission prompts
Section titled “Interactive permission prompts”

When the agent encounters an operation requiring approval (Ask mode), an interactive card appears in your editor. Before clicking Allow for file, URL, or MCP permissions, you can directly edit the target string in the prompt card to expand the granted scope (for example, broadening a single file request like /project/file.txt to the parent directory /project). Antigravity validates that your edited target safely covers the operation and applies the expanded grant for the remainder of the turn, preventing repeated prompts for related operations. (Note: Scope editing isn’t supported for terminal commands).

#### Terminal sandboxing (preview)
Section titled “Terminal sandboxing (preview)”

Permission grants also apply to commands when the sandbox is enabled:

- Paths granted under read_file dynamically populate the sandbox’s read-only filesystem allowlist.

- Paths granted under write_file dynamically populate the sandbox’s read-write filesystem allowlist.

- Domains granted under read_url define outbound network access policies.

#### Default system behaviors and guardrails
Section titled “Default system behaviors and guardrails”

When an action isn’t explicitly listed in your Allow, Deny, or Ask lists, Antigravity falls back to secure system defaults:

- Commands default to Ask: Unconfigured terminal commands (command and unsandboxed) require manual approval unless configured to run without prompting in your settings.

- Workspace files: Reading and writing files inside your active project directory is allowed without prompting, while non-workspace files require approval.

- Web browsing defaults to Ask: Actions for read_url and execute_url default to Ask. Before the agent reads or opens a web page, it pauses and prompts for your explicit approval unless an allow rule is configured.

- MCP tools default to Ask: Unconfigured MCP tool calls prompt for approval.

#### Configuration examples
Section titled “Configuration examples”

The following examples show rules for the Allow list, which defines actions that run without prompting:

command(git) # Standard git commandscommand(regex:npm run (build|lint|test)) # Allow safe npm scripts using regexunsandboxed(git push) # Allow git push outside sandboxread_file(/var/log/app) # Read external log pathswrite_file(src/) # Edit relative src/ folderread_url(google.com) # Fetch Google subdomainsmcp(linter/*) # Run linter MCP tools

The following examples show rules for the Deny list, which defines actions that are permanently blocked:

command(rm -rf) # Block destructive deletionscommand(regex:curl .*) # Block unvetted curl downloadscommand(sudo) # Block sudo privilegeswrite_file(.git/) # Safeguard Git historywrite_file(/home/user/.ssh) # Safeguard SSH keys

The following examples show rules for the Ask list, which defines actions that pause for manual confirmation:

command(*) # Prompt all commandsexecute_url(aws.amazon.com) # Prompt before opening AWS pagesmcp(sql/execute_mutation) # Prompt modifying SQL queries

## Antigravity CLI
Section titled “Antigravity CLI”

### CLI fine-grained permissions
Section titled “CLI fine-grained permissions”

To secure your workstation while enabling autonomous workflows, Antigravity CLI integrates a robust fine-grained permissions engine. Every sensitive operation the agent performs is represented as a permission resource formatted as action(target).

Permissions are evaluated across three distinct access lists configured inside your global settings (~/.gemini/antigravity-cli/settings.json):

- deny: The action is blocked immediately.

- ask: The agent pauses and prompts for your explicit approval before proceeding.

- allow: The action is auto-approved without prompting.

### Supported CLI actions and matching rules
Section titled “Supported CLI actions and matching rules”

Fine-grained permissions follow a standard schema pattern:

action(target)

The supported actions, target format specifications, and default fallbacks are listed in the following table:

ActionTarget FormatDefault Fallback

read_fileread_file(/path), read_file(dir), or read_file(*)Ask (Auto-allowed in workspace)

write_filewrite_file(/path) or write_file(*)Ask (Auto-allowed in workspace)

read_urlread_url(domain) or read_url(*)Ask

execute_urlexecute_url(domain) or execute_url(*)Ask

commandcommand(prefix), command(regex:pattern), or command(*)Ask

unsandboxedunsandboxed(prefix), unsandboxed(regex:pattern), or unsandboxed(*)Ask

mcpmcp(server/tool), mcp(server/*), or mcp(*)Ask

The matching algorithm for each action is as follows:

- read_file: Matches absolute paths or paths relative to workspace roots. Grants recursive read access to all contained files and folders. read_file(*) matches all files on the system.

- write_file: Same as read_file. Implicitly grants read_file for the exact same target path.

- read_url: Matches hostnames and subdomains (for example, google.com covers mail.google.com). Ignores URL path segments. read_url(*) matches any domain.

- execute_url: Covers the browser subagent opening a page on a domain, for example when it navigates to a URL or opens a new page. Matches hostnames and subdomains and ignores URL path segments. A read_url grant doesn’t cover it.

- command: Matches command prefixes word-by-word literally by default. If you want to use a regular expression, add the regex: prefix (for example, command(regex:npm run (build|lint|test))). Covers the command whether it runs inside or outside the terminal sandbox.

- unsandboxed: Business and enterprise accounts only. Other accounts ignore unsandboxed rules and show a warning; use command instead. Matches command prefixes word-by-word literally by default (or with regex:). Commands matching this grant execute outside container isolation when terminal sandboxing is enabled.

- mcp: Matches exact MCP tools or all tools on a specified server (applies to local and remote MCP servers). mcp(*) matches any tool.

#### CLI global wildcard syntax
Section titled “CLI global wildcard syntax”

Across all supported action types, passing the global wildcard * (such as read_file(*), command(*), and mcp(*)) matches all targets within that entire action namespace.

#### CLI implicit permission rules
Section titled “CLI implicit permission rules”

Antigravity CLI applies the following implicit permission rules:

- Write implies read: Allowing write_file on a path automatically grants read_file on that path.

- Deny read implies deny write: Denying read_file on a path immediately blocks write_file on that path.

#### CLI cross-platform path normalization
Section titled “CLI cross-platform path normalization”

Antigravity ensures your permission rules work consistently whether you’re developing on macOS, Linux, or Windows. On macOS and Linux, paths use standard forward slashes (/). On Windows, Antigravity automatically normalizes paths prior to rule evaluation by stripping drive letters (for example, C:) and converting all backslashes (\) to forward slashes (/).

#### CLI cross-platform command matching
Section titled “CLI cross-platform command matching”

On Windows shells like PowerShell or Command Prompt, commands that can’t be cleanly split into separate words require an exact match by default. To match a command and its subcommands on Windows, use the regex: prefix (for example, command(regex:git .*) to allow any git command).

### Default CLI system behaviors and guardrails
Section titled “Default CLI system behaviors and guardrails”

When an action isn’t explicitly listed in your allow, deny, or ask lists, the system falls back to secure system defaults:

- Workspaces are auto-allowed: In standard operation, reading and writing files inside your active project directory is automatically allowed (and approved without interactive diff prompts in auto and accept-edits modes).

- Commands run in the sandbox in auto mode: When auto mode is active, commands run inside the Terminal sandbox without prompting, and commands that need to run outside the sandbox are evaluated automatically so only risky or irreversible actions pause for approval.

- Web browsing defaults to Ask: Actions for read_url and execute_url default to Ask. Before the agent reads or opens a web page, it pauses and prompts for your approval unless an allow rule is configured.

- Other unconfigured actions default to Ask: Unconfigured mcp tools, non-workspace file access, and commands outside auto mode default to Ask, subject to your active execution mode and toolPermission setting.

### Execution modes and the terminal sandbox
Section titled “Execution modes and the terminal sandbox”

Your fine-grained allow, ask, and deny rules always take precedence (Deny > Ask > Allow). For operations not covered by an explicit rule, Antigravity CLI evaluates your active execution mode (--mode or agentMode in settings.json) and toolPermission policy:

- auto mode (--mode=auto or "agentMode": "auto", default where available in v1.5.7+): Automatically approves workspace file edits and runs terminal commands inside the Terminal sandbox by default. When a command needs to run outside the sandbox, Antigravity CLI automatically evaluates it so safe, reversible commands run without prompting, while risky or irreversible commands still pause for your approval. When active, the bottom-right status bar displays auto and the prompt placeholder reads Auto mode: edits & safe commands auto-approved (shift+tab to cycle).

- accept-edits mode (--mode=accept-edits): Automatically approves workspace file edits and creations while continuing to evaluate shell commands against your toolPermission policy and fine-grained rules.

- default mode (select default in /config, or set agentMode to ""): Prompts for interactive diff review before modifying or creating files, and evaluates shell commands against your toolPermission policy (request-review by default).

- toolPermission overrides: strict and always-proceed (--dangerously-skip-permissions) take precedence over auto mode. Outside auto mode, proceed-in-sandbox runs sandboxed commands without prompting and asks before commands outside the sandbox. Starting in v1.4.4, if the sandbox isn’t available on your machine, proceed-in-sandbox behaves like request-review (refer to Terminal sandbox).

Refer to Choose an execution mode for details on switching modes with Shift + Tab, --mode, or /config.

### Interactive CLI permission prompts
Section titled “Interactive CLI permission prompts”

When the agent encounters an operation requiring approval (Ask mode), an interactive prompt card appears in your TUI.

Before confirming Allow for file, URL, or MCP permissions, you can directly edit the target string in the prompt card to expand the granted scope (for example, broadening a single file request like /project/file.txt to the parent directory /project). The CLI validates that your edited target safely covers the operation and applies the expanded grant for the remainder of the turn, preventing repeated prompts for related operations. (Note: Scope editing isn’t supported for terminal commands).

### CLI configuration examples
Section titled “CLI configuration examples”

Add these rules to your ~/.gemini/antigravity-cli/settings.json file:

{ "permissions": { "allow": [ "command(git)", "command(regex:npm run (build|lint|test))", "read_file(/var/log/app)", "write_file(src/)", "read_url(google.com)", "mcp(linter/*)" ], "deny": [ "command(rm -rf)", "command(regex:curl .*)", "command(sudo)", "write_file(.git/)", "write_file(/home/user/.ssh)" ], "ask": ["command(*)", "execute_url(aws.amazon.com)", "mcp(sql/execute_mutation)"] }}

## Related resources
Section titled “Related resources”

Explore related documentation and guides:

- Permissions command: Manage rules interactively in the TUI.

- Sandbox customization: Enforce OS-level container isolation boundaries.

- Plugins and skills: Create your own custom skills and slash commands.

- Settings, rendering, and keybindings: Customize keyboard hotkeys and buffers.
