---
name: implementation-router
description: Classify implementation tasks by risk and route to feat, fix, refactor, test, review, or consult. Front-load this description for Codex implicit matching; explicit invocation via $implementation-router always works.
---

# Implementation Router

## Routing

- New behavior -> `feat`
- Bug/failing test/runtime error -> `fix`
- Behavior-preserving cleanup -> `refactor`
- Test-only -> `test`
- Planning/no edit -> `consult`
- Code review -> `review` / `deep-review`

Always apply rules first and escalate high-risk tasks.

## Common contract

- Plugin-only operation: use `$skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
