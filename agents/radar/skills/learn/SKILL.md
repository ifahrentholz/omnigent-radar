---
name: learn
description: How radar records a lesson so it is not repeated — the two levels (project rule vs. bundle change), the strict line format, the hard size cap on `.omnigent/learnings.md`, and when consolidation is due. Load when the human corrects you, when a step had to be re-run, or when asked to record a learning.
---

# learn — recording a lesson without paying for it forever

`.omnigent/learnings.md` is loaded at the start of **every** session. That single
fact governs everything below: a learnings file that grows without bound is a
standing tax on every future turn, and the usual failure mode of these systems
is a long, fond log of past incidents that nobody reads and everybody pays for.

So: **it is a rule list, not a diary. Hard cap 40 lines.**

## Two levels — decide which before writing

**Project rule** → `.omnigent/learnings.md` in the target repo. Something true
about *this codebase*: "the e2e suite needs the docker compose stack up first",
"tickets labelled `bug` here never get a spec".

**Bundle change** → a prompt or skill edit in the radar bundle, committed there.
Something true about *the method*: radar asked two questions in one message, a
brief template was missing a field, a worker was routed the wrong kind of task.

Only the second is real self-improvement. Writing a method problem into a
project's learnings file fixes it in one repo and lets it recur in every other
one — and it silently spends that project's 40 lines on someone else's bug. When
the lesson is about the method, say so and propose the concrete edit; do not
quietly file it as a project rule.

## Format — one line, and it must be actionable

```
- 2026-09-09 · <trigger condition> → <do this instead>
```

The trigger comes first because that is what a future session matches against.
A line that does not begin with a recognisable situation cannot fire.

```
✓ - 2026-09-09 · e2e-Gate läuft → vorher `docker compose up -d db` starten, sonst rot
✓ - 2026-09-09 · Ticket mit Label `bug` → kein Spec-Step anbieten, direkt implement
✗ - 2026-09-09 · Der coder hatte Probleme mit den Tests        (no trigger, no action)
✗ - 2026-09-09 · Besser auf Sorgfalt achten                    (unfalsifiable)
```

If you cannot write the line in that shape, you have not understood the lesson
yet. Ask one question rather than filing a vague entry — a vague entry costs
tokens forever and changes nothing.

## When to write — and when not to

Write on exactly three triggers:

1. The human **corrects** you — about routing, a default, a convention.
2. A step had to be **re-run** for a reason that will recur.
3. The human says at the end of a lane that something went wrong.

Do **not** reflect after every step. Do not record successes. Do not record
one-offs — a lesson that will not fire again is pure cost. And never record
something already captured in `.omnigent/project/`: that file set is the place
for facts, this one is for corrections to behaviour.

Say in one line that you recorded it. Do not quote the entry back.

## Consolidation

When the file passes 40 lines, consolidate before appending: merge lines with
the same trigger, drop anything the project has since made moot, and promote
anything that has fired repeatedly into `.omnigent/project/` where it belongs as
a fact rather than a correction. Report what you dropped — silently discarding a
rule the human asked for is worse than the file being one line over.
