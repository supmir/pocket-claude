# pocket-claude

**Start Claude Code on your own computer from your phone.**

You, on your phone: *"give me a session in my website project"*
Claude, a few seconds later: *"Here you go"* and a link. Tap it and you're working on the real project, on your own computer.

```
phone (claude.ai or the Claude app)
   └─▶ always-on helper on your computer ──▶ a session in whichever project you ask for
```

## Install

You need [Claude Code](https://claude.com/claude-code) signed in with a **claude.ai account** (API keys don't work for this). Then:

**Plugin (one step):** in Claude Code, run

```
/plugin install pocket-claude --marketplace supmir/pocket-claude
```

then say **"set up pocket-claude"**.

**Or paste this into Claude Code** (the terminal, or the Code tab of the Claude desktop app, not ordinary chat):

> Set up pocket-claude: clone https://github.com/supmir/pocket-claude (tag v0.1.0) into a temporary folder, read skills/setup/SKILL.md, and follow it.

Claude asks one question, tells you in plain words what it will do, and gives you a link. That's the whole install. To undo everything later, say **"remove pocket-claude"**.

## Know this first

- **Your computer has to be awake.** It keeps itself awake while plugged in. **Closing a laptop lid pauses it** (lid open and plugged in, or an external display, works).
- **Anyone who can sign in to your claude.ai account can open sessions on your computer.** Turn on two-step login.
- **Sessions you start from your phone are temporary.** They stop when the computer restarts or you log out. The always-on helper comes back by itself.
- **Work or school computers:** your organisation may have switched this off, and it may not allow background helpers. Ask first.
- **Windows is experimental.** The maintainer hasn't tested it.

## What it changes on your computer

- One background helper that starts when you log in (macOS login item, Linux user service, Windows scheduled task).
- A hidden folder with a few files, a `pocket-claude-hub` folder in your home folder, a small settings file, and logs.
- It marks the hub folder as trusted in Claude's settings (`~/.claude.json`, backed up first). It marks other projects as trusted **only after you say yes**.
- It never uses `sudo`, never edits your shell files, and opens no network ports. It sends nothing anywhere itself.

## Safety, in short

A project you open a session in can run its own settings, hooks and tools on your computer, which is why Claude Code asks you to trust a folder first. pocket-claude keeps that question with you: it shows what a project contains and asks before approving it, and never approves something it just downloaded on its own. Details in [SECURITY.md](SECURITY.md).

## Commands (Claude runs these for you)

```
claude-spawn doctor           check everything is healthy
claude-spawn list             what's running
claude-spawn stop <name|all>  stop sessions
claude-spawn set permission-mode default|acceptEdits|plan
claude-spawn uninstall        remove it all
```

## Tested on

| System | Status |
|---|---|
| macOS (Apple silicon) | Tested by the maintainer |
| Linux (systemd) | Not tested yet; written carefully, reports welcome |
| Windows | Not tested; expect rough edges (laptop lids, battery, OneDrive folders) |

## If something goes wrong

Say **"is pocket-claude working?"** in Claude Code. It runs a health check and explains the result in plain words. The usual causes are a sleeping computer, being logged out, or Claude being signed out.

Not affiliated with or endorsed by Anthropic. MIT licensed.
