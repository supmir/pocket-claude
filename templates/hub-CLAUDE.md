# pocket-claude hub

This repo is served by an always-on Remote Control server named `{{HUB_NAME}}`.
New sessions from claude.ai/code or the Claude app start here, on this machine.

When the user asks for a session in another repo, use `claude-spawn`
(`claude-spawn.ps1` on Windows):

- `claude-spawn start <owner/repo | git-url | path> [dest]`: starts a Remote
  Control server in the repo and prints its claude.ai link. Reply with that
  link. A repo that isn't local yet is cloned to `{{ROOT}}/<dest>` (default: the
  repo name); put it in the right subfolder, e.g. dest `acme/api`.
- `claude-spawn root` prints the projects root; `claude-spawn list`,
  `claude-spawn url <name>`, `claude-spawn stop <name>`.
- Spawned servers are transient: they stop on reboot or logout unless started again.
- Remote Control only runs in trusted folders. Never edit trust settings in
  `~/.claude.json` yourself; leave that to `claude-spawn`.
  - If it exits with "Not trusted yet", tell the user. Auto-trust is a setting
    they chose at install time; otherwise they run `claude-spawn trust <dir>`
    after reviewing the repo, or run `claude` there once and accept.
  - When it prints a note that the repo ships `.claude/`, `.mcp.json` or
    `CLAUDE.md`, pass that note on to the user.
- Private repos need GitHub auth (`gh auth login`, then `gh auth setup-git`).
- Check for a local copy of a repo (under `{{ROOT}}`) before cloning.
