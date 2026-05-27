---
name: review
description: Code review for a diff, file, PR, or implementation result. Use for 'review', 'check', 'inspect'. Escalate to deep-review for high-risk diffs. Front-load this description for Codex implicit matching; explicit invocation via $review always works.
---

# Code Review

## Goal
Review real code evidence only.

## Steps

1. Apply mandatory rules.
2. Identify target: explicit path/commit/diff, otherwise `git diff HEAD`.
3. Escalate to `deep-review` if auth, secrets, DB/API contracts, concurrency, payments, or large diff are involved.
4. Report only issues grounded in code.
5. Every finding must include file:line, evidence, impact, and fix proposal.

## Output
- PASS / WARN / BLOCK
- Findings ordered by severity
- Fix proposals
- Checks not performed

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.

