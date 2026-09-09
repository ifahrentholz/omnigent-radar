---
name: onboard
description: radar's first-contact routine for a project — derive what can be derived deterministically, fan out four read-only explorers over what cannot, and leave behind the committed `.omnigent/project/` fact set that retires the questions radar would otherwise ask every session. Load when `.omnigent/project/` is missing or stale.
---

# onboard — learning a project once

The product of this step is **a set of answers radar never has to ask again**.
That is the whole justification: every fact captured here is a question removed
from every future session, and a guess removed from every future brief.

So the bar for including something is: **expensive to derive, and stable over
time.** A file tree is neither — it is cheap to re-read and stale by tomorrow.
Do not capture it.

## Order of operations: derive → detect → ask

Never ask the human for something the repo already knows. Work in this order and
only what survives all three reaches them.

### Step 1 — Derive, deterministically (radar itself, no model tokens)

Run this yourself. It is plumbing, not investigation, and it costs nothing:

```bash
git remote -v
git log --format=%s -100
git branch -r --format='%(refname:short)' | head -40
ls -d .gitlab/issue_templates .gitlab/merge_request_templates \
      .github/ISSUE_TEMPLATE .github/pull_request_template.md 2>/dev/null
ls -d .github/workflows .gitlab-ci.yml Jenkinsfile 2>/dev/null
gh auth status 2>&1 | head -3; glab auth status 2>&1 | head -3
git rev-parse HEAD
```

From that alone you get: the VCS host (**check `glab auth status`, not the
hostname — self-hosted GitLab does not match `gitlab.com`**), which CLI is
actually authenticated, the templates, the CI system, the branch naming pattern,
and whether commit subjects follow a convention or carry ticket IDs.

Write it to `vcs.md` yourself. **Model VCS and tracker as two fields, not one** —
they usually coincide, but code-on-GitHub with tickets-in-Jira is real, and a
schema that cannot express it will quietly record the wrong thing.

### Step 2 — Detect, in parallel (four explorers, `purpose: explore`)

Fan out exactly four read-only explorers over disjoint questions. Each writes
**one file** and returns the standard 8-line report. They run concurrently; do
not chain them.

| Explorer | Writes | Question |
|---|---|---|
| `onboard-commands` | `commands.md` | How do I install, build, test one file, test everything, lint, typecheck, run dev, run e2e — and what does CI actually gate on? |
| `onboard-arch` | `architecture.md` | Top-level modules, what each is for, entry points, layers. Enough to route a ticket to the right corner. |
| `onboard-conventions` | `conventions.md` | Naming, file layout, where tests live and what they are called, error handling, state management, i18n — **read from actual code**, not from a style guide that may not be followed. |
| `onboard-domain` | `domain.md` | The project's ubiquitous language: which words mean what *here*, and which are used inconsistently. |

Fold danger zones (generated files, vendored code, migrations, secrets) into
`architecture.md`, and any existing `CLAUDE.md` / `AGENTS.md` / `.cursorrules`
into `conventions.md` **as a reference, not a copy** — duplicating it guarantees
the two will diverge.

**`commands.md` must be verified, not guessed.** Its explorer's brief says so
explicitly: run each command once, record the exact invocation that worked, its
approximate runtime, and mark anything that failed as failed. A `commands.md`
assembled by reading `package.json` is fiction, and every later step — the
coder's gates, the reviewer's re-run — inherits that fiction.

### Step 3 — Ask, once, in a batch

Whatever is still ambiguous goes to the human as **one** message at the end, not
as questions during the run. In practice two survive:

- Do tickets live somewhere other than the code? (the Jira case)
- Which labels should new issues carry?

## The human review gate

Before writing `INDEX.md`, show the human `domain.md` and `conventions.md` —
just those two. They are where a wrong guess does lasting damage: every later
spec, ticket and review inherits the vocabulary and the conventions, so an error
here is amplified by everything downstream, silently. The other files are
self-correcting; these are not.

One pass, one message: *"Hier ist, was wir verstanden haben — korrigier, was
falsch ist."*

## Output

```
.omnigent/project/
  INDEX.md          # what this project is, 10 lines, plus what lives in which file
  commands.md       # verified local commands + CI gates
  architecture.md   # modules, entry points, layers, danger zones
  conventions.md    # how code is written here (+ pointer to CLAUDE.md et al.)
  domain.md         # ubiquitous language
  vcs.md            # VCS + tracker (two fields), CLI, branch/commit convention, templates, labels
```

`INDEX.md` is radar's own, written last. It carries the onboarding commit SHA
and date in its footer — that is the staleness anchor.

**Commit all of it.** This is team knowledge: the next colleague inherits the
onboarding instead of repeating it. `.omnigent/runs/` is the only part that is
gitignored.

## Staleness

Do not re-onboard wholesale. On session start, if `INDEX.md`'s SHA is far behind
`HEAD`, or if a dependency manifest or CI config changed since it, offer to
refresh **only the affected file** — a changed `package.json` invalidates
`commands.md`, not `domain.md`. Wholesale re-onboarding throws away human
corrections, which is the one thing here that cannot be regenerated.
