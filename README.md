# workbench — herdr layout

A personal [herdr](https://herdr.dev) setup for running many concurrent coding
agents in one terminal. Config, two helper scripts, and an installer.

```sh
sh install.sh --check   # dry run
sh install.sh           # install
```

Portable by design: no absolute paths, no assumed directory names, nothing tied
to any particular repo. Set `BIN_DIR` to put the helper scripts somewhere other
than `~/.local/bin`.

---

## Hotkeys

`prefix` is **`ctrl+b`** by default. These are two-step chords: press `ctrl+b`,
**release**, then press the next key. Where a chord shows a modifier, that
modifier is held with the *second* key — `prefix+alt+f` is `ctrl+b`, then
`alt+f`.

### Tab status and priority

Two independent slots, written as emoji at the front of the tab name:

| Slot | Marks |
|---|---|
| 1 — focus or priority | ⭐ focus · 🔴 p0 · 🟡 p1 · ⚪ p2 |
| 2 — blocked on | 👀 review · ✋ someone else |

They compose, so `⭐👀 add-search-index` is the current focus, blocked on a
review.

**One chord: `prefix+alt+l`.** It opens a popup showing the tab's current
labels and a multi-select list. Pick one priority, one blocker, either,
or both — **`space` or `tab` marks an item ✓**, `enter` applies, `esc`
cancels.

> fzf binds only `Tab` to toggle by default, so `space` is bound explicitly.
> Without that the list looks single-select: pressing space does nothing
> visible and `enter` applies just the highlighted row. That's the
whole interface; there is nothing else to memorise.

**Three chords, one family — `prefix+alt+<mnemonic>`:**

| | |
|---|---|
| `prefix+alt+l` | **l**abel the focused tab (multi-select popup) |
| `prefix+alt+t` | new **t**ab — name, agent, labels, ready to talk to |
| `prefix+alt+s` | new **s**pace, pick a repo, at its root |
| `prefix+alt+j` | **j**ump to a tab by what it means, not its index |

Resync lives inside the label popup as its last entry, so it needs no chord of
its own.

Selecting two options from the same slot keeps the first. Selecting ⭐ moves
the star off whatever held it, demoting that tab to p0. The list also carries
*clear priority* and *clear blocked* entries, so unsetting is the same gesture
as setting.

It uses fzf when installed, and falls back to a numbered menu (enter
comma-separated numbers) when not.

Under the hood each chord runs `herdr-tag-tab`, which renames the focused tab
*and* sets matching `$focus` / `$p` / `$blocked` metadata tokens on its panes,
so the tab row and the sidebar agree. You can call it directly, including with
an arbitrary emoji:

```sh
herdr-tag-tab                # same popup picker, from a shell
herdr-tag-tab focus | p0 | p1 | p2 | review | them | unblock | clear | resync
herdr-tag-tab 🚀             # arbitrary mark, no token change
```

Every option remains reachable by name, so scripts and muscle memory both
work; there just isn't a chord per option to remember.

### Navigation and tabs

| Chord | Effect |
|---|---|
| `prefix+alt+t` | new tab **at the space's repo root** (see below) |
| `prefix+shift+c` | new tab following the current directory (herdr's builtin) |
| `prefix+a` / `prefix+shift+a` | next / previous agent |
| `prefix+alt+1..9` | jump straight to agent N |
| `prefix+shift+1..9` | switch to space N |
| `prefix+alt+s` | **new space** for a repo, anchored at its root (picker) |
| `prefix+shift+n` | new space following the current directory (herdr's builtin) |
| `prefix+w` | space picker — the real navigation past nine spaces |
| `prefix+q` | detach, leaving everything running |
| `prefix+?` | herdr's own help, listing bindings from the running config |

`prefix+?` is authoritative; this table can drift, that can't.

---

## Jumping by meaning

herdr's indexed focus covers three things — tabs (`prefix+1..9`), workspaces
and agents — and all three select by **position**. At a few dozen sessions
"agent 7" is not a selector anyone can hold in their head, and there is no
indexed focus for panes or for anything custom.

`prefix+alt+j` selects by *state* instead. The list is ordered by how much each
tab wants you:

1. ⭐ the focus tab
2. anything herdr detects as blocked or waiting **on you**
3. your own p0 → p1 → p2
4. everything else, by detected status

Each row shows the marks, the space, the tab name, the agent's status and its
live task title. Selectors work headlessly too, and repeating one **cycles**
through matches rather than sticking on the first:

```sh
herdr-jump              # the picker
herdr-jump star         # the ⭐ tab
herdr-jump p0           # cycle p0 tabs
herdr-jump blocked      # cycle tabs blocked on anything
herdr-jump attention    # cycle agents herdr says are waiting
herdr-jump --list       # print the order, jump to nothing
```

Note the ranking deliberately puts **your** priority above herdr's detected
status for everything except genuinely-waiting agents: a detected `unknown`
says nothing, and must not outrank a tab you marked p0 yourself.

## The layout this config assumes

herdr's hierarchy is **session → workspace ("space") → tab → pane**. An agent
isn't an object in that tree — it's a process herdr *detects* inside a pane. So
herdr doesn't organise agents; it organises **directories**. Two agent panes
sharing a directory share a working tree, and herdr will not warn you.

This config takes one position on that:

| Layer | Holds | |
|---|---|---|
| **Space** | one per repo | what you switch between |
| **Tab** | one per conversation | what you switch inside a repo |
| **Worktree** | one per agent, made by the agent | what stops them colliding |

Branches stay **invisible to the layout**. You never make a space or tab per
branch, so the sidebar stays one row per repo no matter how many branches are
in flight.

The alternative is herdr's native grain: `herdr worktree create` makes a
worktree and its own space as one object, and `worktree remove` addresses it by
`workspace_id`. That's a perfectly good model — it just gives you a sidebar row
per branch, which is the thing this layout is avoiding. The cost of choosing
repo-grouping: a space's row shows no branch, and `herdr worktree remove` won't
manage agent-made worktrees.

---

## Config notes

Everything is in `config/herdr-config.toml.tmpl`. `__BIN__` is substituted at
install time. Validate an edit with `herdr config check`, apply it live with
`herdr server reload-config` — no restart needed.

**`ui.agent_panel_sort = "spaces"`** is the group-by-repo switch. The
alternative, `"priority"`, flattens every agent into one urgency queue — the
opposite of grouping. The jump keys work under both.

**Agent navigation ships unbound.** `next_agent`, `previous_agent`,
`focus_agent`, and `switch_workspace` are all empty by default, which hides the
main reason to run herdr: going straight to the agent that needs you.

**`ui.toast.delivery`** defaults to `"off"`, so an agent finishing or blocking
in a background space notifies nowhere. Set to `"system"` here.
`ui.sound.enabled` is off only because something else is expected to own
sounds; flip it if not.

**Restart behaviour.** `session.resume_agents_on_restore` brings agent panes
back as real resumed conversations rather than bare shells (it needs an
integration reporting a session ref — check `herdr integration status`).
`experimental.pane_history` additionally restores scrollback; without it you
get the conversation back above an empty terminal. Across a reboot you keep the
layout, tab names, directories and conversations — but no running process
survives, and herdr does not auto-start at login unless you add a launch agent.

### Value-based token colour

Sidebar rows colour a token by its **value** (herdr 0.9.0+):

```toml
{ token = "$p", fg = "#9399b2", rules = [
    { equals = "p0", fg = "#f38ba8", bold = true },
    { equals = "p1", fg = "#f9e2af" },
    { equals = "p2", fg = "#6c7086", dim = true },
] }
```

First matching rule wins; unspecified fields inherit. Max 16 rules per token.
String conditions: `equals`, `contains`, `starts_with`, plus `ignore_case`.
Numeric: `gt`, `lt`, strict.

> Priorities are stored as the strings `p0`/`p1`/`p2` and matched with `equals`
> rather than numeric `gt`/`lt`. Token values arrive as strings and it is
> unverified whether herdr coerces them; `equals` sidesteps the question.

These tokens carry only what herdr **cannot** detect. `state_icon` already
shows working / idle / blocked-on-you — don't duplicate it.

---

## Why `resync` exists

**Tab names persist across restarts; metadata tokens do not.** herdr writes tab
`custom_name` into its session file, but pane metadata is display-only and
never hits disk. After a restart a tab still reads 🔴 while its sidebar colour
is gone.

So the emoji marks are the **source of truth**, and `prefix+alt+s`
(`herdr-tag-tab resync`) walks every tab and rebuilds the tokens from them. It
can also be wired to a Claude `SessionStart` hook to self-heal.

> Put custom hooks in a file *beside* herdr's own `herdr-agent-state.sh`, never
> inside it — herdr overwrites that file on every integration update.

## Why tabs can't simply be coloured

There is no per-tab colour in herdr 0.9.0. Every tab-related key is behavioural
(`tab_bar_position`, `tab_bar_right`, …) and theme colours are global. The
reason is structural: **metadata attaches to panes and spaces, never tabs** —
a tab carries only label, number, pane count and agent status, so there is
nothing for a rule to key on. Hence emoji in the name, which is the one thing
that renders in the tab row itself.

## Why `prefix+shift+n` is rebound too

Same cause as `prefix+c`, higher stakes. A space created by the builtin takes
its directory from `new_cwd` — and that directory becomes the space's permanent
`identity_cwd`. There is no CLI to change it afterwards, so a space born in the
wrong place stays mislabelled unless you delete and recreate it, losing its
tabs.

`herdr-new-space` picks a repo and anchors the space at its root, labelled with
the repo's directory name. Candidates come from `$HERDR_REPO_ROOTS`
(colon-separated; defaults to whichever of `~/src ~/code ~/projects ~/dev
~/repos ~/work` exist), searched one and two levels down. **Linked worktrees are
excluded** — under this layout a worktree belongs to its repo's space, not one
of its own — and repos that already have a space are marked rather than hidden.

It's on `prefix+alt+s`, bound as a `popup` rather than a detached shell because
the picker needs a terminal. It uses fzf when present and a numbered menu otherwise.

```sh
herdr-new-space              # pick
herdr-new-space ~/code/thing # direct, no picker
herdr-new-space --list       # show candidates, create nothing
```

## The new-tab wizard

`prefix+alt+t` walks three prompts and leaves you in a working agent:

1. **name** — becomes the tab label (blank for herdr's default)
2. **agent** — which agent and model to start, or a plain shell
3. **labels** — the same multi-select as `prefix+alt+l`

Each is skippable with enter or esc, so hammering enter three times gives you
exactly the plain anchored tab you'd have got before.

**The new tab is created unfocused and focused only at the end**, so the popup
keeps the keyboard until you've finished every prompt. Labelling therefore
targets the tab by id (`herdr-tag-tab pick --tab <id>`) rather than acting on
whatever is focused.

`herdr agent start` requires the pane to be at an interactive shell prompt, and
a brand-new pane is not there yet — a login shell with heavy rc files can take
several seconds, and the server answers `agent_pane_busy` until it settles. The
wizard retries for up to 30s. Two traps worth knowing if you touch this code:
herdr reports errors as **JSON on stderr** with exit status 1, so a retry loop
that only reads stdout sees an empty string and gives up immediately; and the
readiness delay is real (observed 2–8s here), so a single attempt is a coin
flip.

The offered agents default to claude (opus / sonnet / default), codex, and a
plain shell. Override with `$HERDR_TAB_AGENTS` — entries separated by `;`,
each `display=kind` or `display=kind args`:

```sh
HERDR_TAB_AGENTS='claude opus=claude --model opus;grok=grok'
```

`herdr agent start` supports pi, claude, codex, gemini, cursor, devin, cline,
opencode, copilot, kimi, droid, amp, grok and more — `herdr agent start --help`
has the current list. A model alias like `opus`, `sonnet` or `fable` is passed
straight through to the agent's own CLI.

```sh
herdr-new-tab            # the wizard
herdr-new-tab --bare     # no prompts, just the anchored tab
herdr-new-tab --print    # show the resolved repo root
```

## Why new tab and new space are rebound

`terminal.new_cwd` defaults to `"follow"`: a new tab inherits the **source
pane's current directory**, not the space's identity. Once an agent has entered
a worktree, tabs branched from it inherit the worktree, and the next tab
inherits that. It compounds.

It isn't cosmetic. A tab born inside a worktree gets its own agent-memory
namespace keyed to that path, which is orphaned when the worktree is removed.

A second drift compounds it: a space's recorded `identity_cwd` can itself be
wrong — a space created before you `cd`'d into the repo keeps the directory
herdr was launched from. There is no CLI to correct it, and recreating the
space costs you its tabs.

`herdr-new-tab` routes around both. It resolves the focused space's repo root
as the majority `git --git-common-dir` across its panes; from inside a linked
worktree that points at the **main checkout's** `.git`, so it lands on the repo
even when most panes have drifted. It takes `prefix+alt+t`; the builtin keeps
`prefix+shift+c` for when you deliberately want a tab beside an agent inside
its worktree.

herdr's own defaults for these are `prefix+c` and `prefix+shift+n` — tmux's
`c`-for-create convention. They're left on `shift` variants here rather than
reused, so the three anchored commands can share one `prefix+alt+<mnemonic>`
shape and there's no bare letter to misremember.

```sh
herdr-new-tab            # new tab at the focused space's repo root
herdr-new-tab --print    # show the resolved root, create nothing
```

---

## Keeping worktrees off stale code

`EnterWorktree` cuts from `origin/<default-branch>` — the remote-tracking ref,
not your local branch. That ref only moves when something runs `git fetch`, so
an agent can silently branch from days-old code and only discover it at merge
time. Local `main` being behind is irrelevant; fetching is the whole fix.

That belongs in the instruction block (`claude/CLAUDE-worktree-block.md`), which
tells the agent to fetch immediately before entering the worktree. Freshness is
needed at exactly one moment, in exactly one repo — narrower and more reliable
than a scheduled job sweeping every repo, and it needs no daemon and no
assumptions about where your repos live.

A periodic `git fetch --all --prune` across your checkouts is still worth having
for other reasons — accurate `git status` in any pane, and fewer round trips
when you do branch — but it is not what makes agent worktrees current. Don't
rely on it for that.

## Gotchas

- **Don't bulk-create spaces in a loop.** Creating many at once can race
  herdr's pane registry: shells exit with status 1, the server logs `PaneDied
  for unknown pane`, and spaces vanish — including pre-existing ones. Create
  them one at a time.
- **Never let a second herdr binary sit earlier in `PATH`** than the managed
  one. After an upgrade you get an old client against a new server: protocol
  mismatch, and every command fails.
- **`herdr update` refuses to run inside a herdr session** — detach first. On a
  package-managed install, upgrade through the package manager instead; the
  self-updater can't replace a managed binary, and its "restart to update"
  banner can appear with nothing actually downloaded. If two update channels
  disagree on the latest version, pick one and stay on it.
- **As of 0.9.0, `workspace close` on a primary space with open worktree spaces
  needs `--group`.**
- `herdr --skill` prints an agent-facing guide for driving panes, agents and
  spaces over the CLI. `herdr api schema --json` is the authoritative socket
  API.
