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
- Name it after the task (`EnterWorktree` with `name: "add-search-index"`), not
  a random slug, so it's identifiable in `git worktree list`.
- **Run `git fetch` immediately before `EnterWorktree`.** The worktree is cut
  from `origin/<default-branch>` — the *remote-tracking ref*, which only moves
  when something fetches. Skip this and you branch from whenever that ref was
  last updated, which can be days stale, and you won't find out until the merge
  conflicts. Fetching touches no working tree, so it's safe to do while other
  agents are mid-edit.
- Don't fast-forward the local default branch to "fix" staleness, and don't
  switch the main checkout's branch. Neither affects where your worktree is
  cut from, and both disrupt whatever else is using that checkout.
- The default base is `origin/<default-branch>`, which is what we want — the
  main checkout often sits on an unrelated feature branch, and new work
  should not stack on it.
- On finishing: `ExitWorktree` with `keep` if the branch has work worth
  pushing, `remove` if it was abandoned. Don't leave `agent-*` litter behind.

**Why:** several agents run concurrently against one checkout (herdr groups
them as tabs in a single space per repo). Without isolation they share a
working tree and overwrite each other's edits. Worktrees are what makes the
concurrency safe, and they keep branch management out of the terminal layout.

The fetch rule is what keeps "isolated" from also meaning "stale". Freshness is
only needed at one moment — the instant the branch is cut — and only in the one
repo being worked in, so doing it here is both narrower and more reliable than
a background job sweeping every repo on a timer.
