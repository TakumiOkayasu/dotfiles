---
name: codex-handoff
description: 別セッション・別エージェントへ作業を引き継ぐための Context / Tasks / Files / Done when を生成する。
---

# Codex Handoff

## Purpose

作業の中断、別セッションへの移行、PR説明、次担当への引き継ぎに使う。

## Required content

- 背景
- 目的
- 制約
- 決定済み事項
- 未決事項
- 変更済みファイル
- 参照すべきファイル
- 実行済み検証
- 未実行検証
- 次タスク
- Done when

## Output

```md
🎯 Context
- 背景:
- 目的:
- 制約:
- 決定:
- 未確定:

📌 Tasks
1. [タスク] - [目的] - [注意点]

📁 Files
- 変更:
- 参考:
- 未読:

🧪 Validation
- 実行済み:
- 未実行:
- 失敗:

⚠️ Risks
- ...

✅ Done when
- ...
```

## Rules

- 推測で完了済みにしない。
- 未検証を検証済みと書かない。
- path は repo root からの相対 path で書く。
