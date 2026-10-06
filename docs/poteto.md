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
| **`claude` lane** | `claude-sdk`. Opus or Fable, model and effort chosen per dispatch. Replaces the `pstack-opus-*` / `pstack-fable-*` agents. |
| **`codex` lane** | `codex-native`. `gpt-5.6-sol`, effort per dispatch. Replaces `pstack-runner` for Codex. |

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
| feature, refactoring | `claude:opus@xhigh` |
| bug-fix, perf-issue, hillclimb | `codex:gpt-5.6-sol@max` |
| judgment and prose, hardest tasks, how explainer | `claude:opus@max` |
| how explorer, swarm workers | `claude:opus@high` |
| why, reflect | `inherit-parent` |
| arena, architect, interrogate panels | `claude:opus@max`, `codex:gpt-5.6-sol@max`, `claude:fable@max` |

Two departures from pstack's defaults. Grok is not used: its roles went to
Opus, and Fable took its seat in the panels. And Sol is `gpt-5.6-sol`, because
Codex rejects pstack's `gpt-6.1-sol` for a ChatGPT-account login.

Change a role by editing its line. Nothing else reads the sheet.

## Verification

pstack's playbooks drive the app through Claude Code's `run` (CLIs) and
`verify` (UIs) built-ins. Neither works here: `verify` does not exist outside
Claude Code's VS Code extension, and `run` relies on Claude Code tools the
Omnigent harness does not expose. poteto uses the project's own verification
skill instead:

```text
poteto:create-verification-skill
```

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
