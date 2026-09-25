# Pilot: per-worker model routing

Choosing the model per **worker per dispatch**, so the strong model is paid for
where it changes the outcome and not everywhere else. No third-party service, no
fork, no Jev, and no new credential — it runs on the Claude subscription this
machine already has.

The evaluation that led here is in
[`research/jev-model-routing.md`](research/jev-model-routing.md). The short
version: 78% of radar's spend sits in the workers, and per-worker choice is the
only lever that reaches it.

## Who decides

**radar itself.** It classifies the brief it is about to send as SIMPLE /
MODERATE / COMPLEX and passes the matching model as `args.model` on
`sys_session_send`. The procedure — menus, classification signals, floors, the
`reviewer` exclusion — is `radar-lanes` §4c.

This is deliberately not Omnigent's built-in router, and the reason is a hard
constraint rather than a preference:

| Path | How it reaches a model | Credential |
|---|---|---|
| Harness (the workers) | Omnigent **spawns the Claude Code CLI** | The CLI authenticates itself from its own auth file — `cli_config.py:3046`: *"A subscription's credential lives in the harness CLI's own auth file, not our config"* |
| Policy LLM (a judge) | HTTP call via `omnigent/llms/client.py`, adapter picked by model prefix | Needs a credential **in hand**; adapters are `anthropic`, `openai`, `bedrock`, `databricks`, `gemini`, `vertex` |

No adapter shells out to a CLI, so a subscription cannot serve a judge. On this
machine `ANTHROPIC_API_KEY` is unset and Ollama is not running, and there is no
enterprise `ANTHROPIC_BASE_URL` + `apiKeyHelper` gateway
(`claude_managed_gateway_display_name()` returns `None`). Configuring a judge
would therefore mean opening a second, separately billed path alongside the
subscription — a decision the pilot does not need in order to answer its own
question.

**The mechanism is independent of that decision.** `args.model` is runner-side
(`_subagent_model_from_args` → `create_body["model_override"]`) and consults
`routing_available()` nowhere. It works today.

## What changed in the bundle

| Worker | Before | After | Chosen per dispatch? |
|---|---|---|---|
| orchestrator | no pin, `smart_routing_harness: auto` (inert) | `claude-opus-5` | no — pinned |
| `reviewer` | `claude-opus-5[1m]` / 1M | unchanged | **no — excluded on purpose** |
| `coder` | `claude-opus-5[1m]` / 1M | `claude-opus-5` / 200k | yes, **floor `claude-sonnet-5`** |
| `explorer` | `claude-opus-5[1m]` / 1M | `claude-sonnet-5` / 200k | yes |
| `ticketer` | `claude-opus-5[1m]` / 1M | `claude-sonnet-5` / 200k | yes |
| `designer` | `claude-opus-5[1m]` / 1M | `claude-sonnet-5` / 200k | yes |
| `scribe` | `claude-sonnet-5` | unchanged | yes |

The remaining pins are **fallbacks**, not decisions: `args.model` overrides a
sub-agent's `executor.model`, and the pin applies only when a dispatch names no
model. "radar sent nothing" therefore degrades to the table above.

For the `reviewer` that inverts into a guarantee. Its pin is not a fallback but
the decision, and because `args.model` is the *only* thing that can override a
spec pin, radar sending none is precisely what keeps it on `claude-opus-5[1m]`
every single time — and keeps the `[1m]` suffix paired with its 1M window.

### The `coder` floor is a rule, not a gate

`claude-sonnet-5` is the lowest model radar may send to the `coder`. Nothing in
Omnigent enforces it: the only guards on `args.model` are
`harness_supports_model_override` and `model_family_mismatch`, and the latter
checks vendor family, not tier. There is no built-in policy handler that can
clamp a model (`POLICY_REGISTRY` has five entries, all about shell commands,
spawn counts, purposes and write scope).

So the floor is held in two places that are loaded every turn — `radar-lanes`
§4c and the orchestrator prompt — and the menu is shaped to make it structural
within what radar is allowed to name: the `coder` row has no cheap column, and
the no-model fallback is `claude-opus-5`. Both legal paths land at sonnet or
above. The failure mode that remains is radar naming `claude-fable-5` anyway,
which is a prompt violation and will show up in the result line.

### The `[1m]` window had to go from the routed workers

`context_window` and the `[1m]` model suffix are a pair: the suffix asks the
provider for the large window, `context_window` tells Omnigent how far to let the
conversation grow before compacting. A per-dispatch pick carries no suffix, so a
menu offering `claude-sonnet-5` under `context_window: 1000000` would let the
conversation grow past what the model can hold.

Every routed worker is therefore on 200k, the largest window its whole menu
shares. The `reviewer` keeps 1M **because** it is not routed.

This is the one change here that was not asked for, and it was not speculative:
across 27 radar session trees in the last 30 days, `claude-opus-5[1m]` does not
appear in the recorded usage of a single one — only plain `claude-opus-5`.
Whether the suffix ever reached the workers is an open question in the research
doc. To revert: restore `claude-opus-5[1m]` + `1000000` on a worker **and**
remove it from the routable list in §4c. Both, or neither.

## How to tell it is working

radar names the model in the result line whenever it differs from the pin:

```
**✓ explore** → 3 Dateien · `claude-fable-5` (SIMPLE)
```

Silence means the pick equalled the pin — the normal case, and not a fault.
What *is* a fault, and worth watching for on the first runs:

- a `coder` dispatch reporting `claude-fable-5` — the floor was broken;
- a `review` step reporting any model at all — the exclusion was broken;
- every step reporting `claude-opus-5` — radar is classifying everything
  COMPLEX, which is safe but pointless.

## How to measure it

Per-worker cost per run is what the pilot is about:

```bash
omnigent usage --limit 200 --json > /tmp/usage.json
```

Then join against `~/.omnigent/chat.db`: per-conversation cost lives in
`omnigent_conversation_metadata.session_usage` as a zstd blob (2-byte header,
then a zstd frame) carrying `total_cost_usd` and `by_model`, next to
`sub_agent_name`. The query used for the baseline is in the research doc under
"Verification notes".

**The baseline to beat is not the old bundle.** It is this bundle with radar
sending no model at all — i.e. the fallback pins above, which already move
`explorer`, `ticketer` and `designer` off Opus. Measured across the pin commits
`e3027e1` / `9dbb7ed`, that static change alone was worth 4.6x on `explorer` and
2.0x on `coder` per run. Per-dispatch choice has to beat *that*, not the state
before it.

## The upgrade path, if it earns one

`sys_advise_models` is the same decision made by an independent judge instead of
by radar: one call per fanout, the worker's menu as `models`, the pick passed
through as `args.model`. It appears in radar's tool list automatically once the
server has a routing client (`omnigent/tools/manager.py:489`), which needs an
`llm:` block in `~/.omnigent/config.yaml`:

```yaml
llm:
  model: anthropic/claude-haiku-4-5-20251001   # needs ANTHROPIC_API_KEY
  request_timeout: 30
```

§4c already tells radar to prefer that tool when it is present, and to keep the
floors and the `reviewer` exclusion regardless of what it recommends. So this is
a config change on one machine, not a change to the bundle.

Jev would sit behind the same seam again, one level further out
(`routing: provider: external`). Neither step is worth taking until the pilot
shows that per-task choice beats the static assignment at all.
