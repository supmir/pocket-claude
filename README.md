# pocket-claude

**Start Claude Code on your own computer from your phone.**

*v0.1, beta. Tested on one Mac so far; see "Known limits" below. Reports welcome as GitHub issues.*

You, on your phone: *"give me a session in my website project"*
Claude, a few seconds later: *"Here you go"* and a link. Tap it and you're working on the real project, on your own computer.

```
phone (claude.ai or the Claude app)
   └─▶ the "launcher" on your computer ──▶ a session in whichever project you ask for
```

The **launcher** is one small always-on session. You open it on your phone and tell it which project you want.

## Before you start (30 seconds)

- **Works on:** Mac (tested) and Linux (not tested yet). **Windows: not yet.** Windows users can try the no-install `run` mode inside WSL, see "Without a background service".
- **You need a paid Claude plan** (Pro, Max, Team or Enterprise; not Free), signed in with your claude.ai account. API keys don't work for this. Claude Code is the **Code** tab in the Claude desktop app, next to Chat and Cowork, or you can type `claude` in a terminal.
- **On a Team or Enterprise plan,** an admin must first switch on "Remote Control" in the Claude Code admin settings. If you see "Remote Control is disabled by your organization's policy", that's why.
- **Your computer has to be awake.** It stays awake while plugged in. A desktop, Mac mini or server is ideal. A **laptop works with the lid open and plugged in**. Closing the lid, or running on battery, lets it sleep, and then your phone can't reach it. That's a limit of laptops, not something software can fix.
- **Whoever can sign in to your claude.ai account (or picks up your unlocked phone) can work on this computer.** Turn on two-step login.
- **Work or school computer?** Check with your IT team first: this installs a small program that starts when you log in, and some organisations don't allow that or have switched this feature off. You can still try the no-install mode below.

## Install

**Plugin (one step):** in Claude Code, run

```
/plugin install pocket-claude --marketplace supmir/pocket-claude
```

then say **"set up pocket-claude"**.

**Or paste this** into a Claude **Code** session (the Code tab of the Claude desktop app, or type `claude` in a terminal). Not the Chat tab:

> Set up pocket-claude: clone https://github.com/supmir/pocket-claude into a temporary folder, check out commit 6331f8bd02e36261e37a2681a310efaea43c5168, read skills/setup/SKILL.md, and follow it.

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

A project can ship its own settings and commands ("hooks") that run on your computer, which is why Claude Code asks you to trust a folder first. pocket-claude keeps that question with you: when a project isn't approved yet it shows what the project would run, and asks. Details, and what it can't protect against, in [SECURITY.md](SECURITY.md). If you ever open projects you don't control, keep the default (ask every time).

## Without a background service

`claude-spawn run <project-folder>` starts one session from a terminal on that computer. No background service, no launcher folder; it stops when you close the terminal (and keeps the Mac awake only while it runs). The project needs a one-time approval first. This is also the way to try it in WSL on Windows, with the terminal left open. Ask Claude to run it for you.

## For your IT or security team

Remote Control makes outbound HTTPS connections to claude.ai only; nothing listens on your computer. Your claude.ai login is the key: anyone with it can start sessions that run as you. pocket-claude adds a user-level service (no admin rights, no `sudo`), a few files, and trust entries in `~/.claude.json`. [SECURITY.md](SECURITY.md) lists every file and path, and `claude-spawn plan` prints them for your machine.

## Commands (Claude runs these for you)

```
claude-spawn doctor           check everything is healthy
claude-spawn plan             show what will be put on this computer
claude-spawn list             what's running
claude-spawn stop <name|all>  stop sessions
claude-spawn run <folder>     one session, this terminal only
claude-spawn untrust <folder> withdraw an approval
claude-spawn set permission-mode default|acceptEdits|plan
claude-spawn uninstall        remove it all
```

## Known limits

- Closing a laptop lid or running on battery lets the computer sleep; your phone can't reach it until it wakes.
- Linux and the always-on launcher have only been checked by reading the code, not run end to end on a real machine yet.
- No Windows support. No signed releases yet.
- A project's settings are checked again if they change after you approve it, but a project you approved earlier is trusted by folder, not by who wrote it.

## Tested on

| System | Status |
|---|---|
| macOS (Apple silicon) | Tested by the maintainer |
| Linux (systemd) | Not tested yet; written carefully, reports welcome |
| Windows | Not supported yet |

## If something goes wrong

Say **"is pocket-claude working?"** in Claude Code. It runs a health check and explains the result in plain words. The usual causes are a sleeping computer, being logged out, or Claude being signed out.

Not affiliated with or endorsed by Anthropic. MIT licensed.
