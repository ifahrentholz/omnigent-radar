---
name: omnigent-platform
description: How pstack runs on Omnigent. Maps the Claude Code tools, built-in skills, provider dispatch, model sheet and transcript paths that pstack's skills assume onto this bundle. Load together with poteto-mode, and whenever a pstack skill names a Claude Code or Codex tool, a built-in skill, a provider route, the model sheet, or a path under ~/.claude.
---

# pstack on Omnigent

The pstack skills in this bundle are open-pstack's, unchanged. They were written for Claude Code and Codex. This skill is the one place that says what their Claude Code and Codex specifics mean here, the way open-pstack's `poteto-mode/references/codex-tools.md` does for Codex.

Precedence. On a question of tools, routes, models or paths, this skill wins over `provider-dispatch.md` and `codex-tools.md`. On everything else (playbooks, principles, verification standards, autonomy, reply style) the pstack skill governs and this skill adds nothing.

## Skill names

Every pstack skill is listed here as `poteto:<name>`. Always invoke the qualified name. An unqualified name resolves to a host skill first when one exists, and this machine's `~/.claude/skills/` ships its own `tdd` and `teach`.

- `pstack:<name>` and `/pstack:<name>` in a skill mean `poteto:<name>`.
- "The **how** skill", "`/deslop`" and the like mean `poteto:how`, `poteto:deslop`.
- Principle leaves are read by path, as poteto-mode says. The Skill tool result names the bundle's base directory; resolve `principle-*/SKILL.md` and every `references/` or `playbooks/` path against it.
- `plugin-dev:skill-development` does not exist here. For skill authoring, follow `playbooks/authoring-a-skill.md` and the conventions of the SKILL.md files beside it.

## Tools

| pstack / Claude Code | Omnigent |
|---|---|
| Read a file | `sys_os_read` |
| Create or overwrite a file | `sys_os_write` |
| Edit a file | `sys_os_edit` |
| Run a shell command, search, glob | `sys_os_shell` (`rg`, `grep`, `find`, `ls`, `git`) |
| Bash with `run_in_background`, a dev server, a watcher, a log tail | a terminal: `sys_terminal_launch` with the `shell` terminal, then `sys_terminal_send` / `sys_terminal_read`, and `sys_terminal_close` when done. `sys_os_shell` blocks until the command exits. |
| Dispatch a subagent (`Agent` / `Task`) | `sys_session_send` to the `claude` or `codex` worker. See **Dispatch**. |
| Dispatch N parallel subagents | N `sys_session_send` calls in the same turn |
| Wait for a subagent | End the turn. You are woken when a worker finishes. Call `sys_read_inbox` once per wake. |
| Inspect what a subagent did | `sys_session_get_history` on its `conversation_id` |
| Stop a subagent | `sys_session_close` |
| Todolist (`TodoWrite`) | A checklist file, see **Todolist** |
| `AskUserQuestion` | Ask in plain text, one decision, options in brackets. The human types a word; an empty message cannot be sent. |
| `Monitor`, `ScheduleWakeup`, `CronCreate`, the `loop` skill | `sys_timer_set` / `sys_timer_cancel` for a wake-up in this session, `sys_scheduled_task_*` for a recurring run. Never poll in a loop. |
| WebFetch / WebSearch | The web tools this session lists. Otherwise `curl` via `sys_os_shell`. |
| `CLAUDE.md`, `AGENTS.md` | Unchanged. The harness loads the project's instructions. |

## Built-in skills

pstack names three Claude Code built-ins. None of them works here as written.

- **`verify`** (UIs) does not exist in this environment at all, not even in plain Claude Code outside its VS Code extension.
- **`run`** (CLIs, TUIs) may be listed, but it assumes Claude Code's `Bash`, background tasks and `Monitor`, and this harness has none of them.
- **`loop`** assumes `ScheduleWakeup` and cron. Use the timer row above.

Wherever a pstack skill says "the driver skill (`run` for CLIs/TUIs, `verify` for UIs)":

1. Use the project's own verification skill: a `verify-<app>` skill under `.claude/skills/`, listed here as `verify-<app>`. That is what `poteto:create-verification-skill` generates, and it carries its own launch, doctor, drive, evidence and cleanup recipe.
2. If the project has none, drive the surface yourself with `sys_os_shell` and a terminal, held to the same proof standards, and say in the reply that no verification skill exists yet. Offer `poteto:create-verification-skill` once.
3. Never call a run that did not exercise the real surface a pass. pstack's rule ("inconclusive or wrong-surface is not a pass") holds unchanged.

`create-verification-skill` writes to `.claude/skills/verify-<app>/`. Keep that location: it is where this harness discovers project skills, and other agents in the project can use the skill too.

## Dispatch

This replaces `references/provider-dispatch.md` for routing. Its rules on ownership stay: the parent resolves every route, children never choose one, and a failed lane is never silently replaced.

### Workers

| Worker | Harness | Runs |
|---|---|---|
| `claude` | `claude-sdk` | Claude models. The pin is `claude-opus-5-5`; a dispatch names the model. |
| `codex` | `codex-native` | Codex models. The pin is `gpt-5.6-sol`. |

Workers cannot dispatch further. That matches pstack's lane agents, which may not spawn agents or start a pstack workflow.

### From descriptor to dispatch

A descriptor is `<provider>:<model>@<effort>`. Route it like this:

| Descriptor | `agent` | `args.model` | `args.reasoning_effort` |
|---|---|---|---|
| `claude:opus@<e>` | `claude` | `claude-opus-5-5` | `<e>` |
| `claude:fable@<e>` | `claude` | `claude-fable-5-1` | `<e>` |
| `codex:gpt-5.6-sol@<e>` | `codex` | `gpt-5.6-sol` | `<e>` |
| `codex:gpt-6.1-sol@<e>` (a pstack default) | `codex` | `gpt-5.6-sol` | `<e>` |
| `inherit-parent`, `auto` | `claude` | this session's model | omit |
| `grok:*` | not available. A named dropout. | | |

`claude` accepts `low medium high xhigh max`; `codex` also accepts `ultra`. `args.model` and `args.reasoning_effort` only apply when the send creates the session.

Every `sys_session_send` also sets:

- `title`: a task label, unique per lane (`arena-search-opus`, `bugfix-412-impl`). Reusing an `(agent, title)` pair continues that session. pstack wants a fresh subagent with consolidated scope instead of a chained follow-up, so a new attempt gets a new title.
- `args.input`: the complete brief. Task, grounding paths, access mode, and where the output goes.

### Access modes

- **`read-only`**: no worktree. The brief says, in its first line, that the lane modifies nothing.
- **`isolated-write`**: a worktree you create before the dispatch. Never route a writer into the primary checkout.

Every lane starts in the primary checkout; `sys_session_send` has no working-directory option. A writer therefore gets its worktree from you, the way open-pstack's parent prepares one before it launches a runner:

1. `git worktree add <repo>-worktrees/poteto-<title> -b poteto/<title> <base>` from the primary checkout, with `<repo>` its absolute path. `<base>` is the task branch, or the default branch when there is none yet.
2. The brief's first line names the absolute worktree path and says the lane works only there: every shell command starts with `cd <path> &&`, every file path is absolute under it, and its commits land on `poteto/<title>`.
3. When it reports, read the result from the branch (`git -C <path> log`, `git diff <base>...poteto/<title>`). You own integrating it: review the diff, then cherry-pick or merge onto the task branch.
4. Remove the worktree once its branch is integrated or abandoned (`git worktree remove <path>`). The branch ref survives. The Worktree cleanup playbook covers the rest.

If `git worktree add` fails (no repository, a dirty or missing base), that is a dropout, not a reason to write in place.

A newer Omnigent than 0.16.0 can create the worktree itself: its `sys_session_send` schema then lists a `worktree` property in `args`. When it does, pass `args.worktree: true` instead of steps 1 and 2. The lane then runs on an `omni/<title>-<id>` branch, which `git worktree list` shows.

### Output and evidence

There is no `pstack-runner` and no receipt file. The equivalents:

- **Output.** A lane's final message is its output. When a judge must read several candidates side by side, assign each lane an absolute path under `<primary checkout>/.omnigent/poteto/runs/<run-id>/` and have it write there.
- **Receipt.** Record each lane's `conversation_id`, model and effort in the run's notes. `sys_session_get_history` is the evidence of what it did.
- **Dropouts.** A worker that never starts (boot failure), errors, or returns nothing usable is a dropout. Record it and apply the calling skill's dropout policy. Do not substitute another model, do not retry on another provider, do not lower the effort.

### Fan-out

Start every independent lane of a phase in the same turn, then end the turn silently. Judge only when every lane of the phase has reported. A turn may start at most 8 dispatches; split a wider fan-out across turns and say so in the run's notes.

## Model sheet

This replaces `~/.claude/pstack-models.md`. `setup-pstack` is not part of this bundle, because it writes into `~/.claude/CLAUDE.md`, which every Claude session on the machine reads. Read the configured descriptor for a role from here.

```markdown
# pstack model configuration

feature, refactoring: claude:opus@xhigh
bug-fix: codex:gpt-5.6-sol@max
perf-issue: codex:gpt-5.6-sol@max
hillclimb: codex:gpt-5.6-sol@max
judgment and prose: claude:opus@max
hardest tasks: claude:opus@max
how explorer: claude:opus@high
how explainer: claude:opus@max
why investigators, synthesizer: inherit-parent
reflect tooling, judgment, divergent, synthesizer: inherit-parent
arena runners: claude:opus@max, codex:gpt-5.6-sol@max, claude:fable@max
arena cross-judge pool: claude:opus@max, codex:gpt-5.6-sol@max, claude:fable@max
swarm workers: claude:opus@high
architect runners: claude:opus@max, codex:gpt-5.6-sol@max, claude:fable@max
interrogate reviewers: claude:opus@max, codex:gpt-5.6-sol@max, claude:fable@max
```

Two departures from pstack's first-run sheet:

- **Sol is `gpt-5.6-sol`, not `gpt-6.1-sol`.** Codex rejects `gpt-6.1-sol` for a ChatGPT-account login (probed 2026-10-05); `gpt-5.6-sol` is on the account and is the previous Sol default that `provider-dispatch.md` still accepts unchanged. Where a pstack skill names `gpt-6.1-sol`, read `gpt-5.6-sol`.
- **Grok is not used here.** Its first-run roles moved to Opus (feature and refactoring, how explorer, swarm workers), and Fable took its seat in the three-lane panels. Where a pstack skill names a Grok default, read the role's line above instead.

## Todolist

pstack opens a todolist whose first items are the matched playbook's steps, verbatim. Here that list is a file: `.omnigent/poteto/<task-slug>/todo.md`, a Markdown checklist. Keep it current as you go; it is also what Session pickup and Pause safely read. Show it in your first reply of the task.

## Transcripts

Omnigent keeps conversations in its own store and the harness writes no `~/.claude/projects/<encoded-cwd>/*.jsonl` for these sessions. Where a pstack skill reads a transcript there (`recall`, `reflect`, `show-me-your-work`, `automate-me`, the Session pickup and Eval playbooks):

- A worker's transcript is `sys_session_get_history` on its `conversation_id`.
- This session's or an earlier Omnigent session's transcript is `omnigent session export --id <conversation_id> --output <path>` via `sys_os_shell`. `sys_session_list` and `sys_session_get_info` find the ids.
- `~/.claude/projects/` still holds the human's own Claude Code sessions. Search it as well when the skill asks for prior work, and say which store each finding came from.

## Paths

- **This bundle's scratch state** lives under `.omnigent/poteto/` in the project: todolists, run notes, candidate outputs, decision logs.
- **Never write** `.omnigent/state.json`, `.omnigent/learnings.md`, `.omnigent/runs/` or `.omnigent/project/`. They belong to another agent bundle (radar) that runs in the same projects and resumes work from them.
- **The Orchestrate store** stays at `~/.claude/orchestrate/<project-slug>/`, as the playbook says. It is outside the project, and nothing else reads it.
- **The installed plugin root** that pstack refers to (as in "`skills/poteto-mode/scripts/...` under the installed plugin") is the directory that holds `skills/`. The Skill tool reports a skill's own base directory, `<root>/skills/<name>`; the plugin root is two levels up from it.

## Scripts

pstack names its tools by short names (`orch`, `watch-pr`) or calls them by path as if they were executable. Here every script runs through its interpreter: Omnigent drops the executable bits when it unpacks the bundle, so a direct call fails with `Permission denied` (exit 126). These are the exact invocations, with `<root>` the plugin root from **Paths**:

| Tool | Invocation | Needs |
|---|---|---|
| `orch` | `bun <root>/skills/poteto-mode/scripts/orch/orch.ts <args>` | bun |
| `watch-pr` | `bun <root>/skills/poteto-mode/scripts/watch-pr/watch-pr <args>` (the launcher file inside the `watch-pr/` directory) | bun |
| `check-plan` | `node <root>/skills/poteto-mode/scripts/check-plan.mjs <plan.md>` | node |
| `worktree-audit.sh` | `bash <root>/skills/poteto-mode/scripts/worktree-audit.sh [repo]` | bash |
| `log.sh` | `bash <root>/skills/show-me-your-work/scripts/log.sh <args>` | bash |

Omnigent's host daemon keeps the `PATH` it started with, so a `bun` installed later is often missing from `sys_os_shell` even though the human's terminal has it. Before the first bun tool of a session, run `command -v bun || ls ~/.bun/bin/bun`. If only the second finds it, prefix every bun command with `PATH="$HOME/.bun/bin:$PATH"`. If neither finds `bun`, say so when a playbook calls for one of these tools and do the step by hand. Never skip it silently.

On first use the scripts install their dependencies into `poteto-mode/scripts/node_modules/`. `runner/pstack-runner` is not used here; the workers replace it. `runner/model-matrix.test.ts` fails in this bundle by design: it checks open-pstack's package layout, including the `setup-pstack` skill and agent files this bundle leaves out.
