# SETUP (instructions for Claude)

You are setting up pocket-claude for the user on this machine. Do the work yourself,
step by step. **Show the user anything that needs sudo/admin or their password, and tell
them before you change system settings.** Detect the OS first (`uname -s`; Windows =
PowerShell). Use `bin/claude-spawn` on macOS/Linux and `bin/claude-spawn.ps1` on Windows.

## 1. Prerequisites (report what's missing, fix what you can)

1. `claude` is installed, recent, and supports `claude remote-control --help`. Note
   `command -v claude` (`Get-Command claude` on Windows); services run with a minimal PATH.
2. Claude Code is logged in with a **claude.ai account** (not an API key). If not, tell the
   user to run `claude`, then `/login`, in a terminal.
3. `git`, `gh`, and `jq` (macOS/Linux only) are installed. macOS: `brew install gh jq`.
   Private repos need `gh auth login` then `gh auth setup-git`; the user does that interactively.
4. Optional: Tailscale for SSH access. Not needed for Remote Control.

## 2. Ask the user (one message, with these defaults)

- **Projects root**: where their repos live (default `~/Documents`).
- **Hub directory**: default `<root>/pocket-claude-hub`.
- **Hub name**: default `<hostname>-hub`; this is what they pick in claude.ai/code.
- **Trust preference**: auto-trust repos under the projects root, or opt-in per repo?
  Explain: a trusted repo's hooks, MCP servers and `CLAUDE.md` run unattended, so
  **opt-in is the right choice if they ever clone repos they don't fully control.**
- **Sleep behaviour** (see step 3).

## 3. Keep the machine awake (explain options, let them choose)

The services already block *idle* sleep (`caffeinate -is` / `systemd-inhibit` /
`SetThreadExecutionState`). Beyond that:

- **macOS**: `sudo pmset -a sleep 0` never sleeps on AC (user runs it). A closed MacBook lid
  still sleeps unless it's on power with an external display (clamshell mode). Warn them.
  **FileVault**: after a reboot nothing runs until they log in once. Mention it; don't disable it.
- **Linux**: a user service runs only while logged in unless lingering is on: ask, then
  `sudo loginctl enable-linger $USER`. Laptop lid: `HandleLidSwitchExternalPower=ignore` in
  `/etc/systemd/logind.conf` (sudo, user's call). Full-disk encryption blocks boot-time start
  until unlock.
- **Windows**: `powercfg /change standby-timeout-ac 0` (never sleep on AC) and, for the lid,
  Power Options > "When I close the lid" > Do nothing. The task runs only while the user is
  signed in. Bitlocker/PIN prompts block unattended start.

## 4. Install

1. Put `claude-spawn` on PATH.
   - macOS/Linux: `mkdir -p ~/.local/bin && ln -sf "$PWD/bin/claude-spawn" ~/.local/bin/claude-spawn`
     (must be an **absolute** symlink; the script finds `templates/` through it). Ensure
     `~/.local/bin` is on PATH in the shell rc file (`~/.zshrc` / `~/.bashrc`).
   - Windows: add this repo's `bin` folder to the user PATH. If scripts are blocked, tell the
     user to run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
2. `claude-spawn init <root> <hub-dir> <hub-name> <yes|no>` with their answers.
3. `claude-spawn hub`. It creates the hub repo (with the CLAUDE.md from `templates/`), trusts
   it, installs the always-on service and prints the claude.ai link.
4. Verify the service is running (macOS `launchctl print gui/$(id -u)/com.pocket-claude.<hub-name>`,
   Linux `systemctl --user status pocket-claude-<hub-name>`, Windows `claude-spawn list`) and that the
   hub shows up in claude.ai/code. Give the user the link.

## 5. Trust handling (important)

- Trust is per git root in `~/.claude.json` (`.projects["<path>"].hasTrustDialogAccepted`) and
  does **not** inherit from parent folders. `claude-spawn` writes it atomically.
- **Never hand-edit `~/.claude.json` in a tool call.** A permission classifier may deny
  self-modification of trust settings. Run `claude-spawn` (or give the user the command).
- If startup fails with "Workspace not trusted", `claude-spawn` re-trusts and restarts once.
- Repos outside the projects root are never auto-trusted: tell the user to run `claude`
  there once and accept.

## 6. Test

1. `claude-spawn root` prints the projects root.
2. `claude-spawn start <existing repo>`: prints a link; `claude-spawn list` shows it.
3. `claude-spawn start <hub dir>` prints "already has a Remote Control server" (exit 3).
4. `claude-spawn stop <name>`.
5. A path outside the root is refused with "Not trusted yet" (exit 2).
6. Ask the user to log out/in or reboot once: the hub returns, spawned servers don't.

## 7. Final report

Tell the user: the hub link, the `claude` version, what they chose for sleep/lid/encryption
and what they still must run with sudo/admin, any deviations, and every repo whose shipped
`.claude`, `.mcp.json` or `CLAUDE.md` got auto-trusted.

## Notes

- Session URLs look like `https://claude.ai/code?environment=env_...` and are read from the
  service log, so no TTY is needed (verified on macOS/launchd).
- Spawned macOS agents live in `~/Library/Application Support/pocket-claude/agents/` (not
  `~/Library/LaunchAgents/`) so they are *not* reloaded at login.
- Windows trust keys are written with both slash styles because the key format there is unverified.
