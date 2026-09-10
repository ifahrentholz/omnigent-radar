---
name: implement
description: "Implement a piece of work from a spec, a ticket, or a plain instruction."
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

Create or switch to the task branch if your brief names one, but **do not
commit**. Leave your work in the working tree.

That is deliberate. Omnigent's changed-files view runs
`git status --porcelain` and shows **uncommitted** changes only — a committed
change is invisible to it. The human reviews and annotates the diff in that
view, so the moment you commit, you take the change away from them. `deliver`
commits at the end, once the diff is final and reviewed.

**Do not push. Do not open a PR or MR. Do not run a code review.** Those are
separate steps (`deliver` and `review`) with their own owners, and they run only if
the human asks for them. Your deliverable is a dirty working tree on the right
branch and an honest report of what you ran.
