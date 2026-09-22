# Jev as radar's task evaluator

**Question:** can a [Jev](https://docs.typesafe.ai/) (typesafe.ai) evaluator pick the
model per task — cheap model for a simple one, Opus for a hard one — and cut radar's cost?

**Answer:** technically yes, three ways. It is the wrong first move. Omnigent already
ships the whole routing mechanism and it is switched off here for three independent
reasons; and the measured spend says routing is not where the money is. Numbers below.

Measured on this machine, 2026-09-22. All Omnigent paths are relative to the installed
package (`omnigent/…`).

## A · What Jev is

A decision model, not a text model. It returns typed answers that code branches on.

| Primitive | Question | Returns |
|---|---|---|
| `Choice` | "Choose an option from a list" | `choice`, `probabilities`, `confidence` |
| `Score` | "Score the state on a rubric" | `score`, `probabilities`, `confidence` |
| `Noul` | "Is this statement true?" | `noul` (0–1) |

Source: [introduction](https://docs.typesafe.ai/introduction) — "Jev is TypeSafe's
flagship model and the first System One model", built to "make fast, structured
decisions that software can use directly", and it "returns structured results directly.
No text generation, no parsing."

It is explicitly not a coding model:
[introduction/coding-agents](https://docs.typesafe.ai/introduction/coding-agents) —
"Jev is not a chat or code-completion LLM", and "not a drop-in replacement for the LLM
behind Claude Code, Cursor, opencode, Copilot […] or similar tools." The documented
relationship is the one this question assumes: "you can use your coding agent as usual
to write code that uses Jev to make decisions."

| | | Source |
|---|---|---|
| Endpoint | `POST https://api.typesafe.ai/v1/systemone`, `Authorization: Bearer <API_KEY>` | [api](https://docs.typesafe.ai/api) |
| Request | `state` (string \| object \| array), `model`, `questions` (map of typed questions) | api |
| Limits | `Choice`: "maximum of 255 options". `Score`: "at least two levels; the API accepts up to 10" | api |
| Pricing | `$42 / $0.042` per Btok / Mtok. "Charged per input token. **Output tokens are free.**" | [models](https://docs.typesafe.ai/models) |
| Context | "64k tokens per request; 32k tokens for `state` plus the longest question" | models |
| Rate | "250,000 tokens per second / 1,200 requests per minute" | models |
| Version | `jev-1.13.0`; aliases `jev-latest`, `jev-preview` | models |
| SDKs | Python and JavaScript/TypeScript | [llms.txt](https://docs.typesafe.ai/llms.txt) |

[patterns/intent-routing](https://docs.typesafe.ai/patterns/intent-routing) documents
exactly this use case: one `Choice` for intent plus one `Score` for complexity, with the
branch taken in application code, and confidence as a second axis — "If we don't have
enough confidence to classify, route to a human agent" (below `confidence < 0.5`), and
`if complexity.score > 1 or low_confidence: route_to_human_agent(...)`.

Jaggedness that bears on routing
([model-jaggedness/jev-1.13](https://docs.typesafe.ai/model-jaggedness/jev-1.13)):

- "`jev-1.13` answers the question you wrote, not the one you meant."
- "Accuracy falls as the state grows with content unrelated to the decision." A whole
  chat turn as `state` is mostly irrelevant content.
- Adversarial content: "`jev-1.13` does not treat it as hostile by default. Content
  written to adversarially steer the model […] can move the answer."
- "Instructions carrying double negatives or complex indirection are answered less
  reliably."

The documented math, counting and date weaknesses do not apply: this decision reads no
numbers. A build aid exists — `claude plugin marketplace add typesafe-ai/skills` then
`claude plugin install typesafe@typesafe-ai`
([agent-skill](https://docs.typesafe.ai/agent-skill)).

## B · Omnigent already ships this

The pluggable seam exists and is documented as pluggable.

| Piece | Where |
|---|---|
| `RoutingClient` protocol — `async route(message, available_models) -> RoutingResult \| None` | `omnigent/server/smart_routing.py:241` |
| `RoutingResult` — `model`, `rationale`, `harness`, `raw_model` | `omnigent/server/smart_routing.py:221` |
| Built-in judge `LLMRoutingClient` | `omnigent/server/smart_routing.py:550` |
| Judge rubric `_JUDGE_SYSTEM_TEMPLATE` | `omnigent/server/smart_routing.py:485` |
| Timeout ceiling `ROUTING_REQUEST_TIMEOUT_S = 9.0` | `omnigent/server/smart_routing.py:68` |
| Pluggability contract | `omnigent/runtime/caps.py:99-103` |

`caps.py:99-103` is the sentence that makes a third-party evaluator legitimate rather
than a hack: "Pluggable model routing client. The default LLMRoutingClient uses the
server-level `llm:` config to call a lightweight judge. Managed deployments can supply a
different implementation (e.g. a rules engine or remote service). `None` disables
routing."

The built-in judge already implements the user's scenario verbatim
(`smart_routing.py:485`):

```
  SIMPLE   → fast: first available model
             Examples: greetings, quick lookups, one-line fixes, trivial Q&A.
  MODERATE → balanced: middle available model
  COMPLEX  → powerful: last available model
             Examples: multi-file refactors, architecture decisions, security analysis,
             long reasoning chains, tasks requiring high accuracy or broad context.
```

**Two backends**, `omnigent/server/routing_backend.py`: an external `task_v1` client
calling `<base_url>/routes:select`, and the built-in judge. `select_router()`
(`:92`) picks per call; `route_with_fallback()` (`:129`) falls back to the judge;
`routing_available()` (`:288`) is "the single 'is routing configured' gate".

**The external wire contract is versioned in the package** — `omnigent/api/routing/v1/routing_pb2`,
sent as snake_case JSON (`MessageToDict(..., preserving_proto_field_name=True)`,
`smart_routing.py:1834`). Descriptors, read from the installed module:

```
SelectRouteRequest  { repeated RouteOption route_options; Task task;
                      RouteSelector route_selector; SessionHistory session_history }
RouteOption         { string model; string harness }
Task                { string prompt }
RouteSelector       { string router_name; google.protobuf.Struct config }
SelectRouteResponse { repeated RouteSelection route_selection; string rationale }
RouteSelection      { RouteOption route_option; google.protobuf.Struct params }
```

**`sys_advise_models`** (`omnigent/tools/builtins/advise_models.py`) is the fan-out
advisor: "Recommend the best model per worker per task before fan-out. […] Use the
returned model as args.model in sys_session_send. Advisory only." It registers only when
**both** "`tools.agents` is declared in the spec" **and** "`RuntimeCaps.routing_client`
is configured" (`advise_models.py:10-13`). Server-side handler
`_handle_advise_models_mcp` (`omnigent/server/routes/_sessions/helpers.py:10091`) returns
`{"router_on": false, "recommendations": []}` at `:10123` when no client is configured.

**Three trigger points**, all fail-open on the 9 s budget: create-time
(`omnigent/server/routes/_sessions/orchestration.py`), turn routing
(`omnigent/runner/turn_routing.py`), subagent routing (`omnigent/runner/subagent_routing.py`).

**Turn routing fires once per session, not per turn.** `already_routed()`
(`omnigent/runner/turn_routing.py:437`) is "the authoritative 'route once' gate", read
first in `resolve_turn_route` at `:614`, returning `_allow("this session already has a
routing decision", terminal=True)`.

> **Correction to `agents/radar/config.yaml:33`.** The comment claims "Smart routing
> makes that call per turn". It does not. One decision is taken for the whole session and
> pinned. The stated rationale for leaving the orchestrator unpinned — that ~90% cheap
> turns and ~10% expensive turns would each get the right model — does not describe what
> the mechanism does.

## C · Why it is inert on this machine

Three independent blockers. Each alone is sufficient.

| # | Blocker | Evidence |
|---|---|---|
| 1 | No router is configured at all | `~/.omnigent/config.yaml` holds only `host:`, `providers:`, `tui:` |
| 2 | `omnigent run` cannot turn routing on | `omnigent/cli.py:8157`, `:8293` |
| 3 | `smart_routing_harness: auto` is therefore a no-op | `omnigent/server/routes/_sessions/orchestration.py:8215` |

**1.** `_build_routing_backends` (`omnigent/cli.py:383`) yields both sides `None`. With
no `routing:` block it falls to `_build_default_databricks_routing_client` (`:235`),
which returns `None` "when there is no Databricks provider" — there is none. The
built-in side is `_build_local_llm_routing_client` (`:358`), which returns `None` when
`server_llm is None` — there is no `llm:` block. `routing_available()` is then false.
The local server is spawned against exactly this file
(`omnigent/host/local_server.py:726`).

**2.** `bin/radar:39,42` launches `omnigent run`, and `run --smart-routing` is removed:
the flag's help is "`[REMOVED]` Use `omnigent claude|codex --smart-routing` or the web
UI" (`cli.py:8157`), and passing it raises (`cli.py:8293-8294`, under the comment "`run`
never routed in-harness, and its create-time route is gone"). Only a bare
`omnigent claude|codex --smart-routing` harness session or the web UI can create a
session with `cost_control_mode_override: "on"`.

**3.** `_spec_routes_its_own_harness` (`orchestration.py:8215`) returns `False` on its
first line unless `body.cost_control_mode_override == "on"`. So
`agents/radar/config.yaml:36` never fires from a `bin/radar` launch.

## D · What radar actually costs

Source: `omnigent usage --limit 200 --json` joined to `~/.omnigent/chat.db`. `omnigent
usage` prints "Costs are best-effort estimates; consult your provider for actual
billing" (`omnigent/cli.py:6532`). A session row is a whole session **tree**:
`load_session_usage(..., root_conversation_id=...)` (`omnigent/server/routes/usage.py:172-175`);
the 63 worker conversations under radar's 27 roots have no row of their own.

| | |
|---|---|
| All agents, last 30 days | **$870.04** (`cost_last_30d`; the brief's $869.38 was the same figure earlier in the day) |
| radar, 27 session trees | **$170.00**, ⌀ **$6.30** per run, 2026-09-09 → 2026-09-21 |
| Model split across those trees | `claude-opus-5` $110.04 (65%) · `claude-sonnet-5` $37.80 (22%) · `claude-fable-5` $22.16 (13%) |

### The orchestrator-vs-worker split — recovered

**The brief said this split is not separable from the data. It is.** Per-conversation
usage is stored in `omnigent_conversation_metadata.session_usage` as a zstd-compressed
JSON blob carrying `total_cost_usd` and `by_model`, alongside `sub_agent_name`.
Decompressed and summed it reconciles to $170.00 exactly:

| Role | Runs | Cost | Share | Models as recorded |
|---|---|---|---|---|
| `coder` | 16 | $73.56 | 43% | opus $44.62 · sonnet $28.94 |
| orchestrator | 27 | $36.96 | 22% | **fable $22.16** · opus $14.79 |
| `explorer` | 24 | $32.80 | 19% | opus $28.50 · sonnet $4.30 |
| `reviewer` | 12 | $22.13 | 13% | opus $22.13 |
| `scribe` | 10 | $3.87 | 2% | sonnet $3.87 |
| `ticketer` | 1 | $0.69 | 0% | sonnet $0.69 |

Two consequences, and they decide the question:

- **75% of the spend is in workers, which turn routing never touches.** It routes the
  orchestrator's session only.
- **The orchestrator is already mostly cheap.** 60% of its $36.96 ran on
  `claude-fable-5` without any router. The entire prize for routing the orchestrator
  perfectly is the $14.79 of opus it still draws — **1.7% of the 30-day bill**.

### The pins already ran the experiment

Commits `e3027e1` (2026-09-10 17:57, `coder`) and `9dbb7ed` (2026-09-11 09:13, the rest)
pinned workers to `claude-opus-5[1m]`. Sessions straddle both dates, and the model
recorded flips exactly at the commit — a clean natural experiment on static assignment,
with no router involved.

| Worker | Before the pin | After the pin | Per-run |
|---|---|---|---|
| `coder` | 9 runs, all sonnet, ⌀ $3.22 | 7 runs, all opus, ⌀ $6.37 | **2.0×** |
| `explorer` | 9 runs, all sonnet, ⌀ $0.48 | 13 runs, all opus, ⌀ $2.19 | **4.6×** |
| `reviewer` | 6 runs, opus, ⌀ $1.30 | 6 runs, opus, ⌀ $2.39 | no pin effect — opus both sides; the delta is workload |

`explorer` is the standout: the most-dispatched worker, and the pin multiplied its unit
cost 4.6× for read-only investigation. Whether that bought better findings is not in
this data — but it is a one-line question, not a routing question.

### Jev's own cost is not the issue

At `$42` per Btok input, a ~1k-token routing call costs **$0.000042**. Ten calls per run
across all 27 runs is roughly **$0.011**. Against $870 the router's own price is noise;
only its decision quality and its latency matter.

## E · Three integration paths

| Path | Shape | Cost to build | Verdict |
|---|---|---|---|
| **A** | Adapter service behind `routes:select` | config-only on the Omnigent side | the only one that needs no fork |
| **B** | Custom `RoutingClient` in-process via `RuntimeCaps` | fork or entry point | no advantage over A |
| **C** | Route inside radar itself, via `args.model` | prompt/skill edit only | viable, and now unblocked |

**A — adapter behind `routes:select`.** `routing: {provider: external, base_url,
router_name, api_key}` in the server config; `_build_external_routing_client`
(`omnigent/cli.py:280`) requires `base_url` + `router_name` and expands `${ENV}` in
`api_key`. The adapter speaks the proto contract in §B and calls Jev internally — a
`Choice` over the offered `route_options` plus a `Score` for complexity, gated on
`confidence`. It also switches on `sys_advise_models`. Still blocked by blocker 2 for
`bin/radar` launches.

**B — in-process `RoutingClient`.** `_build_routing_backends` understands only
`provider: external`, `provider: none`, and "anything else — no external side, the
built-in judge only" (`cli.py:383`). There is no config path for an arbitrary class, so
this needs a fork. Higher coupling, same result as A.

**C — route inside radar.** The orchestrator already classifies into lanes
(`agents/radar/skills/radar-lanes/SKILL.md`); the lane could carry the model and be
passed as `args.model` on each `sys_session_send`. No Omnigent config, no blocker 2.

> **Open question from the brief, now resolved: `args.model` does override a sub-agent
> spec's `model:` pin.** An explicit `args.model` is validated only against whether the
> child harness supports overrides at all and against model-family compatibility
> (`model_family_mismatch`, `omnigent/models/model_override.py:151`), then written
> straight to `create_body["model_override"]`
> (`omnigent/runner/tool_dispatch.py:2639`). The spec's own pin is consulted only on the
> *other* branch, where no model is passed — inheritance is "skipped when the sub-agent
> spec pins its own model" (`tool_dispatch.py:2651-2655`). And `model_override` outranks
> the spec's static `llm.model` in the documented precedence
> (`omnigent/server/routes/_sessions/orchestration.py:1329`).
>
> So path C does **not** require deleting the workers' pins. They become defaults that a
> per-dispatch decision can override — which also makes the fallback safe: if the
> orchestrator says nothing, the pin still holds.

Path C's real cost is that the orchestrator judges the difficulty of work it is about to
delegate, from the same context it used to classify the lane — no independent signal,
and it contradicts the bundle's own line that radar "verifies nothing".

## F · Risks

- **Asymmetric failure.** A complex task sent to a cheap model costs a failed
  `implement` plus a re-run — ⌀ $6.37 for a `coder` run against a saving of ~$3. One bad
  call erases several good ones. The mitigation is Jev's own: escalate below a
  confidence threshold ([patterns/intent-routing](https://docs.typesafe.ai/patterns/intent-routing)).
- **Prompt injection.** Router input is user text, and "`jev-1.13` does not treat it as
  hostile by default" ([jev-1.13](https://docs.typesafe.ai/model-jaggedness/jev-1.13)).
  A prompt saying "this is a trivial task" can move the routing decision.
- **Data egress.** Up to 4000 characters of the user's prompt leave the machine per call
  — `message[:4000]` at `omnigent/server/smart_routing.py:591` and `:1830`. For client
  projects this is a DPA question before it is a technical one.
- **Latency.** The turn hook holds the prompt until the router answers, capped at 9 s
  (`ROUTING_REQUEST_TIMEOUT_S`, `smart_routing.py:68`).

## G · Recommendation

**Do not start with Jev.** In order, with the point at which to stop:

1. **The measurement is already done — read §D.** 75% of the spend is in workers, the
   orchestrator is already 60% on `claude-fable-5`, and turn routing would contest
   $14.79 of $870. *Abort the turn-routing idea here.* It targets the smallest pot and
   its premise — per-turn decisions — is false (§B).

2. **Fix `agents/radar/config.yaml:33`,** which states a per-turn behaviour the
   mechanism does not have. One comment, no behaviour change.

3. **Revisit the pins — the zero-code lever.** §D prices them: `explorer` at 4.6× and
   `coder` at 2.0×. Downgrading `explorer`, `ticketer` and `designer` is one line each,
   needs no router, no third party and no latency, and is worth more than any routing
   decision on the orchestrator. *If this recovers enough, stop here.*

4. **Only then a router, and the built-in judge first.** It is config-only — an `llm:`
   block in `~/.omnigent/config.yaml` (`cli.py:358`) — and it already encodes the
   SIMPLE/MODERATE/COMPLEX rubric. Blocker 2 still applies, so validate through the web
   UI, not `bin/radar`.

5. **Jev last, as path A,** measured against that judge. Jev buys typed output with
   calibrated confidence, lower latency and negligible cost; it does not buy a different
   answer to "is this task hard", and that is the part nobody has measured.

**The honest framing:** the business case does not hang on Jev. It hangs on whether a
per-task decision beats a static per-worker assignment — and on this evidence the static
assignment has not yet been tuned at all. Tune it first; it is free, and it sets the
baseline any router has to beat.

## Verification notes

Every claim above was checked against the primary source. Corrections made to the
briefed findings:

- **Separability (§D).** The orchestrator/worker split was briefed as unrecoverable. It
  is recoverable from `omnigent_conversation_metadata.session_usage` and changes the
  recommendation.
- **`args.model` vs. spec pin (§E).** Briefed as unverified; resolved — the override
  wins, so path C needs no pin removal.
- **Turn routing (§B).** Confirmed once-per-session, and `agents/radar/config.yaml:33`
  is wrong.
- **Limits (§A).** The 255-option and 2–10-level limits are on
  [api](https://docs.typesafe.ai/api), not [models](https://docs.typesafe.ai/models).
- **Line numbers.** `_JUDGE_SYSTEM_TEMPLATE` is at `smart_routing.py:485`,
  `_spec_routes_its_own_harness` at `orchestration.py:8215`, `_build_routing_backends`
  at `cli.py:383`; the tree-cost call is `load_session_usage` at `usage.py:172-175`, not
  `load_session_tree` at `:180` (that one collects harnesses).
- **30-day total.** $870.04 at time of writing, not $869.38; it accrues during the day.

Not verified:

- **"Rate limits are dynamic."** The numbers on [models](https://docs.typesafe.ai/models)
  are confirmed; the qualifier is not stated on that page.
- **`claude-opus-5[1m]` never appears in radar's recorded usage** — only plain
  `claude-opus-5` — although 16 conversations elsewhere in the same database do record
  the `[1m]` key. Whether the 1M-context suffix is reaching the workers is open, and it
  is a cost question in its own right.
