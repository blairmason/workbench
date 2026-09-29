#!/bin/sh
# Set up herdr with this layout on a fresh machine.
#
# Idempotent and portable: no absolute paths, no assumptions about which repos
# or directories exist. Backs up anything it would overwrite.
#
#   sh install.sh            install
#   sh install.sh --check    dry run; change nothing
#
# Env:
#   BIN_DIR   where the helper scripts go (default: $HOME/.local/bin)

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
STAMP=$(date +%Y%m%d-%H%M%S)
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

say() { printf '%s\n' "$*"; }
run() { [ "$CHECK" -eq 1 ] && { say "  would: $*"; return 0; }; "$@"; }
backup() {
  [ -e "$1" ] || return 0
  [ "$CHECK" -eq 1 ] && { say "  would back up $(basename "$1")"; return 0; }
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
    say "  !! herdr not found and no brew. Install from https://herdr.dev, then re-run."
    exit 1
  fi
fi
# A second herdr earlier in PATH than the managed one will, after an upgrade,
# leave an old client talking to a new server: every command fails on protocol.
MANAGED=$(command -v herdr || true)
case "$MANAGED" in
  "$BIN_DIR/herdr")
    say "  !! herdr resolves to $BIN_DIR/herdr, which may shadow a package-managed"
    say "     install. Remove it unless you deliberately self-manage herdr there." ;;
esac

say "== 2. helper scripts -> $BIN_DIR"
run mkdir -p "$BIN_DIR"
for f in herdr-tag-tab herdr-new-tab herdr-new-space; do
  backup "$BIN_DIR/$f"
  run cp "$HERE/bin/$f" "$BIN_DIR/$f"
  run chmod +x "$BIN_DIR/$f"
  say "  installed $f"
done
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say "  note: $BIN_DIR is not on your PATH. The keybindings use absolute"
     say "        paths so they still work, but you won't be able to run the"
     say "        scripts by name." ;;
esac

if ! command -v fzf >/dev/null 2>&1; then
  say "  note: fzf not found. herdr-new-space falls back to a numbered menu."
fi

say "== 3. herdr config -> $CONFIG_DIR/config.toml"
run mkdir -p "$CONFIG_DIR"
backup "$CONFIG_DIR/config.toml"
if [ "$CHECK" -eq 1 ]; then
  say "  would render config.toml.tmpl with __BIN__=$BIN_DIR"
else
  sed "s|__BIN__|$BIN_DIR|g" "$HERE/config/herdr-config.toml.tmpl" \
    > "$CONFIG_DIR/config.toml"
  say "  rendered config.toml (__BIN__ -> $BIN_DIR)"
  if command -v herdr >/dev/null 2>&1; then
    herdr config check || say "  !! config check failed — see above"
    herdr server reload-config >/dev/null 2>&1 \
      && say "  reloaded the running server" || true
  fi
fi

cat <<EOF

== Optional, and manual by necessity ==

If you run several agents per repo, they share one working tree unless each
isolates itself. The block in
  $HERE/claude/CLAUDE-worktree-block.md
tells Claude Code to do that. Paste it into ~/.claude/CLAUDE.md — Claude's
permission classifier blocks an agent from editing that file, so it can't be
scripted.

Start herdr with:  herdr
Then: ctrl+b ? lists every binding from the running config.
EOF
