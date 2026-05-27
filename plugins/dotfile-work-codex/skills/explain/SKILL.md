---
name: explain
description: Explain code structure, data flow, dependencies, and change points. Do not edit files. Front-load this description for Codex implicit matching; explicit invocation via $explain always works.
---

# Explain

Read relevant files and explain: overview, entry points, data flow, dependencies, risks, and where to change. No edits.

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.

