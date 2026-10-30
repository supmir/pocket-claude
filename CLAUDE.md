# pocket-claude (maintainer notes)

If the user asks to set up, check, change or remove pocket-claude: read `skills/setup/SKILL.md` and follow it.
That file is the single source of truth for setup; don't duplicate it elsewhere.

- `bin/claude-spawn` is bash 3.2 compatible (macOS) and also runs on Linux; `bin/claude-spawn.ps1` is Windows (untested).
- `bash tests/smoke.sh` checks the pure logic (validation, config parsing, trust, naming). No CI by design.
- Keep it simple: no registry, no per-repo policy files, no extra backends. Validate every input that reaches a plist, unit file, script or `git` argument.
- Windows never writes `~/.claude.json`.
