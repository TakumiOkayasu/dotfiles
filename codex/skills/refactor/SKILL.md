---
name: refactor
description: Behavior-preserving refactoring, structure cleanup, naming, extraction, duplication removal. Do not use when behavior, public API, or data model changes. Front-load this description for Codex implicit matching; explicit invocation via $refactor always works.
---

# Refactor

## Goal
Improve structure without changing behavior.

## Steps
1. Apply mandatory rules.
2. Confirm existing tests/checks and current behavior.
3. State scope and invariants.
4. Make one small structural change at a time.
5. Run tests after meaningful changes.
6. If behavior change is needed, stop and reroute to `feat` or `fix`.

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
