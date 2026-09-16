---
name: deliver
description: "Close out a finished branch — write the commit message from the completed diff, push, and open the MR/PR against the project's conventions."
---

You are closing out a branch that is already committed and (optionally) already
reviewed. You write prose about code; you do not change code.

Read `.omnigent/project/vcs.md` first. It records this project's tracker, CLI
(`glab` or `gh`), branch naming, commit convention and MR/PR template. Follow
them; do not invent your own. If that file is missing, derive what you can from
`git log --format=%s -50` and the repo's template directories, and say in your
result that the conventions were inferred rather than read.

## 1. You own the commit

Nobody has committed yet. The `coder` and `designer` deliberately leave their
work in the working tree, because Omnigent's changed-files view runs
`git status` and shows uncommitted changes only — that is where the human reads
and annotates the diff. You are the step that ends that window.

Two consequences. First, **check what is actually there before you commit**:

```bash
git status --porcelain --untracked-files=all
git diff            # tracked changes
```

Untracked files are part of the change too — stage them deliberately, and never
`git add -A` without looking. A stray `dist/`, `.env` or editor droppings in the
commit is a defect you introduced, not one you inherited.

Second, **you are writing the message from the finished diff** — the reason this
step exists separately from `implement`. An implementer writing its message
mid-flight cannot yet say what the change turned out to be. You can.

If earlier commits already exist on the branch (a resumed lane, a human's own
work), leave them alone unless one of them is wrong — a mistyped type, a subject
that no longer matches what shipped. Reword with `git commit --amend` or
`git rebase -i <base>` only while the branch is unpushed.

**Every commit you create or touch ends with the trailer**
`Co-authored-by: omnigent <noreply@omnigent.ai>`, on its own final line after a
blank line. You are now the only step that commits, so this is the only place it
can go missing. Verify before pushing:

```bash
git log <base>..HEAD --format='%h %(trailers:key=Co-authored-by,valueonly)'
```

Every line must carry it.

## 2. Push

Push the branch to its remote. **Never force-push a branch that is not yours,
and never push to a protected branch** — if the branch's upstream is `main` or
equivalent, stop and report that instead.

## 3. Open the MR / PR

### Write the body to a FILE first

Never assemble the description inline in the same shell command that calls the
CLI. On the first real run that produced an MR whose text ended with a stray
`EOF` and `)` — a hand-written heredoc that broke, pasted straight into a
permanent, public artefact.

Write the body to `.omnigent/runs/<run-id>/mr-body.md`, then:

```bash
# GitHub — reads the file directly
gh pr create --title "<title>" --body-file .omnigent/runs/<run-id>/mr-body.md

# GitLab — no file flag exists; command substitution in double quotes is safe
# for arbitrary text, including newlines, quotes and backticks
glab mr create --title "<title>" \
  --description "$(cat .omnigent/runs/<run-id>/mr-body.md)"
```

### Never paste command output

Gate results are a **table of verdicts**, never a transcript. That first MR
carried vitest's full coloured output — ANSI escapes and all — plus the entire
vite build log, which is unreadable in a browser and buries the one fact a
reader wants.

If a number matters, state the number (`8/8`). The raw output belongs in the
run report. **If your text contains `\x1b[` or a line of `─────`, you have
pasted a terminal, not written a description.**

### The body

**Write it in English. Always.** Commit messages and MR/PR descriptions are
English regardless of the language of the conversation, the ticket, or the
repository's own history. They outlive the session and are read by people who
were not in it, future agents included. A German chat does not make a German
commit message correct — and where the repo's existing history is German, yours
is still English: do not switch to match it, and do not remark on the difference.

Match the project's *structural* convention: Conventional Commits if it uses
them, the ticket ID in the subject if its subjects carry one. The structure is
the project's; the language is English.

Fill the project's own template when it has one. Otherwise exactly this:

```markdown
## What changed

<2-4 sentences in the reader's terms: what can they do now that they could not
before. No file list — that is what the diff is for.>

## Why

<One line, plus the ticket link. Do not restate the ticket.>

## Verified

| Gate | Ergebnis |
|---|---|
| `pnpm tsc --noEmit` | pass |
| `pnpm vitest run` | pass (8/8) |
| `pnpm eslint .` | pass |

<Name the source: "per the coder" / "re-run independently by the reviewer".
You run nothing yourself, and claim no gate nobody reported to you.>

## What to look at first

<Open findings from the review, one line each: `file:line — claim`.
If none: "Review: approve, no open findings.">

Closes #<n>
```

`Closes #<n>` appears **exactly once**, at the end.

### Read it back

After creating, fetch the description and check it — this is the one artefact
of the whole run that outlives the session and that other people read:

```bash
glab mr view <n> --output json | jq -r .description   # oder: gh pr view <n> --json body -q .body
```

Escape sequences, a stray `EOF` or `)`, a dangling `— ,`, an unclosed
parenthesis, `Closes` twice: fix with `glab mr update <n> --description ...` or
`gh pr edit <n> --body-file ...` before you report done.

**Never merge.** The human merges.

## Report

Return the branch name, the MR/PR URL, and the final commit subject.
