# pocket-claude

**Start Claude Code on your own computer from your phone.**

You, on your phone: *"give me a session in my website project"*
Claude, a few seconds later: *"Here you go"* and a link. Tap it and you're working on the real project, on your own computer.

```
phone (claude.ai or the Claude app)
   └─▶ the "launcher" on your computer ──▶ a session in whichever project you ask for
```

The **launcher** is one small always-on session. You open it on your phone and tell it which project you want.

## Before you start (30 seconds)

- **Your computer must be awake.** It tries to stay awake while running. A desktop, Mac mini or server is ideal. A **laptop works with the lid open and plugged in**; closing the lid pauses it.
- **Anyone who can sign in to your claude.ai account (or holds your unlocked phone) can run commands on this computer.** Turn on two-step login.
- **Work or school computer?** Ask first. This installs a background service that starts at login and restarts itself, and your organisation may have switched the feature off. No service wanted? See "Without a background service" below.
- **Supported:** macOS (tested) and Linux with systemd (not tested yet). **Windows is not supported yet**; WSL may work.
- You need [Claude Code](https://claude.com/claude-code) signed in with a **claude.ai account** (API keys don't work for this).

## Install

**Plugin (one step):** in Claude Code, run

```
/plugin install pocket-claude --marketplace supmir/pocket-claude
```

then say **"set up pocket-claude"**.

**Or paste this** into Claude Code (the Code tab of the Claude desktop app, or `claude` in a terminal; not ordinary chat):

> Set up pocket-claude: clone https://github.com/supmir/pocket-claude (tag v0.1.0) into a temporary folder, read skills/setup/SKILL.md, and follow it.

Claude tells you in plain words what it will do, asks one question, and gives you a link. To undo everything later, say **"remove pocket-claude"**.

## Using it

On your phone open claude.ai/code (or the Claude app, Code tab), pick the session named `<your-computer>-launcher`, and say *"give me a session in my website project"*. The first time for each project, Claude asks you to approve it (see Safety).

## What it puts on your computer

- One background service for the launcher (macOS: a LaunchAgent; Linux: a systemd user service). It starts when you log in and restarts itself if it stops.
- Scripts in a hidden folder, a small settings file, logs (they contain your session link), and a folder `~/pocket-claude-launcher`.
- It approves the launcher folder in Claude's settings (`~/.claude.json`; your original is copied once to `~/.claude.json.pocket-claude.bak`). Other projects are approved **only after you say yes**.
- Sessions you start from the phone are temporary: they stop when the computer restarts or you log out.
- No `sudo`, no edits to your shell files, no open network ports. It sends nothing anywhere itself.
- Want to see the exact files first? Ask Claude to run `claude-spawn plan`.

## Safety, in short

A project you open a session in can run its own settings, hooks and tools on your computer, which is why Claude Code asks you to trust a folder first. pocket-claude keeps that question with you: when a project isn't approved yet it shows what the project would run, and asks. Details, and what it can't protect against, in [SECURITY.md](SECURITY.md). If you ever open projects you don't control, keep the default (ask every time).

## Without a background service

`claude-spawn run <project-folder>` starts one session in the current terminal only. Nothing is installed or left behind; it ends when you close the terminal.

## Commands (Claude runs these for you)

```
claude-spawn doctor           check everything is healthy
claude-spawn plan             show what will be put on this computer
claude-spawn list             what's running
claude-spawn stop <name|all>  stop sessions
claude-spawn run <folder>     one session, this terminal only
claude-spawn set permission-mode default|acceptEdits|plan
claude-spawn uninstall        remove it all
```

## Tested on

| System | Status |
|---|---|
| macOS (Apple silicon) | Tested by the maintainer |
| Linux (systemd) | Not tested yet; written carefully, reports welcome |
| Windows | Not supported yet |

## If something goes wrong

Say **"is pocket-claude working?"** in Claude Code. It runs a health check and explains the result in plain words. The usual causes are a sleeping computer, being logged out, or Claude being signed out.

Not affiliated with or endorsed by Anthropic. MIT licensed.
