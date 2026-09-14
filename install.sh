#!/bin/sh
# Rebuild the herdr + Claude multi-agent setup on a fresh machine.
#
# Idempotent: safe to re-run. Backs up anything it would overwrite.
# Does NOT install the LaunchAgent or edit ~/.claude/CLAUDE.md — both are
# opt-in and are printed as manual steps at the end.
#
#   sh install.sh            # install
#   sh install.sh --check    # show what it would do, change nothing

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

say() { printf '%s\n' "$*"; }
run() { [ "$CHECK" -eq 1 ] && { say "  would: $*"; return 0; }; "$@"; }

backup() {
  [ -e "$1" ] || return 0
  [ "$CHECK" -eq 1 ] && { say "  would back up $1"; return 0; }
  cp "$1" "$1.bak.$STAMP"
  say "  backed up $(basename "$1") -> $(basename "$1").bak.$STAMP"
}

say "== 1. herdr"
if command -v herdr >/dev/null 2>&1; then
  say "  present: $(herdr --version 2>/dev/null || echo unknown) at $(command -v herdr)"
else
  if command -v brew >/dev/null 2>&1; then
    run brew install herdr
  else
    say "  !! no herdr and no brew. Install from https://herdr.dev then re-run."
    exit 1
  fi
fi
# A stray copy earlier in PATH than the real install will shadow it after an
# upgrade and break the client/server protocol match. Warn loudly.
FIRST=$(command -v herdr || true)
if [ -n "$FIRST" ] && [ "$FIRST" != "$(readlink -f "$FIRST" 2>/dev/null || echo "$FIRST")" ]; then :; fi
if [ -x "$HOME/.local/bin/herdr" ]; then
  say "  !! ~/.local/bin/herdr exists and will shadow the managed install."
  say "     Remove it unless you deliberately self-manage herdr there."
fi

say "== 2. scripts -> ~/.local/bin"
run mkdir -p "$HOME/.local/bin"
for f in herdr-tag-tab git-sync-src.sh; do
  backup "$HOME/.local/bin/$f"
  run cp "$HERE/bin/$f" "$HOME/.local/bin/$f"
  run chmod +x "$HOME/.local/bin/$f"
  say "  installed $f"
done
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) say "  !! ~/.local/bin is not on PATH — add it, or the keybindings will no-op." ;;
esac

say "== 3. herdr config"
run mkdir -p "$HOME/.config/herdr"
backup "$HOME/.config/herdr/config.toml"
run cp "$HERE/config/herdr-config.toml" "$HOME/.config/herdr/config.toml"
say "  installed config.toml"
if [ "$CHECK" -eq 0 ] && command -v herdr >/dev/null 2>&1; then
  herdr config check || say "  !! config check failed — see above"
  herdr server reload-config >/dev/null 2>&1 && say "  reloaded running server" || true
fi

say "== 4. git"
run git config --global fetch.prune true
say "  fetch.prune = true"

say "== 5. Claude integration"
if [ -d "$HOME/.claude" ]; then
  if command -v herdr >/dev/null 2>&1 && [ "$CHECK" -eq 0 ]; then
    herdr integration status 2>/dev/null | grep -E '^(claude|cursor):' || true
  fi
  say "  (herdr installs its own hook; run 'herdr integration install claude' if missing)"
else
  say "  ~/.claude not found — install Claude Code first, then re-run."
fi

cat <<EOF

== Manual steps (deliberately not automated) ==

1. Global worktree instruction — paste the block in
     $HERE/claude/CLAUDE-worktree-block.md
   into ~/.claude/CLAUDE.md. Claude's permission classifier blocks an agent
   from editing that file, so this one is yours.

2. Per-project memory (optional) — copy
     $HERE/claude/memory-worktree-before-editing.md
   to ~/.claude/projects/<project>/memory/ and add a line to that MEMORY.md.
   Only needed if you want the instruction scoped per repo instead of global.

3. Hourly git fetch (optional):
     cp $HERE/launchd/com.blairmason.git-sync-src.plist ~/Library/LaunchAgents/
     launchctl load ~/Library/LaunchAgents/com.blairmason.git-sync-src.plist
   Runs at login and hourly thereafter. Fetch-only by default.

Then start herdr with:  herdr
EOF
