---
name: fix
description: Bug fixing, failing tests, runtime errors, unexpected behavior, regression repair. First reproduce and identify root cause. Do not use for new features. Front-load this description for Codex implicit matching; explicit invocation via $fix always works.
---

# Bug Fix

## Goal
Fix a bug by proving the failure, identifying root cause, and adding regression protection.

## Steps

1. Apply mandatory rules.
2. Record symptom, expected behavior, actual behavior, and environment.
3. Reproduce. If runtime reproduction is unavailable, enter static trace mode and clearly mark reproduction as unavailable.
4. Use `systematic-debugging`: boundary trace -> root cause -> hypothesis validation.
5. Add or update a regression test before the patch when feasible.
6. Patch the root cause with minimal diff. Avoid symptom-only fixes.
7. Run relevant tests/checks.

## Output
- Reproduction status
- Root cause
- Fix summary
- Regression test
- Verification
- Unverified risks

## Claude command reference

- `claude/commands/fix.md` から変換された詳細手順は `references/claude-command.md` を読む。
- 内容が競合する場合は、この Codex-native `SKILL.md` と `Common contract` を優先する。

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
