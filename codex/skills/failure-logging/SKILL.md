---
codex_port_source: claude/skills/failure-logging/SKILL.md
name: failure-logging
description: アプローチ失敗時・同じ問題で繰り返しつまずいた時に使用。失敗の履歴を構築し同じ失敗を繰り返さない。コマンドの実行エラーは failure-log フックが自動記録するため、本スキルは判断を要する記録・分析・参照を担当する。「また失敗した」「同じエラーを繰り返す」「前も詰まった」で発動。
---

# Failure Logging

<!-- codex-port: managed; source=claude/skills/failure-logging/SKILL.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/skills/failure-logging/SKILL.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Global and project rules live under `${HOME}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

同じ失敗を繰り返さないための履歴管理。

コマンドの実行エラー (非ゼロ終了) は `failure-log` フックが `codex_tmp/failure_log/auto-fail.log` に自動記録する。本スキルは、フックが捉えられない判断部分 — 概念的な失敗の記録、原因分析、履歴参照、解決マーク — を担当する。

## トリガー条件

- 試したアプローチがうまくいかなかった時 (コマンドエラーに限らない設計・方針レベルの失敗)
- 同じ問題で 2 回以上つまずいた時
- 新しいアプローチを試みる直前
- `@compact` 後の再開時

## 失敗の記録 (判断を要する分)

フックの `auto-fail.log` はコマンドと終了コードしか持たない。重要な失敗は、構造化ログに「何をしようとしたか」「原因」を加えて記録する。

対象ファイル: `codex_tmp/failure_log/[連番範囲]-fail.md` (例: `1-100-fail.md`)。連番は既存ファイルの末尾から継続し、100 件到達で新ファイルを作る。

```markdown
## [連番]
- 何をしようとしたか:
- 試した手法/コマンド:
- 結果 (エラー内容):
- 原因 (明確な場合のみ):
```

原因が不明なときは推測で埋めず空欄にする。

## 履歴参照 (新アプローチの前)

`codex_tmp/failure_log/` の全ファイル (`auto-fail.log` 含む) を列挙し、問題キーワードで関連エントリを検索する。`✅ 解決済み` マークの有無を確認し、過去に失敗した手法を除外してアプローチを選定する。

参照完了時の出力: `📋 履歴確認済み: [件数]件の関連失敗を確認。除外手法: [手法名]`

## 解決時の更新

該当エントリに `✅ 解決済み` をマークし、`- 解決方法:` を追記する。

## アンチパターン

| 禁止 | 理由 |
| --- | --- |
| 履歴を読まずに同じアプローチを試す | 同じ失敗を繰り返す |
| 原因不明時に原因を推測記入する | 誤情報が混入する |
| フォーマットを変更する | 検索・参照が困難になる |
