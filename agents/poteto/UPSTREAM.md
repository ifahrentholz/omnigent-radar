# Upstream

poteto runs [open-pstack](https://github.com/ericlitman/open-pstack), the
Claude Code and Codex port of Lauren Tan's
[pstack](https://github.com/cursor/plugins/tree/main/pstack), on Omnigent.
The skill tree under `skills/` is vendored from open-pstack unchanged.

## Pinned version

<!-- pin:begin -->
open-pstack 1.5.0 at `1b03678171f6f400ae2cc9dc4e7a4a6a13e4bb43` (https://github.com/ericlitman/open-pstack/commit/1b03678171f6f400ae2cc9dc4e7a4a6a13e4bb43)
<!-- pin:end -->

## Syncing

```bash
scripts/sync-pstack.sh          # open-pstack main
scripts/sync-pstack.sh <ref>    # a tag, branch or commit
```

The script replaces every vendored skill directory, copies the license and
attribution files into `licenses/`, and rewrites the pin above. Read the diff
before committing it. Changes to `poteto-mode/references/provider-dispatch.md`
or `codex-tools.md` are the ones most likely to need a matching edit in
`skills/omnigent-platform/SKILL.md`.

## What poteto changes

Nothing inside a vendored skill. The adaptation lives in three places:

- `skills/omnigent-platform/` maps the Claude Code tools, built-in skills,
  provider dispatch and model sheet that pstack assumes onto Omnigent.
- `config.yaml` is the orchestrator. Its prompt does the job of open-pstack's
  `SessionStart` hook, which routes non-trivial work into `poteto-mode`.
- `agents/claude/` is the one model lane, for Opus and Sonnet. It takes the
  place of open-pstack's `pstack-<family>-<effort>` agent definitions and of
  the external `pstack-runner`.

## Left out

| Upstream part | Why |
|---|---|
| `skills/setup-pstack` | It writes `~/.claude/pstack-models.md` and an `@` import into `~/.claude/CLAUDE.md`. Every Claude session on the machine reads that file, radar's included. The model sheet lives in `skills/omnigent-platform/` instead. |
| `hooks/` | The `SessionStart` hook only injects the poteto-mode routing mandate. The orchestrator prompt carries it. |
| `agents/*.md` | Claude Code subagent definitions. Omnigent dispatches to the workers under `agents/` instead. |
| Codex, Grok and Fable lanes | Too many tokens for this setup. Their roles run on Opus, and the panels on Opus plus Sonnet 5.5; see the model sheet in `skills/omnigent-platform/`. |

## License

MIT. pstack was created by Lauren Tan. open-pstack builds on Michael Denyer's
pstack-claude port and includes attributed MIT-licensed work from Cursor Team
Kit and Superpowers. See `licenses/NOTICE.md` and the license files beside it.
