---
name: plan
description: Planning-only mode for 2-3 options and a recommendation. Do not edit files. Front-load this description for Codex implicit matching; explicit invocation via $plan always works.
---

# Plan

Use `consult`. File edits are forbidden. Output options, comparison, recommendation, and handoff.

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.

