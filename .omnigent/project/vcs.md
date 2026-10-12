# VCS and tracker conventions

## VCS
- Host: GitHub — `git@github.com:ifahrentholz/omnigent-radar.git` (remote `origin`)
- CLI: `gh` (authenticated as `ifahrentholz`); `glab` is not authenticated and not used here
- Default branch: `main`
- Integration: pull requests into `main`, merged with a merge commit ("Merge pull request #N from …")

## Tracker
- Tracker: GitHub Issues (`ifahrentholz/omnigent-radar`) — confirmed by ingo, 2026-10-12
- Labels for new issues: none

## Branch naming
- `<type>/<kebab-case-topic>`, no ticket ID
- Types seen: `feat/`, `fix/`, `chore/`, `docs/`
- Examples: `feat/per-worker-model-routing`, `fix/install-bun-check`, `chore/sonnet-5-5`

## Commit messages
- Subject: a plain English imperative sentence, capitalised, no trailing period
- No Conventional-Commits prefix and no ticket IDs (a few early commits used `scope: ` prefixes like `onboard:`; recent history does not)
- Subjects may join two changes with ", and" (e.g. "Move the Sonnet seats to Sonnet 5.5, and route on two tiers")

## Templates
- None: no `.github/ISSUE_TEMPLATE`, no `.github/pull_request_template.md`

---
Derived at `5b395d973e79da016d835074046faa55292682bb` (main), 2026-10-12.
