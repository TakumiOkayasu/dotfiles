# RULES_CORE

These are the short, always-on invariants for dotfile-work Codex.

## Priority

1. User instruction
2. Nearest project `AGENTS.md`
3. Plugin/project markdown rules
4. Active skill workflow
5. General best practice

When instructions conflict, follow the higher-priority source and report the conflict.

## Mandatory behavior

- Read and apply the full applicable rules before editing files, running mutating commands, reviewing code, or giving implementation conclusions.
- Do not edit unread files.
- Do not overwrite user changes or unrelated diffs.
- Do not run destructive commands, dependency changes, DB/API changes, `sudo`, commit, push, deploy, or external writes without explicit user approval.
- Prefer existing project conventions, pinned tool versions, and project-defined test/lint/build commands.
- Do not invent APIs, options, packages, paths, environment variables, schemas, or test results. Verify or mark `[要確認: reason]`.
- Report verification honestly: passed, failed, skipped with reason, and remaining risk.

## Routing

- Feature implementation -> `$feat` -> `tdd` and design skills only when needed.
- Bug/failing test -> `$fix` -> `systematic-debugging` before patching.
- Review -> `$review` or `$deep-review`.
- Rule uncertainty -> `$rules-required`.

## High-risk triggers

Treat as high-risk: DB schema, public API/SDK/CLI contract, auth/authorization, secrets, payments, dependency add/remove/update, data migration/destructive change, 100+ changed lines, multiple services, or unclear requirements.
