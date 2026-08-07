---
name: commit-msg
description: Generate Conventional Commits message proposals from staged diff. Never run git commit. Front-load this description for Codex implicit matching; explicit invocation via $commit-msg always works.
---

# Commit Message

Check `git status --short` and `git diff --staged`. If staged diff is empty, stop. Suggest 1-3 Conventional Commits messages. Do not commit.

## Claude command reference

- `common/commands/commit.md` から変換された詳細手順は `references/claude-command.md` を読む。
- 内容が競合する場合は、この Codex-native `SKILL.md` と `Common contract` を優先する。

## Common contract

- Plugin-only operation: use `$skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
