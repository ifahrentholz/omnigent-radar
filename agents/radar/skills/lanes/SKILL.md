---
name: lanes
description: radar's routing procedure — the four lanes and how to classify into them, the menu of composable steps with their owners and outputs, the dispatch brief template with its report contract, and the one-line ask format. Load on the first turn of any task and whenever deciding what comes next.
---

# lanes — how radar routes

This is radar's operating procedure. It replaces the fixed pipeline of the
predecessor bundle: there are no stages and no gates, only a **menu of steps**
and **suggested chains** through them.

**The invariant that governs everything below: every step is an entry point and
every step is skippable.** A lane is what radar *proposes*, never what radar
*requires*.

## 1. Lanes

Classify every incoming request into the cheapest lane that fits, then propose
that lane in one line.

| Lane | Signals | Chain | State file? |
|---|---|---|---|
| **0 · chat** | A question, no imperative to change the repo: "wie funktioniert…", "wo liegt…", "warum…" | answer, or one `explore` | no |
| **1 · quick** | Scoped imperative change, no ticket, obviously small: bump a dep, fix a typo, add a null check in a named file | `implement` → `wrap?` | no |
| **2 · ticket** | A ticket reference is present (`#412`, an issue URL), or "setz das um" against known work | `implement` → `review` → `wrap` | no |
| **3 · feature** | New capability, no ticket yet, scope not yet pinned: "ich möchte X bauen" | `grill` → `spec` → `tickets` → then lane 2 per ticket | yes |

**When the lane is ambiguous, propose the CHEAPER one.** Escalating mid-task
costs the human one word ("mach draus ein Feature"); running ceremony that was
never needed costs a spec, a ticket, and twenty minutes. Cheap-by-default is the
whole design.

Two things are *not* lanes and can be requested at any time: `onboard` (see the
`onboard` skill) and `learn` (see the `learn` skill).

## 2. The step menu

| Step | Worker | `purpose` | Braucht | Liefert | Default-next |
|---|---|---|---|---|---|
| `onboard` | 4× `explorer`, parallel | explore | — | `.omnigent/project/*` | — |
| `explore` | `explorer` | explore | a question | findings report | — |
| `grill` | **radar itself** | — | a rough idea | sharpened problem + scope | `spec` |
| `spec` | **radar itself** | — | a sharpened problem | `docs/specs/<slug>.md` with `AC-1…n` | `tickets` |
| `tickets` | `ticketer` | implement | a spec | issue URLs, in dependency order | `implement` |
| `implement` | `coder` | implement | a ticket **or** a plain instruction | branch, diff, gates run | `review` |
| `design` | `designer` | implement | existing UI, explicit opt-in | presentation-only diff | `review` |
| `review` | `reviewer` | review | a diff + its acceptance criteria | findings vs criteria, gates re-run | `wrap` |
| `wrap` | `scribe` | implement | a branch | commit message, MR/PR opened | `learn?` |
| `learn` | **radar itself** | — | a correction or a re-run | one line in `.omnigent/learnings.md` | — |

`grill`, `spec` and `learn` stay with radar because they are conversations with
the human — a sub-agent runs autonomously and reports back through the inbox, so
it cannot hold a dialogue. Everything else is delegated, always.

**`design` is opt-in and stays unused by default.** Dispatch it only on an
explicit yes. Never infer it from a ticket that merely sounds visual.

## 3. The ask format

After every completed step: one line of result, one line proposing the next.
Then stop.

```
✓ implement → branch feature/412-login, 4 Dateien, gates grün (coder)
  review anhängen? [⏎ ja / nein / direkt wrap]
```

Rules:
- **One decision per message.** If two things are open, ask the blocking one.
- **A default marked `[⏎ …]`.** Bare Enter must be a valid, sensible answer.
- **Mirror the human's language.** They write German, you answer German.
- **Never ask what `.omnigent/project/` answers.** That file set exists to
  retire questions permanently.
- **Batch-ahead overrides all of this.** On "mach durch bis MR" / "alles" /
  "ohne Rückfragen", run the chain and surface only: spec approval, a blocked
  step, a failed worker, and the lane's end.
- **A declined step is not re-offered** in that lane.

### A fanout is ONE step

When a step dispatches several workers at once (`onboard` runs four), you report
when the LAST of them is in — never as each one lands. An inbox wake from one
worker of a running fanout is **not** a step completion: read the inbox, keep
the result, and **end the turn without saying anything**.

This is not a style preference. On the first real run radar sent three separate
messages during the onboarding fanout — "✓ architecture.md steht. 3 Explorer
laufen noch." — three full turns of status nobody could act on. One of them even
promised "ich melde mich, wenn alle vier durch sind" and then reported again
immediately. Intermediate progress is not information; it is the chattiness this
bundle exists to avoid.

The only reason to break silence mid-fanout is a worker that came back `failed`
or `blocked` in a way that changes what the human should do next.

## 4. Dispatch brief template

Never freehand a brief. Every `sys_session_send` carries exactly this shape:

```
## Task
<one paragraph, imperative>

## Context
<PATHS, never file contents — the worker has the repo>
Projektwissen: .omnigent/project/INDEX.md
Ticket: <URL or ->
Spec: <path or ->

## Acceptance
<AC-1 … AC-n, or the ticket's criteria verbatim, or "none stated">

## Out of scope
<what not to touch>

## Return
Schreib deinen vollen Report nach `.omnigent/runs/<run-id>/report.md`.
Gib mir HÖCHSTENS 8 Zeilen zurück, genau diese Felder:
  result:  done | blocked | failed
  summary: <ein Satz>
  changed: <file:line, …> | -
  gates:   <command → pass/fail>, … | -
  branch:  <name> | -
  url:     <PR/MR/Issue-URL> | -
  next:    <was ein Folgeschritt bräuchte> | -
  report:  .omnigent/runs/<run-id>/report.md
Keine Prosa außerhalb dieser Felder.
Arbeite still: keine Zwischenkommentare zwischen Tool-Calls. Deine GESAMTE
Ausgabe landet im Kontext des Orchestrators, nicht nur die letzte Nachricht —
gib Text genau einmal aus, am Ende, in genau diesem Format.
```

**One exception: the `reviewer`.** Its environment denies every write, so it
cannot produce a report file — and its findings are exactly what radar needs in
order to route them. It returns the three buckets and the verdict inline, and
nothing else. Every other worker writes the file and returns the eight lines.

**The Return block is not optional and not paraphrasable.** It is the single
largest lever on cost in this bundle: without it a worker returns its full
reasoning into radar's context, and radar carries that weight for the rest of
the session. `<run-id>` is `<step>-<ticket-or-slug>`, e.g. `implement-412`.

**Context is paths, not contents.** The worker can read the repo. Pasting file
contents into a brief pays for the same bytes twice.

## 5. Per-worker notes

- **`coder`** — the only agent that writes product code, and it writes the tests
  for its change. It runs the gates from `.omnigent/project/commands.md` and
  reports them. It does *not* review itself and does *not* open the MR — `wrap`
  owns that, so the MR text is written from the finished diff.

- **`reviewer`** — give it the **branch, the diff and the acceptance criteria,
  and nothing else**. It needs the branch to re-run the gates; what it must
  never receive is the coder's report, summary or reasoning. Independence here
  comes from context isolation, not from a different vendor: a reviewer that can
  see *why* the implementer did something starts agreeing with it, and then
  reviews the intention instead of the code. Its gate re-run *is* the
  verification step in this bundle — the only one.

- **`explorer`** — read-only. Use for anything you are tempted to go look up
  yourself. Fan out several in parallel over disjoint questions rather than
  sending one broad question.

- **`ticketer`** — breaks a spec into vertical slices in dependency order, not
  one catch-all issue. Reads `.omnigent/project/vcs.md` for tracker, labels and
  templates.

- **`scribe`** — commit message, MR/PR description, ADRs, release notes. Follows
  the commit convention recorded in `vcs.md`.

- **`designer`** — presentation only: styling, layout, typography. Never logic,
  never user flow. Onto an existing branch.

## 6. State — lane 3 only

Lanes 0–2 are stateless; they live entirely in the conversation. Only a lane-3
feature needs `.omnigent/state.json`, because it outlives a session:

```json
{"tasks": [{
  "slug": "login",
  "spec": "docs/specs/login.md",
  "spec_approved": {"by": "ingo", "at": "2026-09-09"},
  "design": false,
  "tickets": ["<url>", "..."],
  "active": "<url>",
  "done": ["<url>"]
}]}
```

Read only the active task, never the whole file:
`jq '.tasks[] | select(.active != null)' .omnigent/state.json`.
When every ticket is in `done`, move the task to `.omnigent/archive.json`.

Do **not** create this file for lanes 0–2. A quick fix that leaves state behind
is the rigidity this bundle exists to avoid.

## 7. Run artifacts

`.omnigent/runs/<run-id>/report.md` — one per dispatch, written by the worker.
Link them, never quote them. They are gitignored; only `project/`,
`learnings.md` and `state.json` are committed.
