---
name: plugin-install
description: Install the local dotfile-work Codex plugins into the personal marketplace source. Front-load this description for Codex implicit matching; explicit invocation via $plugin-install always works.
---

# Plugin Install

Run `python3 scripts/install-codex-plugin-personal.py --repo .`. Then restart Codex, open `/plugins`, install/enable core plugin, and trust hooks. Enable extra plugin only when needed.

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
