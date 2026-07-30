---
name: test
description: Add or improve tests for existing behavior or new specification. Use for unit/integration test additions. Do not use for CI-only changes. Front-load this description for Codex implicit matching; explicit invocation via $test always works.
---

# Test Authoring

## Goal
Add meaningful tests that fail for the right reason and protect behavior.

## Steps
1. Apply mandatory rules.
2. Inspect existing test runner, layout, naming, and assertions.
3. Define what behavior each test proves.
4. Use `tdd` when changing implementation.
5. Avoid tautological assertions and coverage-only tests.
6. Run relevant tests or report why not.

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
