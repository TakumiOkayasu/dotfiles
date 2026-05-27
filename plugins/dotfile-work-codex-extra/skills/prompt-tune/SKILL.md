---
name: prompt-tune
description: prompt/skill/agent指示をempirical-prompt-tuningで改善する。 plugin-only運用では @prompt-tune または /skills から起動する。
---

# prompt-tune

empirical-prompt-tuning を使う。scenario と checklist を先に固定し、改善差分は1 iteration 1 themeに限定する。

## Common contract

- 独自 `/prompt:*` と `prompt:*` は使わない。
- rules は作業前に必ず適用する。
- 未確認事項と未実行検証を明示する。
- 破壊的操作、依存追加、DB/API変更、commit/push はユーザー確認を必須にする。
