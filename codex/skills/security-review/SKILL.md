---
name: security-review
description: Security-only review for auth, authorization, secrets, input validation, injection, XSS, SSRF, path traversal, unsafe deserialization, CORS/CSRF. Front-load this description for Codex implicit matching; explicit invocation via $security-review always works.
---

# Security Review

## Goal

Find exploitable security issues with evidence and fixes.

## Scope

- auth / authorization
- secrets / tokens / credentials
- input validation and output encoding
- SQL / command injection
- XSS / SSRF / path traversal
- unsafe deserialization / dynamic code execution
- CORS / CSRF

## Output

- BLOCK / WARN / PASS
- file:line
- exploit scenario
- evidence
- fix proposal

## Common contract

- Plugin-only operation: use `$skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
