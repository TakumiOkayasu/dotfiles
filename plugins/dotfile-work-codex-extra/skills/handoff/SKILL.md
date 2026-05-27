---
name: handoff
description: Codex再開用の引き継ぎを作る。 plugin-only運用では @handoff または /skills から起動する。
---

# handoff

Context, Decisions, Tasks, Files, Done when, Risks, Next command を出す。

## Common contract

- 独自 `/prompt:*` と `prompt:*` は使わない。
- rules は作業前に必ず適用する。
- 未確認事項と未実行検証を明示する。
- 破壊的操作、依存追加、DB/API変更、commit/push はユーザー確認を必須にする。
