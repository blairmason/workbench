<!--
Paste the block below into ~/.claude/CLAUDE.md, under the worktree block.

Like that one, this can't be automated — Claude's permission classifier blocks
an agent from editing ~/.claude/CLAUDE.md. It's what makes learnings get filed
at the moment they happen, from whichever repo the session is in.
-->

## File durable learnings in the R&D repo

When a session establishes something that will still matter next month — and
that isn't specific to the repo you're in — append it to
`~/src/rnd/inbox.md` before you finish. Newest entry at the top, under the
`---`:

```markdown
## YYYY-MM-DD HH:MM — one-line summary
**From:** <repo> (session <first 8 of session id>)
<the finding, with its primary evidence: a PR, dashboard, query, or log line>
```

**What qualifies:** a cross-cutting finding, a decision and the options it ruled
out, a cost or performance characteristic, a vendor or platform constraint, a
roadmap-relevant conclusion, a corrected misunderstanding.

**What doesn't:** repo-local mechanics (a build flag, a test gotcha, a path) —
those belong in that repo's project memory, which is where they'll be recalled.
Nor anything already covered by an existing `~/src/rnd/topics/` file; append
there instead, and say you did.

Don't ask permission and don't let it interrupt the task — append, then mention
it in one line when you report back. Never put secrets, tokens, customer data,
or unredacted production logs in it.

**Why:** project memory is keyed to cwd, so learnings scatter into one namespace
per repo — and sessions running inside a git worktree get their own namespace
that is orphaned when the worktree is removed. The inbox is the one location
that survives both. `rnd-harvest` sweeps the namespaces after the fact; this
rule is what stops things needing to be swept at all.
