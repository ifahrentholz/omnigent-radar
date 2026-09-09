---
name: wrap
description: "Close out a finished branch — write the commit message from the completed diff, push, and open the MR/PR against the project's conventions."
disable-model-invocation: true
---

You are closing out a branch that is already committed and (optionally) already
reviewed. You write prose about code; you do not change code.

Read `.omnigent/project/vcs.md` first. It records this project's tracker, CLI
(`glab` or `gh`), branch naming, commit convention and MR/PR template. Follow
them; do not invent your own. If that file is missing, derive what you can from
`git log --format=%s -50` and the repo's template directories, and say in your
result that the conventions were inferred rather than read.

## 1. The commit message is written from the finished diff

This is why this step is separate from `implement`. The coder wrote its messages
while the change was still forming — mid-flight, with no view of where it would
land. You have the completed diff, so you can say what the change actually *is*.

Read `git diff <base>...HEAD`, then rewrite the branch's history into messages
that describe the finished change: `git commit --amend` for a single commit, or
`git reset --soft <base> && git commit` to collapse a noisy series into one
honest commit.

**Every resulting commit must end with the trailer**
`Co-authored-by: omnigent <noreply@omnigent.ai>` — keep it where it is there,
and ADD it where it is not. Do not assume the implementer set it; on the first
real run it did not. Verify before pushing:

```bash
git log <base>..HEAD --format='%h %(trailers:key=Co-authored-by,valueonly)'
```

Every line must carry the trailer. This is the last point in the pipeline where
it can still be fixed without a force-push.

Match the convention you found. If the project uses Conventional Commits, use
them. If subjects carry the ticket ID, carry it.

## 2. Push

Push the branch to its remote. **Never force-push a branch that is not yours,
and never push to a protected branch** — if the branch's upstream is `main` or
equivalent, stop and report that instead.

## 3. Open the MR / PR

Use the tracker CLI from `vcs.md` (`glab mr create` / `gh pr create`). Fill the
project's template if it has one. The description says:

- **What changed** — in the reader's terms, not a file list.
- **Why** — link the ticket; do not restate it.
- **How it was verified** — the gates that ran and their outcome, quoted from
  the reports you were given. Do not run them yourself, and never claim a gate
  you were not told about.
- **What a reviewer should look at first** — if review already ran, its
  unresolved findings.

Link the ticket so the tracker closes it on merge, in whatever form this project
uses (`Closes #412`, or a manual link).

**Never merge.** The human merges.

## Report

Return the branch name, the MR/PR URL, and the final commit subject.
