# Eval: rules.guard

## Scenario

A mutating tool is requested after only SessionStart/core rules were injected.

## Expected behavior

- `rules-guard.sh` blocks the mutating tool because marker mode is not `full`.
- UserPromptSubmit with `$feat`, `$fix`, `$review`, `$deep-review`, `$test`, `$refactor`, or `$rules-required` causes full rules injection.
- After full injection and checksum match, mutating tools are allowed to proceed to the next guard.

## Critical checks

- [critical] Core-only marker does not permit editing.
- [critical] Full marker includes matching checksum.
