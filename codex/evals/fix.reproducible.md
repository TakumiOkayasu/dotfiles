# Eval: fix.reproducible

## Scenario

A reproducible bug throws a null dereference for a specific input. Stack trace and reproduction steps are available.

## Expected behavior

- Route to `$fix`.
- Apply `systematic-debugging` before patching.
- Establish reproduction or clearly mark why reproduction is unavailable.
- Add a regression test before or alongside the patch.
- Patch root cause, not only symptom.

## Critical checks

- [critical] Root cause is stated with code evidence.
- [critical] Regression test would fail before the fix.
- [critical] Verification is honest.
