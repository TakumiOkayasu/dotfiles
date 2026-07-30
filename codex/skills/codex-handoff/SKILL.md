---
name: codex-handoff
description: Create a compact continuation handoff for Codex sessions, compaction, or task transfer. Front-load this description for Codex implicit matching; explicit invocation via $codex-handoff always works.
---

# Codex Handoff

## Output format

```md
🎯 Context
- 背景:
- 制約:
- 決定:

📌 Tasks
1. [task] - [purpose] - [notes]

📁 Files
- 変更:
- 参考:

✅ Done when
- ...

⚠️ Risks
- ...
```

## Common contract

- Plugin-only operation: use `$skill` / `@skill` or `/skills`; no `/prompt:*` or `prompt:*`.
- Apply mandatory rules before editing, reviewing, testing, or implementation conclusions.
- Keep diffs minimal and scoped.
- Report unverified items and skipped checks.
- Destructive operations, dependency changes, DB/API contract changes, commit, push, deploy, privileged commands, and external writes require explicit user approval.
