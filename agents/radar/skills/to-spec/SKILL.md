---
name: to-spec
description: Turn the current conversation into a spec and publish it to the project issue tracker — no interview, just synthesis of what you've already discussed.
---

This skill takes the current conversation context and codebase understanding and produces a spec (you may know this document as a PRD). Do NOT interview the user — just synthesize what you already know.

The project's own vocabulary and conventions live in `.omnigent/project/` — read `INDEX.md` there first and use that vocabulary throughout the spec. If `.omnigent/project/` is missing, this project has not been onboarded: say so in one line, then write the spec anyway from the conversation and the repo.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

Check with the user that these seams match their expectations.

3. Write the spec using the template below and save it to `docs/specs/<slug>.md`.

Do **not** publish it to the issue tracker. That is the `tickets` step's job and it runs only if the human asks for it. A spec that is a file can be approved, edited, or thrown away without ever touching the tracker — which is the point of keeping the two steps apart.

<spec-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Acceptance Criteria

A numbered list of acceptance criteria — `AC-1`, `AC-2`, … These IDs are the acceptance contract for the whole pipeline: tickets carry them as checklists, and the review reports test coverage per AC ID. Three rules:

- **State the behaviour, not its evidence.** "AC-3: a cancelled order cannot be shipped" is an acceptance criterion. "There is a test for cancellation" is not — that is a claim about the safety net, and it stays true even after the behaviour breaks.
- **Every AC must be falsifiable.** Name what would have to happen for it to be violated. If you cannot describe the violation, the AC is too vague to test and it will pass by default.
- **One behaviour per AC.** Split compound criteria, so a ticket and a test can each map to a single AC ID.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts — not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>
