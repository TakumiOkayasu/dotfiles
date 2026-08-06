---
name: deep-review
description: High-risk or multi-file code review using security, performance, and maintainability perspectives. Use for 'deep review', large diffs, auth/secrets/DB/API, or release gates. Front-load this description for Codex implicit matching; explicit invocation via $deep-review always works.
---

# Deep Review

## Goal

Run a multi-perspective review and synthesize into one severity-ordered result.

## Steps

1. Apply mandatory rules and read target diff.
2. Split review by perspective: security, performance, maintainability. Use subagents only if available and useful; otherwise use parent-session sections.
3. Security: auth, authorization, input validation, secrets, SQL/command injection, XSS, SSRF, path traversal, unsafe deserialization, CSRF/CORS.
4. Performance: N+1, O(n^2), unnecessary recomputation, memory/resource leak, concurrency/race/await issues.
5. Maintainability: architecture invariants, dependency direction, public contract breakage, test quality, scope creep.
6. Synthesize duplicates and sort Critical -> Warning -> Suggestion.

## Output

- `## 判定: BLOCK|WARN|PASS`
- Counts by severity and perspective
- Findings with file:line, evidence, fix proposal

## Claude command reference

- `common/commands/deep-review.md` から変換された詳細手順は `references/claude-command.md` を読む。
- 内容が競合する場合は、この Codex-native `SKILL.md` と `Common contract` を優先する。

## Common contract

- Plugin-only operation: use `$skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
