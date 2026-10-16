---
name: radar-verify
description: "Prove a change on the real surface with the project's own verification skill: pick the mapped features the change touches, launch the app, health-check it, drive every entry point of those features the way a user would, keep the evidence, clean up, and give each feature one verdict."
---

# Verify a change on the real surface

The gates say the code compiles and the tests agree with themselves. This step
says what the app does when a user touches it. It drives the real surface —
the browser, the terminal, the HTTP endpoint — through the project's own
verification skill, and every verdict it returns points at evidence on disk.

You verify the working tree as it stands. `implement` leaves its change
uncommitted, so the change under test is `git diff` plus every untracked file,
on the branch your brief names.

## 1. Pin what is under test

- `git branch --show-current` must be the branch from your brief. If it is
  not, stop: `result: blocked`, and say which branch you found. Never switch
  branches yourself; that would carry or strand the human's uncommitted work.
- `git status --porcelain -uall` and `git diff --stat` give the changed paths.
  Compare them with the paths in your brief and say if they differ.

## 2. Find the harness

The project's verification skill lives at `.claude/skills/verify-<app>/` and
appears in your skill listing as `verify-<app>`. Your brief's `Projekt-Skill`
line names it when radar found one.

- **One skill** → load it. Its Launch, Doctor, Drive, Evidence and Cleanup
  sections govern how you run the app; this skill governs what you prove and
  how you report it.
- **Several** → take the one whose surface the change touches, and say which
  and why.
- **None** → do not write one; that is the `verify-setup` step, and the human
  chose not to run it. Drive the surface yourself, held to the proof standards
  below, and report `harness: ad hoc` so nobody mistakes a one-off for a
  maintained recipe. Read the project's own run instructions (README,
  package scripts, Makefile) for the launch command.

During this step the verification skill is read-only to you. A recipe that is
wrong, a selector that moved, a feature the map is missing, an acceptance
criterion no mapped feature covers: each is drift, and drift goes into `next:`
as its own item starting with `drift:`, never into an edit. radar reads that
prefix to decide when to propose `verify-maintain`, so do not use it for
anything else, and do not leave it off real drift.

## 3. Choose the features

Read the feature map's `features/README.md`, then select the features this
change can affect:

- **From the acceptance criteria.** Every criterion that describes behaviour a
  user can observe maps to at least one feature drive. A criterion no mapped
  feature covers is still driven, through the closest real user path, and the
  missing map entry is reported as drift.
- **From the changed paths.** A changed route, command, handler, view or
  migration selects the features that reach it. When you cannot tell from the
  map, read the source just far enough to trace the path from the user's entry
  point to the change.
- **Every entry point of a selected feature.** If the map lists the toolbar
  button, the keyboard shortcut and the CLI command, drive all three. A proof
  through one convenient entry point is incomplete when the map lists others.

If the change touches no user-facing surface at all — a refactor behind a
stable interface, a test-only change, build tooling — say so, launch nothing,
and return `result: n/a` with the reason. Driving an app the change cannot
affect costs the human time and proves nothing about the change.

## 4. Launch and doctor

Follow the verification skill's Launch section exactly, against disposable
state: a fresh data directory, a port nobody else owns. If its one-time driver
install has not run on this checkout (the skill ships a `package.json` but no
`node_modules/`, typically on a fresh clone), run it only with
`Freigegeben: Treiber-Abhängigkeiten installieren` in your brief, and from the
skill's lockfile; without that line, return `blocked: needs <exact command>`. Anything that keeps
running goes into a terminal (`sys_terminal_launch`), never behind `&` in
`sys_os_shell`.

**Ready means usable**, not that a process answers. A health endpoint can
answer while migrations or seed scripts are still running. Wait for the
signal the skill names, and wait for conditions, not fixed sleeps.

Run the skill's Doctor before the first drive, again after every failed drive,
and after anything surprising. Never drive an instance you have not
health-checked since it last surprised you. Where doctor cannot see a failure
— a wedged UI on a healthy process — reset to a known state or relaunch rather
than hoping.

A doctor failure caused by the skill itself (a moved command, a renamed port
variable) is drift: you may work around it once for this run if the correct
step is unambiguous, and you report the drift. A doctor failure you cannot get
past is `result: blocked` with the doctor output in the report.

## 5. Drive

For each selected feature, follow its `Driving it with …` recipe, entry point
by entry point:

- **Exercise the real user path.** Not an internal setter, not a test-only
  endpoint, not a unit test, not a direct database write standing in for a
  form submit. Mocks only where a production boundary already isolates the
  external system.
- **Capture the action and the resulting state**, not only the final screen.
- **Verify side effects** alongside what is visible: the file written, the row
  inserted, the message sent. A mutation needs a second, read-only view of the
  stored value.
- **Never weaken a journey to make it pass.** A missing precondition is a
  failure with its reason, or `unreachable` when the prerequisite is external
  (an account, an entitlement, an OS, a remote service).
- **A dry-run or test mode is verified by observation**, not by its name:
  check what it actually skipped (files, network, git refs). Some dry-runs
  still touch the network.

When a check fails, suspect the observation before the system: re-read the
recipe, check the selector, look at the raw output. Then triage:

| What you found | Verdict | Where it goes |
|---|---|---|
| The app misbehaves on the real path | `failed` | a product finding — blocks `deliver` |
| The recipe is wrong, the app is right when driven correctly | `verified` on the corrected path | drift, in `next:` |
| A prerequisite you cannot reach | `unreachable` | the prerequisite and the route you tried |
| You did not get to it | `not run` | the reason |

## 6. Evidence

Write evidence under `.omnigent/runs/<run-id>/evidence/<feature>/`, at the
relative path. If the verification skill exposes an evidence-root variable or
flag, point it there. If it only writes to a fixed location, copy the
artifacts into the run directory after the drive and name the original path.

What counts, following the project's own map where it is stricter:

- UI: an accessibility snapshot or DOM dump plus a screenshot with the app's
  identity visible.
- CLI/TUI: the exact command, stdout, stderr and exit code, or the terminal
  transcript.
- HTTP: the request, the status and the response body.
- Every artifact named after the feature ID and the entry point it proves.

## 7. Clean up

Follow the skill's Cleanup section. Stop exactly the processes and terminals
you started; never kill by name or port. Then list the evidence directory and
confirm every artifact you are about to cite still exists. A cleanup that ate
the proof turns every verdict that cited it into `not run`.

## 8. Report

Write the full report to `.omnigent/runs/<run-id>/report.md`:

- the harness used (`verify-<app>` or `ad hoc`) and the commit plus dirty-tree
  state you verified;
- per feature: the verdict, every entry point driven, what you observed, and
  the evidence paths;
- product findings, kept apart from harness and map drift;
- the disposable directories and ports you used, and anything you could not
  stop.

Then return exactly the block your brief's `Return` section asks for, nothing
else. The overall `result`:

- `fail` — at least one feature `failed`;
- `blocked` — you never got a usable instance;
- `n/a` — the change touches no user-facing surface;
- `partial` — nothing failed, but at least one feature is `unreachable` or
  `not run`. That part of the change is unproven, and the report says which;
- `pass` — every selected feature is `verified`. Nothing less.
