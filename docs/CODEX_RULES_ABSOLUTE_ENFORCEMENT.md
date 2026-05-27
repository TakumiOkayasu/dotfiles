# Codex Rules Absolute Enforcement

This patch changes rules handling from "read/remember" to "read + deterministic gate + semantic audit".

## Layers

1. `rules-inject.sh`
   - Activates `codex/rules/*.md` by checksum.
   - Emits only a compact model-visible rules contract.
   - Writes `codex_tmp/.codex_rules_loaded`.

2. `rules-guard.sh`
   - Runs on `PreToolUse`.
   - Allows read-only commands.
   - Blocks mutating tools when rules are inactive or changed.

3. `rules-enforce.sh` / `rules-enforce.py`
   - Runs on `PostToolUse` and `Stop`.
   - Scans changed lines for mechanically checkable rules.
   - Blocks until violations are fixed.

4. `$rules-compliance-review`
   - Semantic second pass for rules that cannot be reliably checked by regex/AST-lite scanning.
   - For large/high-risk diffs, dispatch one rules-only subagent, then parent session makes the final decision.

## Deterministically enforced examples

- loose equality `==` / `!=` in JS/TS
- `=== true` / `=== false`
- `any` in TypeScript
- Promise chains `.then` / `.catch` / `.finally`
- direct `console.*` in production code
- direct `print()` in Python production code
- broad or empty catch handlers
- `toBeDefined()` in tests
- invalid `TODO` format
- commented-out code
- unapproved dependency changes in `package.json`
- `latest` / wildcard dependency versions
- obvious long functions above the hard threshold

## Escape hatch

Use only when a nearer project rule explicitly allows the exception:

```text
// codex-rule-ignore: <specific reason, at least 8 characters>
```

The scanner blocks marker use without a concrete reason.

## Why subagents are supplemental

Subagents are useful for semantic review, architecture direction, and cross-rule reasoning. They are not a complete enforcement boundary. The deterministic scanner is the gate; subagents are the second reviewer.
