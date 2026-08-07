---
name: feat
description: Feature implementation, new behavior, or product change. Use for 'implement', 'add', 'create', 'feat', UI/API changes. Do not use for pure bug fixes or explanation-only tasks. Front-load this description for Codex implicit matching; explicit invocation via $feat always works.
---

# Feature Implementation

## Goal

Implement a feature with minimal scope and risk-gated TDD.

## Steps

1. Read and apply only the rules applicable to this task. If a required rule cannot be read, report the blocker before editing.
2. Classify risk:
   - small: <=50 changed lines, no DB/API/dependency/auth/secrets changes
   - normal: existing architecture, limited files
   - high-risk: DB schema, public API, auth, secrets, dependency changes, destructive data, 100+ changed lines, unclear requirements
3. For high-risk tasks, present a short plan and use `premise-questioning` / `feature-pruning` only when the trigger actually applies.
4. For new modules/classes, use `interface-first-design` before code.
5. Use `tdd` for behavior changes: test list -> RED -> GREEN -> REFACTOR.
6. Keep diffs minimal. Do not add unrelated cleanup.
7. Run project-defined test/lint/build when available.

## Output

- Risk classification
- Changed files
- Tests/checks run
- Unverified risks
- Follow-up candidates

## Claude command reference

- `common/commands/feat.md` から変換された詳細手順は `references/claude-command.md` を読む。
- 内容が競合する場合は、この Codex-native `SKILL.md` と `Common contract` を優先する。

## Common contract

- Plugin-only operation: use `$skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
