---
name: onboard
description: "radar's one-time project setup — derives the VCS and tracker conventions from git itself into .omnigent/project/vcs.md and sets the .gitignore entry. Deliberately writes no summary of the codebase; architecture, conventions and domain language are read from the code at the moment they are needed. Load when .omnigent/project/vcs.md is missing."
---

# onboard — the facts that are not in the code

This step captures only what an agent **cannot** get by reading the repository
when it needs it: how this project names branches, writes commit messages, and
which tracker it files against. That lives in git metadata and the tracker
config, not in the source.

Everything about the code is read from the code, by whoever needs it, at the
moment they need it.

## Why there is no architecture.md, conventions.md, domain.md or commands.md

An earlier version of this bundle produced all four. They made the output
*worse* than no preparation at all. Three reasons, in order of the damage they
did:

1. **A description turns into a prescription.** `conventions.md` saying "this
   project does X" makes a coder apply X in a corner of the repo that actually
   does Y. The document was written to describe and ends up overruling the
   code.
2. **It is stale the moment it is written,** and nothing makes the divergence
   visible. The code moves; the summary does not.
3. **It substitutes someone else's compression for the agent's own judgement.**
   A coder reading the three files it is about to change learns more that is
   relevant to *this* task than any repo-wide digest can carry — and cannot be
   misled by a summarization it did not perform.

Do not reintroduce them, and do not write a smaller version of them under
another name.

**Where the genuinely non-obvious goes instead:** if a project fact cost
someone a wrong turn — the e2e suite needs a docker compose stack up first,
there is no build script and `expo export` is the working substitute — that is
a **learning**, not project documentation. One line in `.omnigent/learnings.md`
with the trigger first. See the `learn` skill. The difference is that a
learning earns its place by having already gone wrong once.

## The one thing to derive

Run this yourself. It is plumbing, not investigation, and costs no model
tokens:

```bash
git remote -v
git log --format=%s -100
git branch -r --format='%(refname:short)' | head -40
ls -d .gitlab/issue_templates .gitlab/merge_request_templates \
      .github/ISSUE_TEMPLATE .github/pull_request_template.md 2>/dev/null
gh auth status 2>&1 | head -3; glab auth status 2>&1 | head -3
git rev-parse HEAD
```

From that alone: the VCS host (**check `glab auth status`, not the hostname —
self-hosted GitLab does not match `gitlab.com`**), which CLI is actually
authenticated, the templates, the branch naming pattern, and whether commit
subjects follow a convention or carry ticket IDs.

Write `.omnigent/project/vcs.md`. **Model VCS and tracker as two fields, not
one** — they usually coincide, but code-on-GitHub with tickets-in-Jira is real,
and a schema that cannot express it will quietly record the wrong thing. End
the file with the commit SHA and date it was derived at.

Then ensure the ignore entry exists:

```bash
grep -qxF '.omnigent/runs/' .gitignore 2>/dev/null || echo '.omnigent/runs/' >> .gitignore
```

Nothing else about the repo's `.gitignore` is yours to change.

## Ask, once, only what is left

Two things are not derivable and only these go to the human, in one message at
the end:

- Do tickets live somewhere other than the code? (the Jira case)
- Which labels should new issues carry?

On an empty repo, both can wait — say so and move on; the tracker conventions
are still worth deriving, because `ticketer` and `deliver` read them.

## Output

```
.omnigent/project/vcs.md    # VCS + tracker (two fields), CLI, branch/commit
                            # convention, templates, labels, derived-at SHA
```

**Commit it.** It is team knowledge and it is small. `.omnigent/runs/` is the
only part that stays out.

## Staleness

`vcs.md` describes conventions, not code, so it ages slowly. Refresh it when
the remote changes, a template is added, or the commit convention visibly
shifts — not on a schedule, and never wholesale: a human may have corrected
the label set, and that is the one thing here that cannot be regenerated.
