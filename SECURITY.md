# Security

## What this is, security-wise

pocket-claude runs `claude remote-control` as a background service so your phone can start
Claude Code sessions on your computer. Whoever can sign in to your claude.ai account (or holds
your unlocked phone) can start sessions that run commands as you. Use two-step login, and lock
your phone.

## What it writes (`claude-spawn plan` prints the exact paths)

- Scripts: `~/.local/share/pocket-claude`; settings: `~/.config/pocket-claude/config`; state: `~/.local/state/pocket-claude`.
- Logs (they contain the session link, treat it like a private URL): `~/Library/Logs/pocket-claude` (macOS) or `~/.local/state/pocket-claude/logs`.
- The launcher service: a LaunchAgent in `~/Library/LaunchAgents` (macOS, label `com.pocket-claude.<computer>-launcher`) or a systemd user unit (Linux). It starts at login and restarts itself. Sessions started from the phone get temporary service files (macOS: `~/Library/Application Support/pocket-claude/agents`, Linux: the same systemd folder) that are never started at login.
- `~/pocket-claude-launcher`: a git folder with instructions and a small permissions file. Setup runs `git init` and `git commit` there (with git hooks disabled).
- Trust entries in `~/.claude.json`. Your original file is copied once to `~/.claude.json.pocket-claude.bak`; later changes are not backed up again.
- Doesn't: use `sudo`, edit shell startup files, open listening ports, or send data anywhere. Network traffic is Claude's own, outbound to claude.ai.
- Remove everything: say "remove pocket-claude", or run `claude-spawn uninstall`. Approved projects stay marked in `~/.claude.json` unless you add `--untrust` (the uninstall lists them). `claude-spawn untrust <folder>` withdraws one.

## Trust model

A project's `.claude/` settings, hooks, `.mcp.json` and `CLAUDE.md` can run commands once the
folder is trusted. pocket-claude:

- trusts only its own launcher folder automatically;
- trusts any other folder only after you say yes. The script prints the project's hooks, server commands and instructions first, and `claude-spawn trust` only accepts a git project folder;
- never auto-trusts a project it downloaded, now or on a later call;
- remembers a fingerprint of what each approved project can run (`.claude/`, `.mcp.json`, `CLAUDE.md`) and asks again if it changes, for example after a `git pull`. Projects you approved in Claude Code itself are fingerprinted the first time pocket-claude sees them;
- offers an advanced `set trust-under-root yes` that auto-trusts existing projects under your projects folder. Don't turn it on if you ever open projects you don't control.

The real second gate: the launcher is only allowed to run `start`, `list`, `url`, `stop` and `doctor` without asking. `trust` is deliberately not on that list, so **Claude Code itself asks you to confirm the approve command** on your phone. Read it.

Limits you should know:
- The "yes" is relayed through an assistant, so a prompt-injected assistant could ask you for it. Read what you're approving.
- Trust is keyed by folder path and doesn't expire. The fingerprint check catches changes to settings and instructions, not changes to ordinary code that a project's own scripts later run.
- The launcher's own instructions live in a folder the launcher can write to. With the default permission mode that needs your approval; with `acceptEdits` it doesn't, so `acceptEdits` weakens this. `claude-spawn doctor` warns about it, and about a broad "allow all shell commands" setting in your own Claude settings.
- Cloning over `ssh` or `git@` URLs offers your ssh agent to that server; only use hosts you know.

## Inputs

Names, destinations, paths and settings are validated (allowlists; no `..`, no dot-folders such as `.claude`; git gets `--`; configuration is parsed, never executed). Paths containing quotes, `&`, `<`, `>`, `%`, `$`, backticks or backslashes are refused rather than escaped.

## Releases

Releases are git tags (`v0.1.0` ...), and the README's paste-in install names an exact commit, which can't be moved. Tags can be moved by the repository owner and nothing is signed yet, so read the code (about 500 lines of bash) if you're cautious, and read what changed before updating.

## Reporting a vulnerability

Open a private report: https://github.com/supmir/pocket-claude/security/advisories/new
Please don't file public issues for security problems.
