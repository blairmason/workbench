---
name: worktree-before-editing
description: Enter an isolated git worktree before the first file edit in a session; herdr groups conversations one space per repo
metadata: 
  node_type: memory
  type: feedback
  originSessionId: af86dc6c-ff53-4bf8-99d1-e6edfeaa4530
  modified: 2026-09-11T20:44:38.717Z
---

Before your first file **edit** in a session, call `EnterWorktree` to move into
an isolated git worktree. Trigger on the first write, not on reads — a session
that only investigates or answers questions stays in the main checkout. Don't
ask first; enter, then say which worktree you're in. Name it after the task
(`name: "dp-140-foo"`) rather than a random slug. On finish, `ExitWorktree`
with `keep` if the branch has work worth pushing, `remove` if abandoned.

**Why:** Blair runs many concurrent Claude sessions against one checkout. As of
2026-09-11 his herdr layout is one space per repo (38 spaces, one per directory
under `~/src`), with each conversation a *tab* inside its repo's space — branches
are deliberately invisible to the terminal layout. Without worktree isolation,
sibling tabs share a working tree and overwrite each other's edits. `EnterWorktree`
defaults to branching from `origin/<default-branch>`, which is what we want: the
main checkout often sits on an unrelated feature branch.

**How to apply:** This memory only covers the backend project. The equivalent
instruction for *all* repos belongs in `~/.claude/CLAUDE.md` — Blair has to paste
it himself, since edits to the global instructions file are blocked by the
permission classifier. See [[fable-orchestration-only]] for the related
delegation pattern.
