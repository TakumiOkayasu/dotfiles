# Codex Rules Quiet Mode

## Problem

`UserPromptSubmit` / `SessionStart` hook stdout is added as extra developer context. In the TUI, that context can be shown as a large "hook context" block. Printing `RULES_BUNDLE.md` from a hook therefore creates noisy UI output.

## Decision

Rules hooks must be quiet by default.

- `rules-inject.sh` writes `codex_tmp/.codex_rules_loaded`.
- It emits no stdout by default.
- `rules-guard.sh` blocks only mutating actions when the marker is missing or stale.
- `rules-required` summarizes applicable rule names and constraints without dumping full rules.

## Debug modes

```sh
CODEX_RULES_INJECT_VERBOSE=1 ~/.codex/hooks/rules-inject.sh
CODEX_RULES_INJECT_OUTPUT=full ~/.codex/hooks/rules-inject.sh
~/.codex/hooks/rules-inject.sh --print-full
```

## Trade-off

Quiet mode avoids UI noise. It does not force full markdown rules into hook-provided developer context every turn. Use the `rules-required` skill and concise `AGENTS.md` invariants for model guidance, while `rules-guard.sh` preserves edit-time checksum enforcement.
