---
name: rules-required
description: Select and apply only the markdown rules relevant to the current task. Use when task or project instructions require rules, applicable rules are unclear, or a rules guard requests reactivation. Front-load this description for Codex implicit matching; explicit invocation via $rules-required always works.
---

# Rules Required

## Goal
Ensure applicable markdown rules are read and applied without loading unrelated rules.

## Steps
1. Locate and read `RULES_CORE.md` and `RULES_INDEX.md` when available.
2. Use the index and task scope to identify only the relevant detailed rule files.
3. Read those files before edits or implementation/review conclusions.
4. If the rules marker is missing, core-only, or stale, run `codex-rules refresh`; the marker proves checksum activation, not model read completion.
5. Summarize applicable constraints and report conflicts according to the runtime instruction hierarchy.

## Output
- Rules read and applied
- Conflicts
- Task-specific checklist

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
