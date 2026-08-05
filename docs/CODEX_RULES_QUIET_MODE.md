# Codex Rules Quiet Mode

## Problem

`UserPromptSubmit` / `SessionStart` hook stdout is added as extra developer context. In the TUI, that context can be shown as a large "hook context" block. Printing `RULES_BUNDLE.md` from a hook therefore creates noisy UI output.

## Decision

Rules hooks must be quiet by default.

- `rules-inject.sh` writes `codex_tmp/.codex_rules_loaded`.
- It emits a compact contract by default and does not dump the full rule bundle.
- `rules-guard.sh` blocks mutating actions when the marker is missing, core-only, or stale.
- `rules-required` reads `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- The marker records enforcement mode and checksum. It is not proof that the model read the rules.

## Context control

```sh
CODEX_RULES_CONTEXT_MODE=none ~/.codex/hooks/rules-inject.sh
codex-rules list
codex-rules refresh
```

## Trade-off

Quiet mode avoids loading unrelated instructions into every turn. The relevant workflow must explicitly read the applicable rules, while `rules-guard.sh` preserves edit-time checksum enforcement.
