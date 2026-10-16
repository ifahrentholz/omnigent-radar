---
name: radar-create-verification-skill
description: "Generate a project-local verification skill (`.claude/skills/verify-<app>/`) that drives the app the way a user does — any language, framework or platform — seed its feature map, and prove it once end to end. The verify-setup step: use when a project has no scripted way to prove UI, CLI or service behaviour."
---

# Create a verification skill

Every serious project needs a scripted way to drive the real app and prove
behaviour: launch it, exercise a feature the way a user would, and capture
evidence. This skill generates that as a project-local skill,
`.claude/skills/verify-<app>/`, tailored to the repository. You write it for
the next agent, not for a human: it will be read cold, mid-task, by an agent
that has never seen the app — radar's `verify` step, a poteto playbook, or a
plain Claude Code session.

Adapted from open-pstack's `create-verification-skill` (see `UPSTREAM.md` in
the verifier's directory). What differs is how this bundle operates, not the
proof standard: you run headless, you never touch product code, and you leave
your work uncommitted for `deliver`.

**The generated skill belongs to the project, not to this bundle.** Name it
`verify-<app>`, without the `radar-` prefix, and keep it at
`.claude/skills/verify-<app>/`. That is where every harness on this machine
discovers project skills, so the one skill serves every agent that works here.

## 1. Interview the repo, not the human

You run headless: there is nobody to ask mid-run. Answer these from the
codebase:

- **Surface:** what does a user actually touch? A web UI, a CLI/TUI, a desktop
  app, an API, a mobile app, a library? A repo can have several; pick the
  primary one and note the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev
  command (package scripts, Makefile, README quickstart). Note ports, env vars,
  seed data, auth.
- **Drive:** how can an agent interact with it programmatically? Existing
  harnesses first — Playwright/Cypress specs, expect scripts, PTY helpers,
  curl-able endpoints, a debug port. Only then pick a generic recipe:
  browser/CDP for web and Electron, a tmux/PTY harness for CLI/TUI, plain HTTP
  for services.
- **Observe:** what evidence can be captured? Screenshots, terminal
  transcripts, response bodies, logs, exit codes, DB state.
- **Isolate:** can two instances run side by side (ports, data dirs,
  profiles)? If not, say so in the generated skill: refusing to double-drive a
  shared instance beats corrupting the human's session. The human's own dev
  server may already hold the default port.

What the code cannot answer — a test account, a licence key, which of two
surfaces matters — is not guessed. Choose the conservative option, write it
into the generated skill as an explicit assumption, and list it under `next:`.
If the missing answer blocks a launch (credentials, a paid service), stop
there: `result: blocked`, naming exactly what is needed.

**If the checkout does not build or start as-is, do not fix it.** A build fix
is product code, and product code belongs to `implement`. Report it precisely
— the command, the error, the file it points at — and return
`result: blocked`; a skill written against a broken base teaches wrong steps.
One exception, unchanged from upstream: when an irrelevant missing asset blocks
startup (a static directory the API never serves, a sample config), the
generated skill may create it, clearly marked as verification scaffolding, and
remove it in its own cleanup. That scaffolding lives in the skill's recipe,
not as a committed file in the product tree.

Installing dependencies, downloading a browser, pulling an image or any other
network step needs the human's approval in your brief. When the launch needs
one that was not approved, the generated skill still documents it, and you
return `blocked: needs <exact command>` instead of running it.

## 2. Generate the skill

Write `.claude/skills/verify-<app>/SKILL.md` with YAML frontmatter
(`name: verify-<app>` and a `description` that names the app, the surface, and
when to reach for it — without frontmatter the skill never registers) and these
sections, each grounded in what the interview actually found (no placeholders
left):

- **Launch:** the exact command that starts the app for verification, and how
  to tell it is ready (a log line, a prompt). Launch must reach a usable state
  from an empty data dir, including any migrations and seed data. Ready means
  usable, not just that a process answers: a database health check can pass
  while its init scripts are still running. Say which steps must stay running
  and therefore belong in a terminal rather than a blocking shell call.
  Include teardown. For a short-lived CLI or TUI there is no server to keep
  alive: launch means build the binary (or install deps) once, then start each
  drive in its own isolated PTY or tmux session.
- **Doctor:** one read-only check that answers "is this instance worth
  driving?" — process up, right version/build, port owned by us, auth valid.
  An agent runs this first whenever anything looks off.
- **Drive:** the harness recipe with real selectors and commands from this
  repo, not examples. Prefer stable handles (ARIA labels, data attributes,
  prompt strings, route paths) over coordinates and tab order.
- **Evidence:** what to capture for a proof and where it goes. Make the
  evidence root ONE variable or flag the caller can set (radar points it at
  `.omnigent/runs/<run-id>/evidence/`), with a default that git ignores —
  check the default with `git check-ignore`. State the proof standards:
  exercise the real user path, not internal setters or test-only endpoints;
  capture the action and the resulting state, not just the final screen;
  verify side effects (files written, rows inserted, messages sent) alongside
  what is visible; mocks only where a production boundary already isolates the
  external system. When the safe path is a dry-run or test mode, verify what it
  actually skips by observing (files, network, git refs) rather than trusting
  its name: some dry-runs still touch the network or open a browser.
- **Cleanup:** how to tear down instances the run created. Never kill by
  process name or port; kill what you started, by the PID or session the
  launch recorded. Cleanup removes instances and scratch state, never the
  evidence: proof artifacts survive the teardown, in the location the skill
  names.
- **Helpers:** any script the skill ships is executable and its invocation is
  shown in the skill body, through its interpreter (`bash scripts/doctor.sh`,
  `node scripts/drive.mjs`) so it also runs where the executable bit was lost.
  A helper the reader has to reverse-engineer is not a helper.

## 3. Seed the feature map

Create `.claude/skills/verify-<app>/features/README.md` plus one file per
user-facing feature you can identify (aim for the top 3–5 to start, from
routes, commands, menus, or docs). Follow the shape in
[`references/feature-map-example/`](references/feature-map-example/), with a
README index and one file per feature. Each file answers, from the user's point
of view: what the feature is, how to reach it, how to drive it with the
harness, and what observable end state proves it works. The four H2s are
`Sub-features`, `How to get to it (user POV)`, `Driving it with <harness>`, and
`Gotchas`.

If the seed data lacks a precondition that a journey needs, the journey reports
a failure and the reason goes in that feature's `Gotchas`. Never weaken the
journey to make it pass. The map is the repo's maintained verification source;
a proof that drives one convenient entry point is incomplete when the map lists
others.

## 4. Prove the generated skill before handing it over

Run its own instructions end to end once: launch, doctor, drive ONE mapped
feature (one is enough; the map exists so later runs can cover the rest),
capture evidence into `.omnigent/runs/<run-id>/evidence/`, clean up. After
cleanup, confirm the evidence still exists at the named location — a cleanup
that eats the proof fails this step. Fix what fails in the skill, and run the
generated cleanup after every failed iteration too, so broken attempts do not
strand processes and ports. A generated skill that was never executed is a
draft, not a deliverable: if you could not run it, return `blocked`, never
`done`.

If you proved it in a stand-in for the real target (a container in place of a
fresh VM, a local stack in place of a remote one), list every setup step the
stand-in did that the target will not. Those steps stay unverified until a run
on the real target covers them.

## 5. Hand over

Leave every file you wrote uncommitted; `deliver` commits the skill together
with whatever else is on the branch. Write the full report to
`.omnigent/runs/<run-id>/report.md`: the files created, the surface chosen and
the ones left out, the assumptions you made, the feature you proved and its
evidence path, and any stand-in gaps. Then return exactly the block your brief
asks for.

Name `verify-maintain` in `next:` as the way to keep the map honest as the app
changes. Suggest a cadence only if your brief asks for one.
