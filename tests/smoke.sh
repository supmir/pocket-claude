#!/usr/bin/env bash
# Smoke test for the pure logic in claude-spawn (no services started, nothing outside a temp dir).
# Run: bash tests/smoke.sh
set -u
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/cfg" XDG_STATE_HOME="$T/state" XDG_DATA_HOME="$T/data" PC_CLAUDE_JSON="$T/claude.json"
mkdir -p "$HOME"
fail=0
t() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# a config value that tries to run code must not run, and a bad hub name must be refused
mkdir -p "$XDG_CONFIG_HOME/pocket-claude"
printf 'PC_HUB_NAME=x$(touch %s/pwned)\n' "$T" > "$XDG_CONFIG_HOME/pocket-claude/config"
out=$(bash "$(dirname "$0")/../bin/claude-spawn" root 2>&1); rc=$?
t "config is never executed" "[ ! -e '$T/pwned' ]"
t "bad hub name refused" "[ $rc -ne 0 ]"
rm "$XDG_CONFIG_HOME/pocket-claude/config"

. "$(dirname "$0")/../bin/claude-spawn"
set +e

t "name allowlist accepts"  "safe_name my-repo_1.x"
t "name rejects slash"      "! safe_name a/b"
t "name rejects leading -"  "! safe_name -rf"
t "path rejects quote"      "! safe_path \"a'b\""
t "path rejects &"          "! safe_path 'a&b'"
t "path allows spaces"      "safe_path 'My Projects/x'"
t "dest rejects .."         "! safe_dest '../x' && ! safe_dest 'a/../b' && ! safe_dest '/abs' && ! safe_dest '-x'"
t "dest allows acme/api"    "safe_dest acme/api"
t "dest rejects dot parts"  "! safe_dest 'proj/.claude' && ! safe_dest '.git' && ! safe_dest 'a/.hidden/b'"
t "mode allowlist"          "mode_ok acceptEdits && ! mode_ok bypassPermissions"

PC_ROOT="$T/proj"; mkdir -p "$PC_ROOT/a/b-c" "$T/other/x"
t "name under root"         "[ \"\$(derive_name \"$PC_ROOT/a/b-c\")\" = \"\$PC_MACHINE-a-b-c\" ]"
echo "$T/other/x" > "$statedir/$PC_MACHINE-x.dir"
n=$(derive_name "$T/elsewhere/x")
t "collision gets a suffix" "[ \"\$n\" != \"\$PC_MACHINE-x\" ] && case \"\$n\" in \"\$PC_MACHINE\"-x-*) true ;; esac"

PC_HUB_NAME='hub&name' PC_ROOT='/r&r'; printf '{{HUB_NAME}} {{ROOT}}\n' > "$T/tpl"
t "template fill keeps &"   "[ \"\$(fill '$T/tpl')\" = 'hub&name /r&r' ]"

# trust: preserves other keys, backs up, follows a symlink, refuses HOME
echo '{"keep":1,"projects":{"/x":{"a":1}}}' > "$T/real.json"; ln -s real.json "$T/claude.json"
command -v jq >/dev/null && {
  trust "$T/proj" 
  t "trust sets flag"       "jq -e '.projects[\"$T/proj\"].hasTrustDialogAccepted' '$T/real.json' >/dev/null"
  t "trust keeps data"      "jq -e '.keep==1 and .projects[\"/x\"].a==1' '$T/real.json' >/dev/null"
  t "trust keeps symlink"   "[ -L '$T/claude.json' ]"
  t "trust made backup"     "[ -f '$T/real.json.pocket-claude.bak' ]"
  t "trust refuses HOME"    "! (trust '$HOME') 2>/dev/null"
  echo 'not json' > "$T/real.json"
  rc=0; trust "$T/proj" 2>/dev/null || rc=$?
  t "trust failure is not silent" "[ $rc -ne 0 ] && [ $rc -ne 3 ]"
}
# change detection and untrust
mkdir -p "$T/g/.claude"; echo '{"a":1}' > "$T/g/.claude/settings.json"
echo '{}' > "$T/real.json"
command -v jq >/dev/null && {
  trust "$T/g"
  h1=$(stored_hash "$T/g")
  t "hash recorded on trust"   "[ -n '$h1' ] && [ '$h1' = \"\$(shipped_hash '$T/g')\" ]"
  echo '{"a":2}' > "$T/g/.claude/settings.json"
  t "hash changes with edit"   "[ '$h1' != \"\$(shipped_hash '$T/g')\" ]"
  untrust "$T/g"
  t "untrust clears flag"      "[ \"\$(jq -r '.projects[\"$T/g\"].hasTrustDialogAccepted' '$T/real.json')\" = false ]"
  t "untrust drops hash"       "[ -z \"\$(stored_hash '$T/g')\" ]"
}
exit $fail
