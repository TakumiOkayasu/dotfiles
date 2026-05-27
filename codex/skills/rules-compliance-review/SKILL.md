---
name: rules-compliance-review
description: Use after code changes, before final answers, or whenever rules/*.md compliance is uncertain. Runs deterministic rules-enforce first, then performs a semantic audit of codex/rules/*.md against the current diff. Do not use as a replacement for hooks; use it as the human/model-level second pass.
---

# Rules Compliance Review

This skill verifies that current changes comply with all active `codex/rules/*.md` markdown rules.

## Mandatory sequence

1. Run deterministic scanner first:

```sh
codex/hooks/rules-enforce.sh --report
```

If the repo is installed through plugin only, use the plugin copy when available:

```sh
~/.codex/plugins/dotfile-work-codex/hooks/rules-enforce.sh --report
```

2. Read applicable rules:

```sh
codex-rules read
```

3. Inspect the current diff:

```sh
git diff HEAD --
```

4. Semantic audit checklist:

- `coding-conventions.md`: strict equality, no boolean explicit comparison, guard clauses, small functions, no `any`, async/await, no empty/broad catch, logger usage, concrete test assertions.
- `implementation-policy.md`: no unnecessary custom implementation, no unapproved dependencies, no latest/wildcard versions, ORM/migration/logger/validation/crypto/http-client boundaries.
- `hierarchical-architecture.md`: dependency direction, no lateral layer access, no layer skipping, composition over inheritance, interface responsibility, Intent over Raw Input.
- `hallucination-prevention.md`: no invented APIs/options/env/schema/test results, uncertainty marked with `[要確認: reason]`.
- `RULES_CORE.md`: no unread edits, no user-diff overwrite, no destructive/external write without approval, honest verification report.

5. Output only one of these:

```text
## Rules Compliance: PASS
- Checked: <rules>
- Deterministic scan: pass
- Semantic audit: pass
- Remaining risk: <none or concise>
```

```text
## Rules Compliance: BLOCK
1. <file:line> - <rule> - <violation>
   Fix: <specific change>
```

## Subagent policy

For large diffs, high-risk changes, or review tasks, ask one focused subagent to audit rules compliance only:

- Scope: current diff + active `rules/*.md`
- Prohibit: feature suggestions, style-only comments not backed by rules, implementation changes
- Output: `PASS` or `BLOCK` with `file:line`, rule name, evidence, and fix

Do not rely on the subagent alone. Parent session must run `rules-enforce.sh` and make the final decision.
