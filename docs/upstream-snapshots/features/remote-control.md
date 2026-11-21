Remote Control2-0Antigravity AppFeaturesRemote Control Antigravity App FeaturesAntigravity AppAntigravity CLI

Available on:Antigravity AppAntigravity CLI

# Remote Control
Section titled “Remote Control”

Antigravity Remote Control allows you to securely connect to and drive your Antigravity desktop sessions and CLI instances running across your machines from any web browser.

As AI agents take on larger-scope tasks—such as full-subsystem refactorings, extensive test suite runs, and complex dependency migrations—operations can run for extended periods. Remote Control untethers you from your physical desk while preserving your entire local development environment.

- Antigravity App

- Antigravity CLI

## Antigravity App
Section titled “Antigravity App”

### Enabling Remote Control in the Antigravity App
Section titled “Enabling Remote Control in the Antigravity App”

You can enable Remote Control directly from the Antigravity App settings:

- Open the Settings panel by pressing Cmd + , (or Ctrl + , on Linux and Windows), or click Settings at the bottom of the left sidebar.

- Navigate to the Application section.

- Toggle Enable Remote Control to On.

- (Optional) Enter a Device Name (for example, workstation-primary or server-machine) to easily identify this machine in your instance list.

#### Connecting from a web browser
Section titled “Connecting from a web browser”

To access your remote Antigravity instance:

- Open your web browser on any device and navigate to the Antigravity Remote Control Dashboard. (Tip: On mobile devices, you can optionally install the web app to your home screen to receive push notifications when agents complete tasks or request input.)

- Sign in with the same Google Account that you used on your desktop application.

- In the instance switcher, select the machine you want to control.

- You now have full access to view active conversations, start new agent tasks, review implementation plans, and inspect artifacts.

### Desktop troubleshooting
Section titled “Desktop troubleshooting”

#### Antigravity App desktop
Section titled “Antigravity App desktop”

If you encounter issues connecting to your desktop instance, review the following troubleshooting steps:

- Machine does not appear in the web UI:
- Ensure that Enable Remote Control is toggled on in the Antigravity App settings on your host machine.

- Verify that your host machine has an active internet connection and is not asleep or suspended.

- Check that you are signed in with the same Google Account in both the desktop app and the web browser.

- Reconnection and disconnects:
- If your local network connectivity drops temporarily, the web interface automatically tries to reconnect. Any running background agent tasks and shell commands continue executing on your host machine uninterrupted as long as the host maintains an internet connection.

## Antigravity CLI
Section titled “Antigravity CLI”

### Overview
Section titled “Overview”

Remote Control lets you interact with your CLI instances remotely using the Antigravity desktop UI. Antigravity CLI supports two ways to use Remote Control:

- Interactive mode: Start a Remote Control connection in an active CLI instance using /remote-control or start it in a new instance by launching the CLI with the --remote-control flag. The tunnel stays open only for the lifetime of that CLI instance.

- Headless background daemon: Start a connection to an always-on headless CLI instance with agy remote-control start. You can interact with this instance remotely as long as the machine running it is on.

### Interactive mode
Section titled “Interactive mode”

#### Enable Remote Control in an active session (/remote-control)
Section titled “Enable Remote Control in an active session (/remote-control)”

You can turn on Remote Control at any point during an interactive agy terminal session without restarting the CLI.

Inside the prompt box, run /remote-control (or /remote-control on):

/remote-control

The CLI establishes a reverse tunnel for the current session and prints the session’s hostname along with a link to open the active conversation on another device:

Remote control on for this session.Hostname: devbox-swift-falconOpen https://antigravity.google.com/r/<instance-id>?p=c%2F<conversation-id> on another device to continue this conversation.

Open the printed URL in any web browser (on your laptop, tablet, or phone) signed in to the same Google Account to interact with the session using the Antigravity desktop UI.

To disconnect the remote tunnel while keeping your local terminal session running, run:

/remote-control off

Remote control off. This machine is no longer reachable from other devices.Hostname: devbox-swift-falcon

#### Launch directly with Remote Control (--remote-control)
Section titled “Launch directly with Remote Control (--remote-control)”

To start a remote connection immediately upon launching an interactive CLI session, use the --remote-control flag:

agy --remote-control

#### How interactive Remote Control works
Section titled “How interactive Remote Control works”
Session lifecycleSection titled “Session lifecycle”

Interactive Remote Control is strictly tied to the running agy terminal process:

- Automatic cleanup on exit: When you exit the interactive CLI (/exit, Ctrl + C, or Ctrl + D) or close the terminal window, the Remote Control tunnel automatically terminates and the instance disappears from the dashboard.

- Concurrent terminal sessions: Because each interactive CLI process generates its own session instance ID and session hostname, you can run agy --remote-control across multiple terminal tabs or project directories simultaneously.
Live bidirectional synchronizationSection titled “Live bidirectional synchronization”

When you connect to your interactive CLI session using the Antigravity desktop UI in your browser, both surfaces stay synchronized in real time:

- Shared live stream: Prompts submitted from your remote device stream live into your local terminal TUI as they happen, and thoughts, tool executions, and diffs generated in the terminal appear live in the remote UI.

- Cross-device tool approvals and questions: When the agent pauses for a tool confirmation (y/n) or asks an interactive clarifying question, you can respond from either your local terminal or the remote UI.

- CLI-controlled settings: You cannot toggle settings in the settings panel from the remote web interface; to change settings, use the CLI.

### Remote Control headless daemon
Section titled “Remote Control headless daemon”

Use the remote-control subcommand to register an always-on headless CLI instance that starts automatically in the background and stays connected whenever your machine is powered on:

agy remote-control start

The daemon registers as an OS service (a systemd user service on Linux, a LaunchAgent on macOS, or a Scheduled Task on Windows) and starts immediately without requiring an open terminal window.

Run agy remote-control status to view this machine’s instance name, then select it from the Antigravity Remote Control Dashboard to interact with it using the Antigravity desktop UI.

#### Managing the daemon
Section titled “Managing the daemon”

Use the following commands to manage the headless daemon:

agy remote-control start Register and start the daemonagy remote-control status Show the daemon's status and instance nameagy remote-control stop Stop the daemon and unregister it

#### Windows notes
Section titled “Windows notes”

Keep the following behavior in mind when running the daemon on Windows:

- Registering the daemon to start at boot requires an Administrator prompt. PowerShell and Command Prompt both work.

- From a normal prompt, start still works, but if your machine gets logged out or restarted, the daemon resumes only after you log back in; it cannot start on boot.

- status and stop work from a normal prompt.

#### Sign-in
Section titled “Sign-in”

The daemon uses the credentials you used to sign in to the CLI for authentication. This sign-in is separate from the Antigravity editor on the same machine.

#### Naming your machine (headless daemon)
Section titled “Naming your machine (headless daemon)”

For headless daemon instances, the instance name is how the machine appears in Remote Control:

-
Set it with the --name flag:

agy remote-control start --name "my-workstation"

Re-running start --name with a new value renames the machine.

-
If you never set a name, the daemon generates a friendly one (such as my-machine-distant-plume) on its first start. agy remote-control status shows the current name.

-
To rename by editing the settings file instead, open ~/.gemini/config/config.json on Linux or macOS or %USERPROFILE%\.gemini\config\config.json on Windows, change the value of cliRemoteControlHostname, save, and run agy remote-control start again to restart the daemon. The new name appears in the Antigravity Remote Control dashboard once the service restarts; edits do nothing while it’s running.

#### How the daemon runs
Section titled “How the daemon runs”

BehaviorLinuxmacOSWindows

StartsAt boot, nobody needs to log inWhen you log inAt boot (Administrator install); at login otherwise

Keeps running after you sign outYesNo, back at next login.Yes, with a boot install

Comes back by itself after a crashYesYesYes, up to three restart attempts, then at the next boot or by running agy remote-control start again

### Interactive mode vs. headless background daemon
Section titled “Interactive mode vs. headless background daemon”

Use the table below to choose between interactive Remote Control and the persistent background daemon:

FeatureInteractive mode (/remote-control / agy --remote-control)Headless background daemon (agy remote-control start)

ScopeSingle interactive terminal sessionEntire machine (background OS service)

LifecycleActive only while the terminal session is open and toggled onPersistent across logouts and system reboots

Instance namingFresh per-session name (for example, host-swift-falcon)Single persistent machine name (--name or cliRemoteControlHostname)

ConcurrencyMultiple concurrent terminal sessions supported per machineOne daemon service per machine

Direct handoff linkPrints a link directly into the active conversation threadAccessed using the instance switcher on antigravity.google.com

Best forStepping away from an active terminal task and continuing on mobile or webAlways-on remote access to a workstation or server anytime

### CLI troubleshooting
Section titled “CLI troubleshooting”

#### Interactive mode issues
Section titled “Interactive mode issues”

Review the following solutions for common interactive mode issues:

- Remote control is not enabled for your account.: Account or organization policy has not enabled the Remote Control feature flag. Contact your workspace administrator or verify that your account plan supports Remote Control.

- Instance disappears from the web dashboard: /remote-control and agy --remote-control create tunnels that automatically disconnect when the interactive terminal session exits (/exit or Ctrl + C), or when /remote-control off is run. To keep a machine reachable when no terminal is open, run agy remote-control start to install the headless daemon.

- Multiple CLI instances listed for the same machine: Each interactive CLI session uses a distinct session hostname so you can control multiple terminal windows simultaneously.

#### Headless daemon issues
Section titled “Headless daemon issues”

Review the following solutions for common headless daemon issues:

- Machine doesn’t show up in the Antigravity Remote Control dashboard: Run agy remote-control status. If it reports sign-in problems, run agy, sign in, and then run agy remote-control start again.

- Checking the logs: Inspect the daemon logs for your operating system:
- Linux: journalctl --user -u antigravity-cli-daemon -n 50

- macOS: ~/Library/Logs/antigravity-cli-daemon.log

- Windows: The newest cli-*.log under %USERPROFILE%\.gemini\antigravity-cli\log

- Rename didn’t take effect: The name is read when the daemon starts; run agy remote-control start again.

- Windows daemon only starts at login, not at boot: start was run from a non-Administrator prompt. Re-run agy remote-control start from an elevated prompt for start-at-boot.

- Connection keeps dropping and reconnecting: An old script-installed daemon may still be registered and competing with this one for the connection. Run agy remote-control start again; it removes the old service automatically.

- Two similar entries in the Antigravity Remote Control dashboard: One is the editor, and one is this daemon. They’re separate on purpose; rename whichever one you want to distinguish.

## Next steps
Section titled “Next steps”

Explore related documentation and guides:

- Connect over SSH: Open a remote Linux machine directly in an Antigravity App window over OpenSSH.

- Remote Agents: Run agent sessions in an isolated remote environment without keeping a local machine online.

- Settings overview: Explore configuration options across Antigravity.

- Permissions and security: Configure permission presets and tool access rules.
