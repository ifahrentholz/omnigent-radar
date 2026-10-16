# Upstream

Two of the verifier's three skills are adapted from
[open-pstack](https://github.com/ericlitman/open-pstack), the Claude Code and
Codex port of Lauren Tan's [pstack](https://github.com/cursor/plugins/tree/main/pstack):

| Skill here | Upstream | At |
|---|---|---|
| `skills/radar-create-verification-skill/` | `plugins/pstack/skills/create-verification-skill/` | open-pstack 1.10.0, [`22aff42`](https://github.com/ericlitman/open-pstack/commit/22aff4297dc30a0e7901329e67b8f810e54d9fd0) |
| `skills/radar-maintain-verification-skill/` | `plugins/pstack/skills/maintain-verification-skill/` | same |
| `skills/radar-create-verification-skill/references/feature-map-example/` | the same path, **unchanged** | same |

`skills/radar-verify/` is this bundle's own. It is the step that consumes what
the other two produce, the job pstack hands to Claude Code's `run` and
`verify` built-ins, neither of which works under Omnigent.

## Adapted, not vendored

Unlike `agents/poteto/skills/`, these are not byte-for-byte copies and
`scripts/sync-pstack.sh` does not touch them. The proof standard is upstream's,
word for word where it could be. What changed is how the bundle operates:

- **Headless.** "Ask the user" becomes an explicit assumption or a `blocked`
  result; a radar worker has nobody to ask mid-run.
- **No product code.** Upstream fixes a checkout that does not build before
  generating; here that is reported, because product code belongs to
  `implement`.
- **No network without approval.** Installs and downloads need the human's yes
  in the brief, as everywhere in radar.
- **The source wave moved up a level.** Upstream's maintenance pass fans out a
  read-only subagent per feature. An Omnigent worker cannot dispatch, so radar
  runs that wave as `explorer`s before it dispatches the verifier.
- **Uncommitted, then `deliver`.** Upstream opens the PR itself; here the
  corrections stay in the working tree for the human and for `deliver`.
- **Evidence under `.omnigent/runs/`**, and the generated skill's evidence
  root is one variable radar can point there.

## Updating

Compare the two upstream `SKILL.md` files against the pin above, carry the
proof-standard changes over by hand, and move the pin. The feature-map example
can be copied over as is.

## License

MIT, (c) 2026 Lauren Tan — see `LICENSE-pstack`. open-pstack builds on Michael
Denyer's pstack-claude port; its full attribution is in
`agents/poteto/licenses/NOTICE.md`.
