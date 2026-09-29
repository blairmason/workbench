# herdr + Claude multi-agent setup

Snapshot of a working setup for running many concurrent Claude Code sessions in
one terminal. Captured 2026-09-14, herdr 0.9.0 on macOS.

```sh
sh install.sh --check   # dry run
sh install.sh           # install
```

Then do the manual steps it prints at the end (one of them matters — see
[Manual steps](#manual-steps)).

---

## The mental model

Get this right and the rest is detail.

**herdr's hierarchy is session → workspace ("space") → tab → pane.** An agent is
not an object in that tree — it is a process herdr *detected* running inside a
pane, reported by a hook. So herdr does not organize "agents working on a repo".
It organizes **directories**.

That has one sharp consequence: two Claude panes whose cwd is the same directory
are two agents editing the same working tree, and **herdr will not stop them or
warn you**.

This setup resolves that with a deliberate split:

| Layer | Owns | Why |
|---|---|---|
| **Space** | one per repo | what you navigate between |
| **Tab** | one per conversation | what you switch inside a repo |
| **Worktree** | one per agent, created by the agent | what keeps them from colliding |

Branches are deliberately **invisible to the terminal layout**. You never make a
space or tab per branch. Each agent isolates itself into its own git worktree
before its first edit, so the layout stays one-row-per-repo no matter how many
branches are in flight.

### Why not one space per worktree?

That is herdr's *native* grain — `herdr worktree create` makes a worktree and its
own space as a single object, and `worktree remove` addresses it by
`workspace_id`. It is a perfectly good model. It is just not this one: it gives
you a sidebar row per branch, which at 10+ concurrent agents is the thing you
were trying to escape.

Consequence of choosing repo-grouping: a space's sidebar row shows no branch, and
`herdr worktree remove` won't manage agent worktrees. Both are fine here —
branches belong to the agents.

---

## What's in the box

```
config/herdr-config.toml   the whole herdr config
bin/herdr-tag-tab          focus/priority/blocked tagging for tabs
bin/herdr-new-tab          new tab anchored at the space's repo root
bin/git-sync-src.sh        fetch (and optionally fast-forward) every repo in ~/src
bin/rnd-harvest            sweep all Claude memory namespaces into one digest
bin/rnd-weekly             weekly consolidation pass for ~/src/rnd
rnd-seed/                  starting CLAUDE.md + inbox for the R&D repo
claude/                    the two global instruction blocks + a project memory
launchd/                   optional hourly fetch + weekly consolidation agents
install.sh                 idempotent installer
```

---

## herdr config, section by section

Everything below is in `config/herdr-config.toml`. Validate any edit with
`herdr config check`, then apply it live with `herdr server reload-config` — no
restart needed.

### Grouping and navigation

- `ui.agent_panel_sort = "spaces"` — **this is the group-by-repo switch.** The
  alternative, `"priority"`, flattens every agent into one urgency-ordered queue,
  which is the opposite of grouping. You keep the jump keys either way.
- `keys.next_agent` / `previous_agent` / `focus_agent` — agent navigation ships
  **unbound**, which hides the main reason to run herdr at all: jumping straight
  to the agent that needs you.
- `keys.switch_workspace` — also unbound by default. With one space per repo this
  means "switch repo". It reaches only the first 9; `prefix+w`
  (`workspace_picker`) is the real navigation beyond that.
- `ui.show_agent_labels_on_pane_borders` — tell panes apart without focusing them.

### Surviving a restart

- `session.resume_agents_on_restore = true` — agent panes come back as
  `claude --resume <id>`, not bare shells. Requires an integration that reports a
  session ref (`herdr integration status` should show claude as v6+).
- `experimental.pane_history = true` — also bring back **scrollback**. Without
  it you get the conversation back above an empty terminal.

What survives a reboot: the layout, tab names, cwds, and the conversations.
What doesn't: **any running process** (no multiplexer can do otherwise), and
herdr **does not auto-start at login** unless you add a LaunchAgent.

### Notifications

- `ui.toast.delivery = "system"` — the default is `"off"`, meaning an agent
  finishing or blocking in a background space notifies **nowhere**.
- `ui.sound.enabled = false` — only because peon-ping already plays sounds via
  Claude hooks. Flip it if you'd rather herdr own them; it distinguishes
  background spaces, which peon-ping can't.

### Sidebar rows and value-based color

`ui.sidebar.agents.rows_by_agent.claude` puts Claude's live task title
(`terminal_title_stripped`) on its own row, so rows read by *what the agent is
doing* rather than ten identical `backend` labels.

Below that sit three metadata tokens, colored **by value** (herdr 0.9.0+):

```toml
{ token = "$p", fg = "#9399b2", rules = [
    { equals = "p0", fg = "#f38ba8", bold = true },
    { equals = "p1", fg = "#f9e2af" },
    { equals = "p2", fg = "#6c7086", dim = true },
] }
```

First matching rule wins; unspecified style fields inherit the default. Max 16
rules per token. String conditions are `equals`, `contains`, `starts_with`
(+ `ignore_case`); numeric are `gt` / `lt`, strict.

> Priority values are stored as the literal strings `p0`/`p1`/`p2` and matched
> with `equals` rather than numeric `gt`/`lt`. Token values arrive as strings and
> it's unverified whether herdr coerces them — `equals` sidesteps the question.

**These tokens carry only what herdr cannot detect.** `state_icon` already shows
working / idle / blocked-on-you automatically. Don't duplicate it.

---

## Tab tagging

Two independent slots, encoded as emoji at the front of the tab name:

| Slot | Marks |
|---|---|
| 1 — focus or priority | ⭐ focus · 🔴 p0 · 🟡 p1 · ⚪ p2 |
| 2 — blocked on | 👀 review · ✋ them |

They compose: `⭐👀 dp-140-composer` is the current focus, blocked on a review.

| Chord | Effect |
|---|---|
| `prefix+alt+f` | ⭐ focus — **exclusive**, demotes the previous focus to p0 |
| `prefix+alt+q` / `w` / `e` | 🔴 p0 / 🟡 p1 / ⚪ p2 |
| `prefix+alt+r` | 👀 blocked on review |
| `prefix+alt+t` | ✋ blocked on them |
| `prefix+alt+d` | unblock — clears slot 2, keeps priority |
| `prefix+alt+x` | clear both |
| `prefix+alt+s` | **resync** — rebuild tokens from marks |

`alt+<letter>` chords were chosen because `alt+1..9` is `focus_agent` and
`shift+1..9` is `switch_workspace`.

### Why resync exists

**The tab name persists across restarts; the tokens do not.** herdr writes tab
`custom_name` into `session.json`, but pane metadata is display-only and never
hits disk. So after a restart a tab still reads 🔴 while its sidebar color is
gone.

That's why the emoji marks are the **source of truth** and `herdr-tag-tab resync`
walks every tab and rebuilds all tokens from them. Press `alt+s` after a restart,
or wire it to a Claude `SessionStart` hook to self-heal.

> Custom hooks go in a file *beside* `~/.claude/hooks/herdr-agent-state.sh`,
> never inside it — herdr overwrites that file on every integration update.

### Why tabs can't just be colored

There is no per-tab color in herdr 0.9.0. Every tab key is behavioral
(`tab_bar_position`, `tab_bar_right`, …) and theme colors are global. The reason
is structural: **metadata attaches to panes and spaces, never tabs** — `TabInfo`
carries only label, number, pane_count, agent_status, so there's nothing for a
rule to key off. Hence emoji in the name, which is the one thing that renders in
the tab row.

---

## Keeping repos current

`bin/git-sync-src.sh` sweeps every repo under `~/src`.

```sh
git-sync-src.sh          # fetch only — never touches a working tree
git-sync-src.sh --ff     # also fast-forward the default branch, behind guards
```

**Fetch-only is usually all you need.** `EnterWorktree` branches from
`origin/<default-branch>`, so only the *remote-tracking ref* must be current.
Your local `main` being stale changes nothing, and fetch never moves HEAD — safe
to run while agents are mid-edit.

`--ff` fast-forwards only when all three guards pass: the default branch is
checked out, there are no tracked modifications, and there are no local commits
the remote lacks. Anything failing a guard is fetched and left alone. Linked
worktrees are skipped — fetching the parent already refreshes their refs.

Known snag: an **untracked** file that later became tracked upstream aborts the
merge (`would be overwritten by merge`). Diff it against the remote first; if
identical, set it aside with `git stash push -u -- <path>` and re-run.

---

## Manual steps

**1. The global worktree instruction — do not skip this.**

Paste `claude/CLAUDE-worktree-block.md` into `~/.claude/CLAUDE.md`. Claude's
permission classifier blocks an agent from editing that file, so it can't be
automated.

It is load-bearing. `EnterWorktree` only fires when the user says "worktree" **or
CLAUDE.md/memory directs it** — so without this block, agents don't isolate, and
sibling tabs in one space share a working tree and overwrite each other. The
wording is an unconditional imperative on purpose; "prefer" or "consider" won't
reliably clear the gate. It triggers on the first **write**, not on reads, so
read-only sessions don't litter `.claude/worktrees/` with unused branches.

**2. Optional** — the per-project memory in `claude/`, if you'd rather scope that
instruction per repo than globally.

**3. Optional** — the LaunchAgent in `launchd/` for hourly fetching.

---

## Gotchas worth keeping

- **Never bulk-create spaces in a loop.** Creating ~30 at once raced herdr's pane
  registry: shells exited with code 1 and the server logged `PaneDied for unknown
  pane`, taking most of the new spaces *and* two pre-existing ones with them.
  Create them one at a time, or just `prefix+shift+n` when you first open a repo.
- **Never let a second herdr binary sit earlier in `PATH`** than the managed one.
  After an upgrade you get a 0.8.0 client against a 0.9.0 server —
  `compatible: no`, protocol 19 vs 22, and every `herdr` command fails.
- **`herdr update` refuses to run inside a herdr session.** Detach first
  (`prefix+q`). On a Homebrew install, use `brew upgrade herdr` instead — the
  self-updater can't replace a Cellar-linked binary, and its "Update installed ·
  Restart to update" banner can appear with nothing actually downloaded.
- **`workspace close` on a primary space with open worktree spaces needs
  `--group`** as of 0.9.0.
- **Two update channels disagree.** Homebrew's formula and herdr's own updater
  can be several versions apart. Pick one and stay on it.
- `herdr --skill` prints an agent-facing guide for driving panes/agents/spaces
  over the CLI. `herdr api schema --json` is the authoritative socket API.

---

## The R&D space (`~/src/rnd`)

Repo-scoped spaces have nowhere to put work that isn't about one repo, so
research scatters. Measured before building this: **83 memories across 9
project namespaces** (backend 28, uniform 16, data-eng-workflows 11,
baker-bot 10, substreams 8 …) with no consolidation path between them.

`~/src/rnd` is a **notes repo** with its own herdr space. `inbox.md` takes raw
capture, `topics/<slug>.md` holds the durable subjects, `decisions/` is an
append-only log, `roadmap/<quarter>.md` is intent. Its `CLAUDE.md` holds the
filing rules — chiefly *append to an existing topic rather than create a
near-duplicate*, and *every claim carries provenance*.

**Its `CLAUDE.md` deliberately overrides the global worktree rule.** In a notes
repo a worktree would hide new notes on an unmerged branch, which is exactly
the scattering the repo exists to prevent.

### Two mechanisms feed it

**At write time** — the block in `claude/CLAUDE-rnd-capture-block.md` tells any
session, in any repo, to append a durable cross-cutting finding to
`~/src/rnd/inbox.md` with its source repo and session id.

**After the fact** — `rnd-harvest` walks every `~/.claude/projects/*/memory/`
namespace and emits one digest with a triage checklist. `rnd-weekly` runs the
harvest, hands it to `claude -p` in the repo to file into topics, then commits.

```sh
rnd-harvest                    # what isn't yet referenced in ~/src/rnd
rnd-harvest --orphans          # only the at-risk worktree namespaces
rnd-harvest --since 2026-09-01
rnd-weekly --dry               # harvest only, print the digest path
```

### Why `--orphans` matters

A session running **inside a git worktree** gets its own project namespace —
`-Users-blairmason-src-backend--claude-worktrees-dp-166-chain-completeness` and
friends. Any memory saved there is **orphaned when the worktree is removed**.
That is a direct consequence of the worktree isolation this setup encourages,
so the harvest flags those namespaces first and the digest says to file them
before anything else.

### Scheduling notes

The weekly pass is a **LaunchAgent**, not a Claude cron job or a cloud routine:
`CronCreate` jobs are session-only and expire after 7 days, and cloud routines
can't read `~/.claude/projects/` on this machine. The plist sets an explicit
`PATH` because launchd's default is minimal and wouldn't find `claude` or `git`.

---

## The `new_cwd` trap

`terminal.new_cwd` defaults to `"follow"`: a new tab inherits the **source
pane's current directory**, not the space's identity. That quietly breaks the
repo-grouping model, because agents following the worktree rule cd into
`.claude/worktrees/<name>/`. Branch a tab off one of those and it inherits the
worktree; the next tab inherits that. It compounds.

The damage isn't cosmetic. **A tab born inside a worktree gets its own Claude
project namespace** — `-…backend--claude-worktrees-<name>` — so everything it
learns is orphaned when the worktree is removed. This is the mechanism behind
the orphan namespaces `rnd-harvest --orphans` reports; it was the default path,
not an edge case.

A second drift compounds it: a space's own `identity_cwd` can be wrong. On this
machine `wJ` (backend) recorded `/Users/blairmason`, because herdr was launched
from `$HOME` and `wJ` was the original space — so even "follow the workspace"
gave home. There is no CLI to correct it; `herdr workspace` has no cwd command,
and recreating the space costs you its tabs.

`bin/herdr-new-tab` routes around both. It resolves the focused space's repo
root as the majority `git --git-common-dir` across its panes — and from inside
a linked worktree that points at the **main checkout's** `.git`, so it lands on
the repo even when most panes have drifted. It's bound to `prefix+c`, taking
over the muscle-memory key; the builtin follow-the-cwd behaviour moves to
`prefix+shift+c` for when you deliberately want a tab beside an agent inside
its worktree.
