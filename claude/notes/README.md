# notes/

長時間・マルチセッションタスクの詳細メモを保持する。`{task-id}.md` 形式で 1 タスク 1 ファイル。

詳細規約: `~/.claude/rules/opus-47-policy.md` の「File-System Memory」セクション。

## 命名規約

ファイル名 = ブランチ名のスラッシュをハイフンに置換 (例: `feat/login-form` → `feat-login-form.md`)。

新規タスク開始時:

```bash
cp .claude/notes/_template.md ".claude/notes/$(git branch --show-current | tr '/' '-').md"
```

## 運用

| タイミング | 操作 |
| --- | --- |
| タスク着手時 | テンプレートをコピー、目的・背景を記入 |
| セッション開始時 | SessionStart hook が自動 read |
| 設計判断時 | 「決定事項」セクションに 1 行追加 |
| subagent 利用時 | 「subagent 出力」セクションに集約 |
| 失敗時 | 「failure-log」セクションに記録 (failure-logging skill 連携) |
| タスク完了時 | 「完了時の要約」を progress.md へ反映 |
| ブランチクリーンアップ時 | PostToolUse hook が自動アーカイブ (`notes/archive/` へ移動) |

## ディレクトリ構造

```
.claude/notes/
├── _template.md         # 雛形 (コピー元)
├── {task-id}.md         # 進行中タスクの詳細メモ
└── archive/             # マージ済みタスクのアーカイブ
    └── {task-id}.md
```
