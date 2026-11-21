Remote Agents2-0Antigravity AppFeaturesRemote Agents Antigravity App FeaturesAntigravity AppAntigravity CLI

Available on:Antigravity AppAntigravity CLI

# Remote Agents
Section titled “Remote Agents”

Antigravity Remote Agents run your agent sessions and tools in an isolated, Google-managed remote environment rather than on your local machine.

Because execution happens remotely, Remote Agents continue working on long-running tasks and executing commands even when you close your browser, put your laptop to sleep, or switch between desktop and mobile devices.

## Remote Agents vs. Remote Control
Section titled “Remote Agents vs. Remote Control”

Antigravity provides multiple ways to work with agents remotely depending on where your code and tools live. Use the following table to compare Remote Agents and Remote Control:

FeatureRemote AgentsRemote Control

Execution environmentIsolated, Google-managed remote environmentYour own desktop workstation or server

Host machine requirementRuns independently; no local machine needs to stay onRequires your host machine to remain powered on and online

Workspace and filesRemote Resources (GitHub repositories, Google Drive files, and uploaded files)Local filesystem folders, local toolchains, and Git worktrees

Best forRepository tasks, mobile workflows, and background execution while awayTasks that require local hardware, local dev servers, or uncommitted local checkouts

To connect the Antigravity App directly to your own remote Linux machine over OpenSSH, see Connect over SSH.

## Getting started
Section titled “Getting started”

You can launch and manage Remote Agents from the Antigravity App on your desktop, from the Antigravity CLI in your terminal, or directly from any web browser at antigravity.google.com.

- Antigravity App

- Antigravity CLI

### Antigravity App
Section titled “Antigravity App”

### Start in the Antigravity App
Section titled “Start in the Antigravity App”

To create a remote project alongside your local projects in the Antigravity App, do the following:

- In the left sidebar, click + next to Projects (or open the project selector in the message box) and select New Remote Project.

- (Optional) Click Add Resource to attach GitHub repositories, Google Drive files, or uploaded files from your computer, and then click Next (or Skip if you do not add any resources yet).

- Enter a name in Set Project Name and click Create.

- Select your remote project and send a prompt in the message box to start a remote conversation.

You can also start a remote project directly from a GitHub repository in the message box:

- In the message box, click the project selector dropdown.

- Select Remote > GitHub Repositories. If you have not connected your GitHub account yet, click Connect GitHub to authorize access.

- Choose a repository from the list. Antigravity automatically selects an existing remote project for that repository or creates a new one.

### Start on the web
Section titled “Start on the web”

To use Remote Agents from a desktop or mobile browser without installing a local application, do the following:

- Open your browser and navigate to antigravity.google.com.

- Sign in with a personal Google Account on an eligible plan (Google AI Pro or Google AI Ultra).

- Enter a prompt in the message box to start a standalone remote conversation, or click Create Project next to Projects in the left sidebar to configure a project with GitHub repositories, Google Drive files, or uploaded files.

### Switch between Remote Agents and Remote Control
Section titled “Switch between Remote Agents and Remote Control”

If you also use Remote Control to connect to local Antigravity App or Antigravity CLI instances, use the instance switcher on antigravity.google.com (in the left sidebar above Settings on desktop browsers, or in the top bar on mobile) to switch between Remote Conversations and any of your connected host machines.

### Antigravity CLI
Section titled “Antigravity CLI”

### Start a remote agent session
Section titled “Start a remote agent session”

To run your Antigravity CLI conversations on Remote Agents, do the following:

-
Make sure that you’re running Antigravity CLI 1.4.12 or later. To update the CLI, run agy update.

-
Sign in to the CLI with a personal Google Account on an eligible plan (see Availability). The CLI shows the signed-in account and its plan when it starts, and in /help.

-
Start the CLI with the --remote-agent flag:

agy --remote-agent

-
Enter a prompt to start a remote conversation.

Every conversation that you start in the session runs on a remote agent, and the status line shows remote and the name of the remote project. Because the agent runs remotely, it keeps working on a task even if your machine goes to sleep or loses its connection, and you can continue the conversation later from the CLI, the Antigravity App, or the web.

### Choose a remote project
Section titled “Choose a remote project”

The first time that you start a remote agent session on a machine, the CLI creates a remote project named CLI Project (<hostname>) for that machine and opens new conversations in it. Later remote agent sessions on the same machine and account reuse that project.

To open conversations in a different remote project, such as one that you created in the Antigravity App or on the web, pass the project’s name or ID with --project:

agy --remote-agent --project="My remote project"

If no remote project has that name or ID, the CLI shows a warning and uses the machine’s default remote project instead.

To create a new remote project named after the current directory, pass --new-project:

agy --remote-agent --new-project

To switch projects during a session, run /projects, select a project, press Enter, choose Switch to project, and confirm. The CLI starts a new conversation in that project.

### Attach repositories and files
Section titled “Attach repositories and files”

Remote agents work with the resources attached to their remote project. To create a remote project with resources from the CLI, do the following:

- Run /projects and select + New project… at the top of the list.

- Enter a name for the project, and then press the right arrow key to choose its resources.

- Attach any of the following resources:
- GitHub: Select GitHub and press Enter. If you haven’t connected GitHub yet, sign in to it in your browser. Then select the repositories to attach.

- Google Drive: Select Google Drive and press Enter, signing in if you haven’t connected it yet. Then select + Add a Drive file by link… and paste a link to a Google Docs, Sheets, Slides, or Drive file.

- Uploaded files: Select Upload Files, then + Add a local file…, and enter the path of a file on your machine.

- Press Ctrl + S to create the project.

To change the resources of an existing remote project, run /projects, select the project, press Enter, and choose Edit. These are the same resources that you can manage in the Antigravity App and on the web. For details, see Remote projects and resources.

### Resume remote conversations
Section titled “Resume remote conversations”

Remote agent conversations are stored with your remote projects rather than on your machine. To continue your most recent remote agent conversation, run the following command:

agy --remote-agent -c

To resume a specific remote agent conversation, pass its ID:

agy --remote-agent --conversation=<conversation_id>

When you exit a remote agent session, the CLI prints the command that resumes your conversation. During a session, run /resume to choose from your remote agent conversations.

### Remote agent settings
Section titled “Remote agent settings”

Remote agent sessions use your CLI settings from settings.json, such as your color scheme, verbosity, and editor mode, except for permissions. For permissions, remote agents follow your remote agent settings, which apply to all of your remote agent sessions.

In a remote agent session, /config splits your settings into two tabs. Press Tab to switch between them:

- TUI: Your CLI settings. This tab hides the settings that your remote agent settings replace: Agent Mode, Tool Permission, Artifact Review, Sandbox Mode, and Non-Workspace Access.

- Remote Agent: Your remote agent settings:
- Permission Preset: Controls which actions the agent can take. default asks before sensitive operations, request review asks before every command, and always-proceed (turbo) runs all commands without restrictions.

- Plan Review Policy: Controls whether the agent asks you to review its documents, such as implementation plans: always ask or always proceed.

To manage the allow, deny, and ask rules that remote agents follow, run /permissions. In a remote agent session, it shows your remote agent rules instead of your local rules.

Unless you change it, the permission preset is always-proceed (turbo), so remote agents run commands without asking for approval. Remote agent sessions always use the default execution mode, so plan, accept-edits, and auto mode aren’t available.

### Features not available in remote agent sessions
Section titled “Features not available in remote agent sessions”

The following CLI features aren’t available in remote agent sessions yet:

- Print mode (--print)

- Code search (/codesearch)

- /diff, /fork, /rewind, and /btw

- Voice dictation (/voice)

- Running terminal commands yourself with !

- Sending messages to subagents with @

- MCP servers, plugins, and agent skills installed on your machine

If you run a slash command that isn’t available, the CLI reports that it’s not available in remote agent sessions.

### CLI troubleshooting
Section titled “CLI troubleshooting”

Review the following solutions for common issues with remote agent sessions:

- Remote conversations don’t start: Make sure that you’re signed in to the CLI with a personal Google Account on an eligible plan (see Availability). Run /help to see the signed-in account.

- Project Not Found warning: No remote project has the name or ID that you passed with --project, so the CLI uses this machine’s default remote project instead. Run /projects to see the names of your remote projects.

- is a local conversation warning: The ID that you passed with --conversation belongs to a local conversation. Start the CLI without --remote-agent to resume it.

- @ suggests sending a message first: A remote agent’s environment starts with the conversation. After you send the first message, @ suggests files from the remote agent’s environment.

- Not available in remote agent sessions.: The command isn’t supported in remote agent sessions yet. For the full list, see Features not available in remote agent sessions.

## Remote projects and resources
Section titled “Remote projects and resources”

While local projects mount directories from your workstation under Folders, remote projects attach external context under Resources. You can attach or remove resources when creating a remote project, or at any time under Project Settings > Resources by clicking Add Resource:

- GitHub: Authorize GitHub with OAuth and select one or more repositories to attach to the project. Conversations automatically clone and mount your connected repositories into the remote workspace for development. All private repositories within the same project must belong to the same GitHub user or organization owner; to work with private repositories from multiple owners, create a separate remote project for each owner.

- Google Drive: Select files or folders from your Google Drive (using the Google Drive Picker on the web interface or the Drive file list in the Antigravity App), such as Google Docs, Sheets, Slides, PDFs, or folders. The remote agent reads attached Drive files on demand during conversations.

- Uploaded files: Upload local files from your device (up to 8 MiB per file, 50 files and 100 MiB per project, and 2 GiB total across your account), including source code, text and data files, images, PDFs, and .zip archives. Uploaded files persist across conversations in the project and are staged under /home/antigravity/upload.

In the Antigravity CLI, run /projects to attach and remove resources. For details, see Attach repositories and files.

## Plugins and credentials
Section titled “Plugins and credentials”

Remote Agents support plugins that connect your agent to external tools and services:

- Open Customizations in the left sidebar and select the Marketplace tab (under Apps, or Installed once connected).

- Browse available plugins, such as GitHub, Google Drive, Google Docs, Google Sheets, Google Slides, and Google Calendar.

- Click Connect next to a plugin to authorize your account with OAuth.

In a remote agent session in the Antigravity CLI, run /plugin to connect plugins from the Discover tab and manage them in the Installed tab.

Your OAuth credentials are encrypted at rest and tokens are securely injected when the remote agent makes requests to authorized services.

## Next steps
Section titled “Next steps”

Explore related documentation and guides:

- Connect over SSH: Open a remote Linux machine directly in an Antigravity App window over OpenSSH.

- Remote Control: Connect to and control local Antigravity App and CLI sessions running on your own machines.

- Projects: Learn how projects organize workspaces, scoped settings, and conversations.

- Plugins: Configure plugins and external integrations across Antigravity surfaces.

- Permissions and security: Configure permission presets and fine-grained tool access rules.
