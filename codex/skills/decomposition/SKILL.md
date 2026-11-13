---
name: decomposition
description: Turn a complex task into independently understandable, verifiable work items grounded in the actual codebase. Use when the user asks to decompose work, create detailed todos, or turn an agreed goal into an execution plan.
---

# Task Decomposition

Create specific, achievable work items that another worker can execute from their descriptions. Ground them in the actual project before planning.

This is a Codex adaptation of Kuu's Task Decomposition command. Read [provenance and runtime changes](references/upstream.md) when comparing or updating it. The skill is distributed under the included [GPL-3.0 license](LICENSE).

## 1. Explore the codebase

Read the user's task, existing plan, applicable `AGENTS.md`, relevant specifications, and related code. Identify the project structure, existing patterns, affected files, dependencies, and test commands. Do not invent files or APIs to make the plan appear concrete.

## 2. Identify components and dependencies

Separate work by responsibility and observable result. Determine prerequisites and execution order. Mark discovery work as a spike when its result is required before implementation can be planned accurately.

## 3. Resolve unclear decisions

Identify unknowns that change scope, approach, ordering, granularity, acceptance criteria, or risk.

- Use an available user-input tool within its current contract, with a small round of concrete options and trade-offs.
- Do not ask questions already answered by the project or conversation.
- If a required decision cannot be collected through a tool, ask it directly and pause dependent planning. Continue work whose scope is already known.
- Repeat the interview when answers expose another decision affecting decomposition.
- Record unavailable information as a blocker instead of presenting it as an executable task.

## 4. Write actionable work items

For each item include:

- **What:** A concrete action and expected result.
- **Where:** Verified files, modules, functions, or other locations. Clearly mark a proposed new location.
- **How:** The existing pattern or agreed approach to follow, with required inputs and outputs.
- **Why:** How this result contributes to the user's task.
- **Verify:** A runnable check, expected behavior, or explicit manual acceptance criterion.

Keep each item focused on one responsibility and independently verifiable. The upstream guide suggests about 5-30 minutes as a granularity aid; do not split or merge a coherent change solely to fit that estimate.

Include necessary boundary/error handling and tests in the relevant work item. Do not add unrelated hardening, a new testing framework, or speculative abstractions.

## 5. Record and review

Write new work items with `pending` status to the host's plan facility or the established project plan. Include prerequisites and blockers; do not use tool names from another runtime.

Review whether the full set covers the original request, each item has concrete verification, and dependencies permit execution in the stated order. If gaps or new ambiguities appear, return to step 3 and update the work items.

## Final output

Summarize the original goal, work items with their descriptions, dependency order, blockers, and estimated scope. Do not start implementation unless the user also requested it.
