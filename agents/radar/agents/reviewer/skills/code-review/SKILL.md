---
name: code-review
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes — Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/PRD asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to "review since X".
---

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

The tracker and its conventions are in `.omnigent/project/vcs.md`. If that file is missing, this project has not been onboarded: report it as a finding and review without the spec axis — do not try to provision it.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

**The usual case in this bundle is an UNCOMMITTED change.** The implementer leaves its work in the working tree so the human can review it in Omnigent's changed-files view, and `deliver` commits only at the very end. So when `git log <fixed-point>..HEAD` is empty but `git status --porcelain --untracked-files=all` is not, the change under review is the working tree: use `git diff` for tracked edits and read each untracked file in full — an untracked file shows up in no diff at all, and skipping it means reviewing half the change. Say in your report which of the two you reviewed.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here — not inside two parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.) — fetch with the tracker CLI named in `.omnigent/project/vcs.md`.
2. A path the user passed as an argument.
3. A PRD/spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below — a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation — and, like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Spawn both sub-agents in parallel

Send a single message with two `Agent` tool calls. Use the `general-purpose` subagent for both.

**Standards sub-agent prompt** — include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full — the sub-agent has no other access to it.
- The brief: "Report — per file/hunk where relevant — (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk. Distinguish hard violations from judgement calls — documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** — include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Report: (a) an **AC coverage table** — one row per acceptance criterion in the spec, `AC-ID | test that executes it (file:line) | PASS / PARTIAL / NO-TEST`. A criterion with no test that actually executes it is `NO-TEST` and is BLOCKING; a test whose _name_ mentions the criterion does not count unless its assertions exercise the behaviour, and neither does a passing suite on its own. (b) requirements the spec asked for that are missing or partial; (c) behaviour in the diff that wasn't asked for (scope creep); (d) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. The table doesn't count against the limit; keep the prose under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings — the two axes are deliberately separate (see _Why two axes_).

Reproduce the AC coverage table in full under `## Spec` — it is the acceptance contract's audit trail, so never summarize it away. Any `NO-TEST` row makes the Spec verdict CHANGES-REQUESTED, however green the suite is.

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes — that's the reranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.

---

# Risk map — where a human should actually look

A human cannot read every line an agent writes; that is the premise of this
whole bundle. So alongside the findings, mark the places in the diff that
deserve human eyes, as comments on the changed files.

**"Critical" means UNREVIEWED BY CONSTRUCTION, not "looks important".** The
distinction matters: a model's sense of what is important correlates with where
it was already paying attention, and therefore with where it is least likely to
be wrong. What follows is ordered by how objectively it can be established.

**Derivable — these are facts, mark all of them:**

1. **Changed code no test exercises.** Cross the diff against the test files it
   touched (and coverage, if the project produces it). Untested changed code is
   unreviewed by definition.
2. **Changed code no acceptance criterion covers.** Map each hunk to `AC-1…n`.
   What maps to nothing was never specified, so nobody agreed it should exist.
3. **Files the project itself calls dangerous** — the danger-zones section of
   `.omnigent/project/architecture.md`.

**Heuristic — weaker, still far better than a hunch:**

4. **Persisted-shape changes** — anything altering data already written to disk,
   a database or storage: migrations, serialization, stored schemas. A real
   example from this bundle's own history: a rename shipped green with 98 tests
   passing and still crashed on every record saved before it.
5. **Deletions and removed behaviour.** Far harder to see in a diff than
   additions, because there is nothing to read where the behaviour used to be.
6. **Changed exported signatures** — every caller is affected, most are off-diff.
7. **Security-shaped surface:** auth, crypto, input parsing, path handling,
   shell invocation, SQL.

**At most eight annotations, ranked.** A map that marks everything marks
nothing. If more qualify, keep the highest classes and say in your report how
many you dropped.

## Posting them

Your brief carries `Session:` — the orchestrator's session id, which is where
the human's changed-files view lives. Write each annotation to a file and POST
it; never inline JSON into the curl command.

```bash
cat > /tmp/ann.json <<'JSON'
{"path": "src/game/logic.ts",
 "body": "🤖 radar · ungetestet: step() behandelt hier den Wrap-Fall, kein Test deckt ihn ab.",
 "anchor_content": "if (next.x < 0)",
 "start_index": 812, "end_index": 827}
JSON
curl -sS -X POST "http://127.0.0.1:6767/v1/sessions/<SESSION>/comments" \
  -H 'Content-Type: application/json' --data @/tmp/ann.json
```

`start_index` / `end_index` are **character offsets in the file**, not line
numbers. Compute them exactly — find the anchor text and take its real offset;
do not estimate. `anchor_content` is what survives if the offsets drift, so
always set it.

**Every body starts with `🤖 radar · ` followed by the class.** The server
records no author in single-user mode, so without that prefix your annotation
is indistinguishable from one the human wrote — and their "send all annotations
to the agent" action would ship your own notes back as a work order.

## Check that they landed, and say so

A posted annotation nobody can see is worse than none: the orchestrator will
tell the human "auch als Annotationen im Diff", they will go and look, and find
nothing. Never claim a post you did not confirm.

The endpoint returns the created comment as JSON. Capture the status and check
both:

```bash
code=$(curl -sS -o /tmp/resp.json -w '%{http_code}' -X POST \
  "http://127.0.0.1:6767/v1/sessions/<SESSION>/comments" \
  -H 'Content-Type: application/json' --data @/tmp/ann.json)
# 2xx AND an "id" in /tmp/resp.json — either one alone is not proof
```

Then report the map inline, one line each (`file:line — Klasse: warum`), and
add this as a line of its own so the orchestrator can pass it on truthfully:

```
annotations: 4 gepostet
annotations: 0 — POST 404, Session-ID im Brief unbekannt
annotations: 2 von 5 — 3× HTTP 000, Server nicht erreichbar
```

If none landed, the map still goes in your report as text. It is then the
orchestrator's only channel for it, and the human needs to know why they will
not find it in the diff.
