---
name: radar-parallel
description: How radar runs several implement tasks at once — one git worktree per task, dispatched to the ordinary coder. Load on the first turn when .omnigent/mode says parallel, and whenever deciding whether a set of tickets can run together.
---

# parallel — several tickets at once

Applies **only when `.omnigent/mode` contains `parallel`**. Missing file means
single mode, and none of this is in force.

Parallel mode changes exactly one step: **`implement`**. Lanes, classification,
the ask format, the report contract, `grill`, `spec`, `tickets`, `review`,
`deliver` and `learn` are unchanged — `radar-lanes` governs all of them here
exactly as it does in single mode.

**There is no separate machinery.** Same `coder`, same `sys_session_send`, same
brief template. The only difference is that several run at once and each is
pointed at a worktree of its own.

## 1. What it costs, and when to say so

Parallel mode **loses the diff annotations**. A coder's work lives in a git
worktree; Omnigent's changed-files view reads `git status` in the repository
root, and git does not look inside a nested worktree. So there is nothing to
annotate and nothing to send back.

Say this ONCE, the first time a parallel dispatch is actually on the table in a
session, in the same line that proposes it:

    3 Tickets parallel — je ein Worktree, keine Diff-Annotationen.
    [ja / nacheinander]

Never repeat it, and never argue for a mode the human did not pick.

## 2. When NOT to fan out

- **A dependency order in the ticket set is binding.** `ticketer` produces
  issues in dependency order for exactly that reason; dependent tickets run in
  sequence.
- **Obvious file overlap** — two tickets naming the same module — runs in
  sequence.
- **Everything else may run together.** When unsure, say which pair you were
  unsure about rather than silently serialising.

Conflicts do not surface here. Each task delivers its own branch and MR, so they
surface when the human merges.

**The per-turn dispatch cap is 6.** More tasks than that run in waves.

## 3. Cutting the worktrees and dispatching

Once, per repository — keeps the worktrees out of `git status`, which is what
the changed-files view reads:

```bash
grep -qxF 'worktrees/' .omnigent/.gitignore 2>/dev/null \
  || { mkdir -p .omnigent; echo 'worktrees/' >> .omnigent/.gitignore; }
```

Then per task, in the SAME turn, all of them before you end it:

```bash
git worktree add .omnigent/worktrees/<id> -b <branch>
```

`<id>` is the ticket number or slug. `<branch>` follows
`.omnigent/project/vcs.md` when it names a convention, else `radar/<id>`.

```
sys_session_send(agent="coder", title="implement-<id>",
                 args={purpose: "implement", input: "<the brief>"})
```

A distinct `title` is what makes these separate, concurrent sessions; reusing
one continues that task instead. Record each `conversation_id` — it is how you
drive or cancel that task later.

### The brief

The template in `radar-lanes` §4, unchanged, with two additions at the top of
`## Context` and one substitution:

```
Worktree: .omnigent/worktrees/<id> — dein Arbeitsverzeichnis ist der Repo-Root,
          also beginnt JEDER Pfad, den du schreibst, mit diesem Präfix.
          Gates: `cd .omnigent/worktrees/<id> && <gate>`.
Branch:   <branch> — bereits ausgecheckt, nicht neu anlegen.
```

The substitution is the report path: the `Return` block names
`.omnigent/worktrees/<id>/.omnigent-run-report.md`, so each task's report
travels with its worktree.

Nothing confines the coder to that worktree — it is a path prefix it has been
told to use, exactly as in Omnigent's own `polly` example. A coder that gets it
wrong writes into the main checkout, which `git status` shows and which is
recoverable. Guardrails were tried here and removed: see the PR that introduced
this mode.

## 4. Reporting a wave

**A fanout is ONE step** — the rule in `radar-lanes` §3, and it matters more
here. Report when the LAST task is in, never as each lands. An inbox wake from
one task of a running wave is not a step completion: read the inbox, keep the
result, end the turn without saying anything.

The exception is unchanged: a task that came back `failed` or `blocked` in a way
that changes what the human should do next breaks the silence immediately.

The content budget from radar's prompt applies across the whole message, not per
task:

```markdown
**✓ implement ×3**

- `412` → `radar/412` · 4 Dateien · Gates grün (laut coder)
- `413` → `radar/413` · 2 Dateien · Gates grün (laut coder)
- `414` → **blocked** — Migration fehlt, siehe `next`

**review für 412 und 413?**

[ja / erst 412 / alles liegen lassen]
```

## 5. review and deliver, per task

Ordinary dispatches to `reviewer` and `scribe`. Both briefs carry the same
`Worktree:` line, and the reviewer's must say the gates run inside it
(`cd .omnigent/worktrees/<id> && <gate>`) — it has nothing stopping it from
running them against the main checkout and reporting a green that means nothing.

The reviewer's risk map has nowhere to land: pass no `Session:` line, promise no
annotations, and render every finding in the message as `radar-lanes` §3
describes. That rendering is the whole review surface here.

## 6. Where things stand, and tearing down

```bash
git worktree list                                  # what is actually running
git -C .omnigent/worktrees/<id> status --porcelain # what one task has done
```

Read git, not `.omnigent/state.json` — state records intent, git records fact.
Use this on session start in parallel mode before inferring anything.

Tear a task's worktree down after `deliver`:

```bash
git worktree remove .omnigent/worktrees/<id>
```

**git's own refusal is the safety, and it is enough.** It exits non-zero on a
worktree holding modified or untracked files. A worktree whose work is committed
loses nothing when removed — the branch keeps the commits, and
`git worktree add .omnigent/worktrees/<id> <branch>` brings the directory back.
Never pass `--force`, and never work around a refusal: report it to the human
with git's message verbatim.
