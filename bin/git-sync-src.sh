#!/bin/sh
# Keep ~/src repos' remote-tracking refs current.
#
# Default: fetch only. Never touches a working tree, never moves HEAD --
# safe to run while agents are mid-edit. This is all that's needed for
# `EnterWorktree`, which branches from origin/<default-branch>.
#
# With --ff: additionally fast-forward the local default branch, but ONLY
# when it is provably safe (checked out, no tracked edits, no divergence).
# Any repo failing a guard is fetched and left alone.
#
# Usage: git-sync-src.sh [--ff] [--quiet]

set -u
ROOT="${GIT_SYNC_ROOT:-$HOME/src}"
DO_FF=0
QUIET=0
for a in "$@"; do
  case "$a" in
    --ff) DO_FF=1 ;;
    --quiet) QUIET=1 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || echo "$@"; }

export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}"

fetched=0; ffwd=0; failed=0

for gitpath in "$ROOT"/*/.git; do
  [ -e "$gitpath" ] || continue
  repo=$(dirname "$gitpath")
  name=$(basename "$repo")

  # Linked worktrees share the parent's object store and refs; fetching the
  # main checkout already refreshes them. Skip them to avoid duplicate work.
  common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
  case "$common" in
    "$repo"/.git) ;;
    *) continue ;;
  esac

  if ! git -C "$repo" fetch --all --prune --quiet 2>/dev/null; then
    say "fetch-failed  $name"
    failed=$((failed + 1))
    continue
  fi
  fetched=$((fetched + 1))

  [ "$DO_FF" -eq 1 ] || continue

  # Default branch, as the remote reports it.
  def=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || continue
  def=${def#origin/}
  [ -n "$def" ] || continue

  # Guard 1: that branch must be the one checked out.
  [ "$(git -C "$repo" rev-parse --abbrev-ref HEAD)" = "$def" ] || continue
  # Guard 2: no tracked modifications (untracked files are fine and are kept).
  [ -z "$(git -C "$repo" status --porcelain --untracked-files=no)" ] || continue
  # Guard 3: no local commits the remote lacks -- ff-only would fail anyway.
  [ "$(git -C "$repo" rev-list --count "origin/$def..HEAD" 2>/dev/null)" = "0" ] || continue

  behind=$(git -C "$repo" rev-list --count "HEAD..origin/$def" 2>/dev/null)
  [ "${behind:-0}" -gt 0 ] || continue

  if git -C "$repo" merge --ff-only "origin/$def" --quiet 2>/dev/null; then
    say "ff  $name  +$behind"
    ffwd=$((ffwd + 1))
  else
    say "ff-blocked  $name  (untracked file collision?)"
  fi
done

say "fetched=$fetched fast-forwarded=$ffwd failed=$failed"
