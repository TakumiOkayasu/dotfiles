# Opus 4.7 Policy

<!-- codex-port: managed; source=claude/rules/opus-47-policy.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/opus-47-policy.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Global and project rules live under `${HOME}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

Codex Opus 4.7 の以下強化点を運用に反映する:

- 計画段階での self-checking 能力向上
- `xhigh` thinking レベル追加と Adaptive thinking
- ファイルシステムベースのメモリ強化
- 長時間 / マルチステップタスクの信頼性向上

本ポリシーは `${HOME}/.codex/rules/` 配下にあるため、AGENTS.md の `@import` 経由で常時適用される。premise-questioning / feature-pruning より**軽量・常時適用**。

## 🧠 Thinking Budget Policy

タスク性質に応じて推論深度を引き上げる。Codex 内では `think` 系キーワードを内省的に発動する (公式推奨)。

| タスク性質 | 推論レベル | キーワード例 |
| --- | --- | --- |
| 軽量編集・typo・単純な置換 | default | (即実装) |
| 複数ファイル変更・新機能追加・設計判断 | high | `think` |
| 難解なバグ・並行処理・型パズル | xhigh | `think hard` |
| アーキテクチャ設計・セキュリティ監査・長時間エージェント | max | `ultrathink` |

判定が曖昧な場合は**1 段上**を選ぶ。軽量で済むタスクに重いレベルを当てるコストより、難問を軽量で誤る損失の方が大きい。

## ✅ Self-Review Gate (常時)

実装着手前に**必ず**以下を内省する。No が 1 つでもあれば 1 段上の thinking レベルで再検討する。

| # | 自問 |
| --- | --- |
| 1 | 入出力の型と契約を 1 文で言えるか |
| 2 | エッジケースを 3 つ以上挙げられるか |
| 3 | 既存パターン (skills / rules) と整合するか |
| 4 | テスト可能な単位に分割されているか |
| 5 | 失敗した場合の rollback 手順があるか |

本 gate は premise-questioning / feature-pruning の**前段**に位置する常時適用ゲート。100 行未満の変更にも適用する。重い検証への昇格条件は AGENTS.md「着手前の方針検証」節を参照。

## 📂 File-System Memory (3 層構造)

長時間 / マルチセッションタスクの継続性を担保するため、以下 3 層で運用する。

```text
.codex/
├── progress.md       # 主帳簿 (既存)
├── notes/            # 詳細メモ (新規)
│   └── {task-id}.md
└── scratch/          # 試行錯誤 (新規、gitignore)
    └── {task-id}.md
```

| 層 | 用途 | git 管理 | 更新頻度 |
| --- | --- | --- | --- |
| `progress.md` | タスク履歴・判断ログ・完了状況 | ✅ | 着手時 / 判断時 / 完了時 |
| `notes/{task-id}.md` | 長時間タスクの調査結果・参考リンク・中間成果 | ✅ | セッション中随時 |
| `scratch/{task-id}.md` | REPL 風メモ・没アイデア・実験コード | ❌ (gitignore) | 自由 |

### 規約

- `{task-id}` はブランチ名と一致させる (例: `feat/login-form` → `feat-login-form.md`)
- セッション開始時、対応する `notes/{task-id}.md` が存在すれば**必ず** read する
- タスク完了時、`notes/` の要点を `progress.md` の「判断ログ」へ要約反映する
- `scratch/` は `.gitignore` 必須。コミットしない
- 新規ディレクトリ作成時は `.codex/notes/.gitkeep` を置く

### Adaptive thinking との連携

`notes/` を読み戻すことで前提コンテキストの量を減らせるため、その分の thinking budget を実装側に振り向けられる。長時間タスクではこれを意識する。

### failure-logging との接続

`failure-logging` skill は試した内容と失敗理由を **`.codex/notes/{task-id}.md` の `## failure-log` セクション**へ追記する。これにより:

- 失敗履歴と決定事項・調査メモが**同一ファイルに集約**される
- SessionStart hook で失敗履歴も自動 read され、4.7 のファイルメモリ強化で「同じ失敗を繰り返さない」が機械的に支援される
- `systematic-debugging` skill の「失敗パターン」節 (「試した内容と失敗理由は failure-logging スキルで記録する」) と整合する

#### failure-log エントリのフォーマット

```markdown
### YYYY-MM-DD HH:MM
- 試したこと: (1 文で)
- 結果: 失敗 (エラーメッセージは原文引用)
- 理由: (根本原因。推測なら推測と明示)
- 次に試すこと: (1 文で)
```

#### 書き込み先の決定

- 通常は `.codex/notes/{task-id}.md` の `## failure-log` セクションへ追記
- notes ファイルが未作成なら `_template.md` をコピーして作成してから追記
- task-id (ブランチ名 → ハイフン置換) は `git branch --show-current | tr '/' '-'` で取得

## 🔄 削除・整理

- マージ済みブランチに対応する `notes/{task-id}.md` は `git-cleanup-branch` 時に `notes/archive/` へ移動する
- `scratch/` は 30 日以上更新のないファイルを自由に削除可


## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.
