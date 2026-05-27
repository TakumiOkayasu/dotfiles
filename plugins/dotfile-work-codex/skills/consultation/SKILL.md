---
name: consultation
description: Planning and policy decision mode. Use when comparing approaches, designing implementation strategy, or preparing Codex handoff. No file edits. Front-load this description for Codex implicit matching; explicit invocation via $consultation always works.
---

# Consultation

## Goal
Decide a direction without changing files.

## Steps
1. Clarify problem and constraints.
2. Present 2-3 options.
3. Compare tradeoffs in a table when useful.
4. Recommend one option with rationale.
5. Produce Codex handoff if implementation follows.

## Output
- Options
- Comparison
- Recommendation
- Handoff

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.

