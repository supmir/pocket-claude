# pocket-claude

Run [Claude Code](https://claude.com/claude-code) on your own computer and drive it from your phone.

An always-on **hub** (Claude Code Remote Control) runs on your Mac, Linux or Windows
machine. Open claude.ai/code or the Claude app, pick the hub, and you get a session on
that machine. Ask it "give me a session in `owner/repo`" and `claude-spawn` starts another
Remote Control server for that repo and hands you the link.

- **Hub**: persistent. Restarts if it dies, starts at login.
- **Spawned sessions**: transient. They stop on reboot or logout.
- **macOS**: launchd + `caffeinate`. **Linux**: `systemd --user` + `systemd-inhibit`.
  **Windows**: Task Scheduler + `SetThreadExecutionState`.

> Not affiliated with or endorsed by Anthropic. "Claude" is their trademark.
> Windows support is **experimental** (untested by the author). macOS is tested; Linux is
> a straight systemd translation, so reports welcome.

## Install

Clone this repo, open Claude Code in it, and say:

> Set this up.

Claude follows [SETUP.md](SETUP.md): checks prerequisites, asks you a few questions
(projects folder, hub location, trust preference, sleep behaviour), installs
`claude-spawn`, starts the hub and gives you the link.

## Requirements

- Claude Code, logged in with a **claude.ai account** (Remote Control doesn't work with API keys)
- `git`, `gh` (for cloning private repos), and `jq` (macOS/Linux)
- The machine must stay awake and you must be logged in (see SETUP.md for per-OS options)

## Security: read this

Claude Code only runs Remote Control in folders you've **trusted**, and a trusted repo's
`.claude/` settings, hooks, `.mcp.json` and `CLAUDE.md` all take effect, including running
commands. At install you choose:

- **Opt-in (recommended if you ever clone repos you don't control).** `claude-spawn` refuses
  untrusted repos; you review them and run `claude-spawn trust <dir>`.
- **Auto-trust under your projects folder.** Convenient when everything in there is yours
  or your team's. It prints a note when a repo ships its own `.claude/`, `.mcp.json` or `CLAUDE.md`.

Trust is written to `~/.claude.json` (`projects["<path>"].hasTrustDialogAccepted`), an
undocumented internal file. It may change in a future Claude Code release; if it does,
`claude-spawn` falls back to telling you to accept the dialog in a terminal.

Anyone with access to your claude.ai account can drive sessions on your machine. Protect it.

## Commands

```
claude-spawn init <root> <hub-dir> <hub-name> <yes|no>   save config (yes = auto-trust under root)
claude-spawn hub                                         create + start the always-on hub
claude-spawn start <owner/repo | git-url | path> [dest]  session for a repo, prints the link
claude-spawn list | url <name> | stop <name> | root
claude-spawn trust <dir>                                 trust a repo (after you've reviewed it)
```

Logs: macOS `~/Library/Logs/pocket-claude/`, Linux `~/.local/state/pocket-claude/logs/`,
Windows `%LOCALAPPDATA%\pocket-claude\logs\`.

## License

MIT
