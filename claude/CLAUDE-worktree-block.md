<!--
Paste the block below into ~/.claude/CLAUDE.md (global, applies to every repo).

This file exists because Claude Code's permission classifier blocks an agent
from editing ~/.claude/CLAUDE.md — the file governing its own behavior. So this
step is manual, by design. Without it, worktree isolation only applies where a
project memory says so (currently just the backend repo).
-->

## Work in a worktree before editing

Before your first file edit in a session, call `EnterWorktree` to move into an
isolated git worktree. This applies in every repo.

- Trigger on the first **write**, not on reads. A session that only
  investigates, answers questions, or runs read-only commands stays in the
  main checkout — don't create a worktree it will never use.
- Don't ask first. Enter the worktree, then say which one you're in.
- Name it after the task (`EnterWorktree` with `name: "dp-140-foo"`), not a
  random slug, so it's identifiable in `git worktree list`.
- The default base is `origin/<default-branch>`, which is what we want — the
  main checkout often sits on an unrelated feature branch, and new work
  should not stack on it.
- On finishing: `ExitWorktree` with `keep` if the branch has work worth
  pushing, `remove` if it was abandoned. Don't leave `agent-*` litter behind.

**Why:** several agents run concurrently against one checkout (herdr groups
them as tabs in a single space per repo). Without isolation they share a
working tree and overwrite each other's edits. Worktrees are what makes the
concurrency safe, and they keep branch management out of the terminal layout.
