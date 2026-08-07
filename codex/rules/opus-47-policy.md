# Session Memory Policy

<!-- codex-port: managed; source=common/rules/opus-47-policy.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/rules/opus-47-policy.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

長時間 / マルチセッションタスクの継続性を、ファイルシステム上の 3 層で担保する。

## 📂 File-System Memory (3 層構造)

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

### progress.md のフォーマット

```markdown
# PROGRESS

## 現在のタスク
- [ ] タスク名 — 目的: xxx

## 判断ログ
- YYYY-MM-DD: 判断内容。理由: ...

## 完了
- [x] 完了したタスク (最新 5 件のみ)

## 既読ファイル (セッション内)
- path/to/file (read: HH:MM)
```

`## 完了` は最新 5 件のみ残す。古い分は `progress-archive.md` へ YYYY-MM-DD ヘッダ付きで追記する。`progress-archive.md` はセッション開始時に読まない。

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

This rule applies when selected through `RULES_INDEX.md` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the runtime instruction hierarchy and report the conflict.
