# Security

## What this is, security-wise

pocket-claude runs `claude remote-control` as a background service so your phone can start
Claude Code sessions on your computer. Whoever can sign in to your claude.ai account (or holds
your unlocked phone) can start sessions that run commands as you. Use two-step login, and lock
your phone.

## What it does and doesn't do

- Writes: a background service, its scripts (`~/.local/share/pocket-claude` or the Windows/macOS equivalent), a settings file, logs, a `pocket-claude-hub` folder, and trust entries in `~/.claude.json` (backed up to `~/.claude.json.pocket-claude.bak` before each change; Windows never writes it).
- Doesn't: use `sudo`, edit shell startup files, open listening ports, or send data anywhere. Network traffic is Claude's own, outbound to claude.ai.
- Logs contain the session link. They are readable only by you where the system allows it. Treat the link like a private URL.
- Remove everything: say "remove pocket-claude", or run `claude-spawn uninstall`.

## Trust model

A project's `.claude/` settings, hooks, `.mcp.json` and `CLAUDE.md` can run commands once the
folder is trusted. pocket-claude:

- trusts only its own hub folder automatically;
- trusts any other folder only after you have said yes (the assistant is told to show you what the folder contains first);
- never auto-trusts a project it has just downloaded;
- offers an advanced `set trust-under-root yes` that auto-trusts existing projects under your projects folder. Don't turn it on if you ever open projects you don't control.

Limits you should know: the "yes" is relayed through the assistant, so a prompt-injected
assistant could ask you for it; read what you're approving. Trust is keyed by folder path and
doesn't expire, so a later `git pull` of malicious code into an approved project runs. The hub's
own instructions live in a folder the hub can write to.

## Inputs

Names, destinations, paths and settings are validated (allowlists; no `..`; git gets `--`;
configuration is parsed, never executed). Paths containing quotes, `&`, `<`, `>`, `%`, `$`,
backticks or backslashes are refused rather than escaped.

## Releases

Releases are git tags (`v0.1.0` ...). The setup prompt in the README pins a tag. Prefer a tag
over `main` if you're cautious, and read what changed before updating the plugin.

## Reporting a vulnerability

Open a private report: https://github.com/supmir/pocket-claude/security/advisories/new
Please don't file public issues for security problems.
