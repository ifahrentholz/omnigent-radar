# poteto

A second agent in this repository, independent of radar: Lauren Tan's
[pstack](https://github.com/cursor/plugins/tree/main/pstack), through
[open-pstack](https://github.com/ericlitman/open-pstack), running on Omnigent.

```bash
cd your-project
poteto
```

radar and poteto answer different questions. radar routes each request to the
cheapest chain of steps and lets you skip any of them. poteto is pstack's lead
engineer: it learns the system before changing it, compares designs, delegates
code to model lanes, proves the result on the real surface, and carries the
work to a pull request. Use whichever fits the task. Neither reads the other's
state.

## What runs

| | |
|---|---|
| **Orchestrator** | `poteto` on `claude-opus-5-5`. Its prompt routes non-trivial work into `poteto:poteto-mode`, which is what open-pstack's `SessionStart` hook does in Claude Code. |
| **Skills** | open-pstack's skill tree, vendored unchanged under `agents/poteto/skills/` and listed as `poteto:<name>`. |
| **Platform map** | `poteto:omnigent-platform`, the one skill poteto adds. It says what pstack's Claude Code tools, built-in skills, provider routes, model sheet and paths mean on Omnigent. |
| **`claude` lane** | `claude-sdk`. Opus or Sonnet 5.5, model and effort chosen per dispatch. Replaces the `pstack-<family>-<effort>` agents and `pstack-runner`. |

Every writing lane gets its own git worktree, which the lead creates with
`git worktree add` under `<repo>-worktrees/poteto-<title>` on a
`poteto/<title>` branch before it dispatches. The lead reviews each lane's diff,
integrates it, and removes the worktree. Omnigent 0.16.0 cannot create
sub-agent worktrees itself; a newer release that can is used automatically.

## The model sheet

pstack configures models per role with `setup-pstack`, which writes into
`~/.claude/CLAUDE.md`. That file is read by every Claude session on the
machine, radar's included, so the skill is left out and the sheet is static in
`agents/poteto/skills/omnigent-platform/SKILL.md`:

| Role | Lane |
|---|---|
| every single-lane role | `claude:opus@high` |
| why, reflect | `inherit-parent` |
| arena, architect, interrogate panels | `claude:opus@high`, `claude:sonnet@high` |

pstack spreads these roles over Opus, Codex's Sol and Grok, with three-lane
panels. poteto runs Claude only, to keep token use down: every single-lane role
is on Opus at `high`, and the panels have two lanes, Opus and Sonnet 5.5. Two is the
minimum `architect` accepts, and the second model keeps the diversity
`interrogate` relies on, at a fraction of Opus's cost. Codex, Grok and Fable
lanes are never dispatched.

Change a role by editing its line. Nothing else reads the sheet.

## Verification

pstack's playbooks drive the app through Claude Code's `run` (CLIs) and
`verify` (UIs) built-ins. Neither works here: `verify` does not exist outside
Claude Code's VS Code extension, and `run` relies on Claude Code tools the
Omnigent harness does not expose. poteto uses the project's own verification
skill instead. In a poteto session, type:

```text
/create-verification-skill
```

Slash commands carry the skill's bare name. The `poteto:` prefix only exists
in the skill listing the model sees, so `/poteto:create-verification-skill` is
an unknown command. Type `/` to see the 31 skills you can invoke this way; the
`principle-*` leaves are hidden, as in pstack. A slash command always runs the
bundle's skill, so `/tdd` and `/teach` reach pstack's even when
`~/.claude/skills/` has skills of the same name.

It writes `.claude/skills/verify-<app>/` into the project: how to launch the
app, check it is healthy, drive it like a user, capture evidence and clean up,
plus a feature map. poteto's playbooks use it from then on, and so can any
other agent working in that project, radar's reviewer included.
`poteto:maintain-verification-skill` keeps it honest as the app changes.

## What appears in your project

```
.omnigent/poteto/           # gitignore — todolists, run notes, lane outputs
.claude/skills/verify-<app>/  # commit — from create-verification-skill
```

poteto never writes radar's files (`.omnigent/state.json`, `learnings.md`,
`runs/`, `project/`).

## Known gaps

- **Transcripts.** Omnigent sessions write no `~/.claude/projects/*.jsonl`.
  `recall`, `reflect`, `show-me-your-work` and the Session pickup and Eval
  playbooks read transcripts through `omnigent session export` and
  `sys_session_get_history` instead.
- **Bun scripts.** `orch` and `watch-pr` need `bun`; `check-plan` runs on
  node. Omnigent's host daemon keeps the `PATH` it started with, so a `bun`
  installed afterwards is invisible to poteto until the daemon restarts
  (`omnigent stop`, then start again from a new terminal). poteto falls back
  to `~/.bun/bin/bun` on its own. Without any `bun`, the Orchestrate and
  Babysit playbooks do those steps by hand.
- **No nested lanes.** A lane cannot dispatch further. pstack's own lanes may
  not either, but its Orchestrate and Autopilot playbooks give phase owners
  their own fan-out, which poteto cannot yet do.

## Updating pstack

```bash
scripts/sync-pstack.sh          # open-pstack main
scripts/sync-pstack.sh <ref>    # a tag, branch or commit
```

Then read the diff. `agents/poteto/UPSTREAM.md` holds the pin, what is left out
and why.
