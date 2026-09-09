---
name: implement
description: "Implement a piece of work from a spec, a ticket, or a plain instruction."
disable-model-invocation: true
---

Implement the work described in your brief.

Use `/tdd` where possible, at pre-agreed seams.

Stay inside the scope the brief names. Do not refactor or wander unprompted — a
change nobody asked for is a change nobody reviewed.

Run the project's own gates, as recorded in `.omnigent/project/commands.md`:
typecheck and single test files regularly while you work, the full suite once at
the end. Report every gate you ran as `command → pass/fail`. If that file does
not exist, use what the repo tells you and say in your result that the gates
were guessed.

Commit to the current branch. Co-sign every commit you author: end the message
with a blank line, then this exact trailer as the final line —

    Co-authored-by: omnigent <noreply@omnigent.ai>

**Do not push. Do not open a PR or MR. Do not run a code review.** Those are
separate steps (`wrap` and `review`) with their own owners, and they run only if
the human asks for them. Your deliverable is a committed branch and an honest
report of what you ran.
