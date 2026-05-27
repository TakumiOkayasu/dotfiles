---
name: rules
description: 今回の作業に適用するrulesを読み、遵守計画を作る。 plugin-only運用では @rules または /skills から起動する。
---

# rules

rules-required を適用し、今回の作業に関係する rules、競合、遵守チェックリストを出す。

## Common contract

- 独自 `/prompt:*` と `prompt:*` は使わない。
- rules は作業前に必ず適用する。
- 未確認事項と未実行検証を明示する。
- 破壊的操作、依存追加、DB/API変更、commit/push はユーザー確認を必須にする。
