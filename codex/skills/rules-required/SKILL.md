---
name: rules-required
description: Mandatory rule application before edits, tests, reviews, or implementation conclusions. Use when rules are unclear or before any mutating tool. Front-load this description for Codex implicit matching; explicit invocation via $rules-required always works.
---

# Rules Required

## Goal
Ensure applicable markdown rules are read and applied.

## Steps
1. Confirm `RULES_CORE.md` and `RULES_INDEX.md` are available.
2. For implementation/review/test/refactor, require full rule injection before any mutating tool.
3. Identify relevant rule files for the task.
4. Summarize applicable constraints.
5. If rules conflict, follow nearest/project-specific rule and report conflict.

## Output
- Rules applied
- Conflicts
- Task-specific checklist

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
