---
name: deslop
description: Remove unnecessary AI-generated comments, wrappers, and defensive code introduced by the current branch while preserving behavior. Use when the user asks to deslop a diff or clean up AI-generated code.
---

# Remove AI code slop

Review the branch diff and remove unnecessary additions while preserving intended behavior and the project's conventions.

This is a Codex adaptation of Kuu's deslop skill. Read [provenance and runtime changes](references/upstream.md) when comparing or updating it. The skill is distributed under the included [GPL-3.0 license](LICENSE).

## 1. Resolve the base

Use the PR's actual base when the task identifies one. Otherwise select the first existing ref from `origin/main`, `origin/master`, `main`, and `master`. If no base can be established, ask for it before editing.

Inspect `git status --short`, `git diff --name-only <base>...HEAD`, and `git diff <base>...HEAD`. Include the working-tree diff only when it is part of the requested cleanup; preserve unrelated user changes.

## 2. Inspect before removing

Read the changed code, relevant callers, contracts, and tests. Look for:

- Comments that add no reason or conflict with the surrounding style.
- Defensive checks and catch blocks unsupported by the actual call path.
- Wrappers, indirection, helpers, and abstractions without current value.
- Other additions inconsistent with the project's established conventions.

Do not infer that code is unnecessary just because it looks defensive. Verify that a check is redundant or unreachable before removing it. Preserve validation at trust boundaries, error handling, security, and requested behavior. If intent remains uncertain, keep the behavior and report the uncertainty.

## 3. Clean up and verify

Make the smallest supported cleanup. Prefer deletion to a replacement abstraction; avoid unrelated rewrites and formatting. Run the relevant existing checks and inspect the final diff for behavior changes. Follow project authorization rules for commits, pushes, and other side effects.

## Final report

Use one to three sentences describing what changed, the relevant verification result, and any remaining uncertainty. Do not describe unrun checks as successful.
