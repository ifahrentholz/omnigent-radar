---
name: radar-parallel
description: The parallel-mode procedure — how radar runs several implement tasks at once, each in its own git worktree with its own confinement policy. Load on the first turn of any task when .omnigent/mode says parallel, and whenever deciding whether a set of tickets can run together.
---

# parallel — several tickets at once

This skill applies **only when `.omnigent/mode` contains `parallel`**. In
single mode (the default, and the absence of the file) none of it is in force
and `radar-lanes` governs alone.

Parallel mode changes exactly one step: **`implement`**. Lanes, classification,
the ask format, the report contract, `grill`, `spec`, `tickets`, `review`,
`deliver` and `learn` are unchanged. It is not a different bundle; it is one
step that can now run more than once at a time.

## 1. What it costs, and when to say so

Parallel mode **loses the diff annotations**. A coder's work lives in a git
worktree; Omnigent's changed-files view reads `git status` in the repository
root, and git does not look inside a nested worktree. So there is nothing to
annotate and nothing to send back — the review → annotate → fix loop that makes
single mode worth using is not available here.

Say this ONCE, the first time a parallel dispatch is actually on the table in a
session, in the same line that proposes it:

    3 Tickets parallel — je ein Worktree, keine Diff-Annotationen.
    [ja / nacheinander]

Never repeat it, and never argue for a mode the human did not pick. `--single`
is one word away and they know it.

## 2. When NOT to fan out

Parallelism is only safe for tasks that do not touch the same code. You cannot
verify that cheaply, so use what you have and be honest about the rest:

- **A dependency order in the ticket set is binding.** `ticketer` produces
  issues in dependency order for exactly this reason. Tickets that depend on
  each other run in sequence, always.
- **Obvious file overlap** — two tickets naming the same module — runs in
  sequence.
- **Everything else may run together**, and when you are unsure, say which
  pair you were unsure about instead of silently serialising.

Conflicts do not surface here. Each task delivers its own branch and MR, so
they surface when the human merges — which is the same bargain every
feature-branch workflow makes.

**The per-turn dispatch cap is 6.** More tasks than that run in waves: dispatch
a batch, let it come back, dispatch the next.

## 3. Cutting a task

One command per task, run from the repository root:

```
radar-task.sh new <task-id> [--base <ref>] [--branch <name>]
```

`<task-id>` is the ticket number or the slug — `412`, `login`. It becomes the
worktree directory, the config directory and, by default, the branch
`radar/<task-id>`. Pass `--branch` when `.omnigent/project/vcs.md` names a
different convention; that file is the authority, not the default.

It prints one line: `task=… worktree=… branch=… config=… status=created|reused`.
Take the `worktree` and `config` values from that line and use them verbatim —
do not reconstruct the paths yourself.

The script cuts the worktree, renders the per-task coder config, and keeps the
running tasks out of `git status` so the changed-files view stays readable.
`reused`
means the task already existed and only its config was re-rendered.

## 4. Dispatching the coder

```
sys_session_create(
  config_path = "<the config path the script printed>",
  title       = "implement-<task-id>",
  message     = "<the brief>"
)
```

**`sys_session_create`, not `sys_session_send`, and the reason is not the
working directory.** Every worker in this bundle runs in the repository root no
matter what its config says — measured, and not changeable. What a rendered
per-task config buys is a **guardrail policy naming that task's worktree**, and
`guardrails` is per-spec. A `tools.agents` dispatch would put every task in one
unconfined checkout.

Record the `conversation_id` it returns. That is how you drive or cancel that
task later (`sys_session_send` with `session_id`, `sys_cancel_task` with
`task_id`).

In single mode `sys_session_create` is **not** used at all. It exists in the
tool list for this step and nothing else.

### The brief, and the one line that changes

Use the dispatch brief template from `radar-lanes` §4 unchanged, with one
addition at the top of `## Context`:

```
Worktree: <worktree path> — ALLE Schreibpfade beginnen damit, relativ.
Branch:   <branch> — bereits ausgecheckt, nicht neu anlegen.
```

Everything else about the brief is the same **except the report path**. The
template sends the run report to `.omnigent/runs/<run-id>/report.md`, which is
relative to the repository root — outside the coder's confinement, so that write
is denied. In parallel mode the Return block names

```
<worktree>/.omnigent-run-report.md
```

instead, and you link and read it from there. A coder that reports a denied
write is a brief that still had the old path in it.

## 5. Reporting a wave

**A fanout is ONE step** — the rule in `radar-lanes` §3 holds here and matters
more. You report when the LAST task of the wave is in, not as each lands. An
inbox wake from one task of a running wave is not a step completion: read the
inbox, keep the result, end the turn silently.

The exception is unchanged: a task that came back `failed` or `blocked` in a
way that changes what the human should do next breaks the silence immediately.

When the wave is in, one block per task, and the content budget from radar's
prompt applies across the whole message — not per task:

```markdown
**✓ implement ×3**

- `412` → `radar/412` · 4 Dateien · Gates grün (laut coder)
- `413` → `radar/413` · 2 Dateien · Gates grün (laut coder)
- `414` → **blocked** — Migration fehlt, siehe `next`

**review für 412 und 413?**

[ja / erst 412 / alles liegen lassen]
```

Over eight items, keep the blocked and failed ones and end with
`- +N weitere → <report>`.

## 6. review and deliver, per task

Both are ordinary `sys_session_send` dispatches to the shared `reviewer` and
`scribe`. Neither needs a rendered config: the reviewer writes nothing, and the
scribe's job is to push.

The one thing both briefs must carry is the worktree:

```
Worktree: <worktree path> — der Diff liegt dort, nicht im Hauptcheckout.
```

The reviewer re-runs the project's gates, so it needs to run them inside the
worktree (`cd <worktree> && <gate>`). Say that in the brief; it has no
confinement policy and will otherwise run them against the main checkout and
report a green that means nothing.

The reviewer's risk map has nowhere to land in parallel mode. Do not promise
annotations, and do not pass a `Session:` line — render every finding in the
message instead, exactly as `radar-lanes` §3 describes. That rendering is the
whole review surface here.

## 7. Tearing a task down

```
radar-task.sh teardown <task-id> --check    # verdict only, changes nothing
radar-task.sh teardown <task-id>            # removes, or refuses
```

The refusal is the point. Without `--check` the script exits 3 and changes
nothing when the tree is dirty, when the branch holds commits that are on no
remote (or, in a repository with no remote, on no default branch), or when it
cannot establish either. **`unverifiable` refuses** — "I could not check" must
never read as "safe".

Never work around a refusal. Report it to the human as a finding, with the
verdict verbatim, and let them decide.

Tear down only after `deliver` has run for that task. A task whose MR is open
is done; its branch is on the remote and the worktree is disposable.

## 8. Where things stand, when you do not know

`radar-task.sh list` reads git, not a record. It is the answer to "what is
actually running", including after a session died:

```
task=412 branch=radar/412 dirty=4 unlanded_commits=0 config=.omnigent/tasks/412
```

`dirty` is uncommitted files, `unlanded_commits` is what would be lost. Use it
on session start in parallel mode before you infer anything about a task, and
prefer it over `.omnigent/state.json`, which records intent rather than fact.
