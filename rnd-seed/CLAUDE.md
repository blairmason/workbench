# R&D / roadmapping space

This is a **notes repo, not a code repo**. Its whole job is to stop research
from evaporating into one-off sessions scattered across the other repos.

## Do not use a worktree here

The global instruction in `~/.claude/CLAUDE.md` says to call `EnterWorktree`
before the first file edit. **That does not apply in this repo.** Edit files
directly on `main`.

Worktrees exist to stop concurrent agents from clobbering each other's *code*.
Here, the whole point is that everything lands in one shared, visible place —
a worktree would hide new notes on an unmerged branch, which is exactly the
scattering this repo exists to fix.

## Layout

```
inbox.md          raw capture, newest at top. Unstructured, triaged later.
topics/<slug>.md  one durable subject per file. The real destination.
roadmap/<period>.md   what we intend to do and why, per quarter.
decisions/NNNN-<slug>.md   decisions with consequences. Numbered, append-only.
```

## Filing rules

**Prefer appending to an existing topic over creating a new one.** Check
`topics/` first. Fragmentation across near-duplicate files is the failure mode
this repo is meant to prevent, not reproduce.

Every topic file carries a header:

```markdown
# <Title>

**Status:** exploring | settled | superseded by [[other-topic]]
**Updated:** YYYY-MM-DD
**Sources:** backend (session af86dc6c), DD dashboard xyz, PR #11722
```

**Every claim needs provenance.** A finding with no source is a rumour. Cite the
repo and session it came from, plus the primary evidence — a PR, a dashboard, a
query, a log line. Prefer a link or an exact query over a summary.

**Mark uncertainty explicitly.** `Verified:` for something checked against
primary evidence, `Believed:` for a strong inference, `Open question:` for
what's unresolved. Never let an inference harden into a fact by being restated.

**Record what was ruled out and why.** The alternatives rejected are usually
more valuable later than the option chosen, because they're what stops the same
ground being re-litigated.

**Update in place; don't append contradictions.** If a new finding overturns an
existing claim, rewrite the claim and note the change under the header. A file
holding both the old and new answer is worse than either alone.

## Decisions

`decisions/` entries are append-only. Once written, a decision is not edited
except to add `**Superseded by:** NNNN` at the top. That preserves the reasoning
that applied at the time, which is the only thing that makes a decision log
worth keeping.

## What does not belong here

- Code, scripts, or config that something else executes — those live in the repo
  that runs them (or `~/dotfiles`).
- Secrets, tokens, customer data, or anything unredacted from a production log.
- Anything that is really a ticket. File it in Linear (tagged
  `claude-generated`) and link it from the relevant topic.
