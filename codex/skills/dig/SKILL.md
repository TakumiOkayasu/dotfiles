---
name: dig
description: Investigate hidden assumptions and unresolved decisions in an existing plan through iterative, focused questions. Use when the user asks to dig into a plan, challenge its assumptions, or explore risks before implementation.
---

# Deep Dig

Uncover hidden assumptions, risks, and decisions in the current plan. Dig into a relevant thread before expanding the question list. Preserve the user's goal and constraints.

This is a Codex adaptation of Kuu's Deep Dig command. Read [provenance and runtime changes](references/upstream.md) when comparing or updating it. The skill is distributed under the included [GPL-3.0 license](LICENSE).

## 1. Gather context

Before asking questions, read the current plan, applicable `AGENTS.md`, specifications, related code, and the user's existing decisions. Locate actual project conventions rather than guessing paths or reopening settled choices.

Identify stated goals, constraints, implicit assumptions, missing topics, and evidence that can resolve them without asking the user.

## 2. Map assumptions

Keep an investigation queue ordered by the impact of a wrong assumption. Consider feasibility, user behavior, scope, dependencies, timing, and architecture where relevant. Start with the highest-risk unresolved assumption.

## 3. Investigate iteratively

- Ask two or three focused questions per round, or fewer when one answer determines the rest.
- Offer concrete choices with short trade-offs. Follow the current input tool's limits and do not add an `Other` choice if the host adds it.
- Use an available user-input tool only where the current tool contract permits. If a required decision cannot be collected through a tool, ask it directly in the response and pause dependent work. Continue independent investigation.
- After each answer, identify newly exposed assumptions. Follow the same thread to the next decision or failure consequence before changing topic; aim for at least two levels of relevant inquiry on major topics.
- Do not manufacture questions to meet a count or repeatedly challenge an assumption already supported by evidence.
- Track explored categories, unresolved questions, and confirmed decisions with the host's plan facility or the existing plan document.

Question areas include trade-offs, actual scale, critical failure modes, user scenarios, dependencies, security, maintenance, migration, rollback, and competing priorities. Select areas supported by the current task.

## 4. Integrate each round

Summarize discoveries with the assumption, evidence, impact, and decision. Record each confirmed decision and its rationale in the existing plan. Add new questions to the queue without presenting an unanswered choice as a decision.

If no plan file exists, use the host's plan facility or the response. Create a durable plan file only when requested or required by the project.

## 5. Evaluate and repeat

Return to investigation while a relevant condition remains unmet:

- High-risk assumptions lack evidence or an explicit decision.
- A major topic still has an unexplored consequential assumption.
- New questions affect the plan's viability or scope.
- Trade-offs have not been acknowledged.
- Critical failure modes remain unexplored.
- The plan does not reflect confirmed decisions.

Stop when these conditions are satisfied, the user asks to stop, or a required answer is unavailable. Record the unresolved decision instead of looping indefinitely or claiming the plan is complete.

## Final summary

Report the rounds completed, important discoveries, decisions with rationale, remaining risks, and concrete next actions. Keep the summary proportional to the investigation. Do not implement the plan unless the user also requested implementation.
