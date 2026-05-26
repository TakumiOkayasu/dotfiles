---
name: rules-required
codex_port_source: generated
summary: Codex作業前に必須rulesを読み込み、編集前に遵守状態を確認する。
description: 実装・修正・レビュー・設計・調査の前に ~/.codex/rules と project-local rules を必ず読むための運用 skill。rules-inject/rules-guard hooks と連携する。
---

# Rules Required

Codex が rules を「存在するだけ」で守るとは仮定しない。作業前に rules の内容をコンテキストへ入れ、編集前に適用できる状態にする。

## 発動条件

以下のいずれかに該当する場合は必須:

- 実装 / 修正 / リファクタ / テスト追加 / レビュー / 設計
- `/prompt:*` command を使う作業
- `Bash`, `Edit`, `Write`, `MultiEdit`, `apply_patch` を使う可能性がある作業
- rules や AGENTS.md の変更

## 読む対象

優先順:

1. project-local `.codex/rules/*.md`
2. repo-local `codex/rules/*.md`
3. global `~/.codex/rules/*.md`
4. project `AGENTS.md` / `AGENTS.override.md`
5. global `~/.codex/AGENTS.md`

競合時は、より近い project-local 指示を優先し、競合を報告する。

## 実行手順

1. `rules-inject.sh` が full content を注入しているか確認する。
2. 注入済みなら、その内容を読了済み rules として扱う。
3. 未注入なら `codex-rules bundle` または `cat ~/.codex/rules/*.md` 相当で rules を読む。
4. 実装・修正では最低限以下を適用する:
   - `coding-conventions.md`
   - `implementation-policy.md`
   - `hallucination-prevention.md`
   - `hierarchical-architecture.md`
5. 作業完了報告に「適用rules」を1行で記録する。

## 禁止事項

| 禁止 | 理由 |
| --- | --- |
| rules 未読で編集を開始する | project safety 境界が消える |
| rules の存在だけを根拠に「守った」と報告する | 内容未読では遵守不能 |
| rules 競合を黙って都合よく解釈する | 誤った優先順位になる |
| hook が失敗したまま作業を続ける | enforcement が壊れている可能性 |

## hook 連携

- `rules-inject.sh`: UserPromptSubmit / SessionStart で rules full content を注入する。
- `rules-guard.sh`: PreToolUse で rules 未注入・checksum 不一致時の mutating tool を block する。

## 完了報告フォーマット

```text
- 適用rules: coding-conventions / implementation-policy / hallucination-prevention / hierarchical-architecture / project-local rules
- rules確認: full injection checksum <sha> または manual read
```
