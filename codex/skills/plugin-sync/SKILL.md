---
name: plugin-sync
description: Synchronize codex assets into the local plugin bundle and verify plugin packaging. Front-load this description for Codex implicit matching; explicit invocation via $plugin-sync always works.
---

# Plugin Sync

Run `python3 scripts/generate-standard-workflow-skills.py --repo . --overwrite`, then `python3 scripts/port-claude-assets-to-codex.py --repo . --overwrite --no-backup --prune`, then `python3 scripts/apply-codex-performance-profile.py --repo .`, then `python3 scripts/sync-codex-plugin.py --repo . --clean`, then `python3 scripts/verify-codex-plugin.py --repo .`. Stop on the first failure.

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
