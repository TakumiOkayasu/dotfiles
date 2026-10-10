# Session Memory Policy

長時間 / マルチセッションタスクの継続性を、ファイルシステム上の 3 層で担保する。

このruleはruntime固有の作業状態を扱う。以下の `.claude/` と `claude_tmp/` は、対象runtime向けviewの生成時に対応するpathへ変換される。
これらはGit管理対象外であり、再利用する知識だけを `knowledge-reuse` に従って `.ai/inbox/` へ候補として残す。
durable knowledgeの所有権、昇格、exportは `project-ai-knowledge.md` を正本とする。既存のruntime stateを自動移動しない。

## 📂 File-System Memory (3 層構造)

```text
.claude/
├── progress.md       # タスクの継続状態
├── notes/            # 必要な調査・判断の詳細
│   └── {task-id}.md
└── scratch/          # 試行錯誤 (新規、gitignore)
    └── {task-id}.md
```

| 層 | 用途 | git 管理 | 更新頻度 |
| --- | --- | --- | --- |
| `progress.md` | タスク履歴・判断ログ・完了状況 | ❌ (runtime state) | 着手時 / 判断時 / 完了時 |
| `notes/{task-id}.md` | 長時間タスクの調査結果・参考リンク・中間成果 | ❌ (runtime state) | セッション中随時 |
| `scratch/{task-id}.md` | REPL 風メモ・没アイデア・実験コード | ❌ (gitignore) | 自由 |

### 規約

- `{task-id}` はブランチ名と一致させる (例: `feat/login-form` → `feat-login-form.md`)
- セッション開始時、対応する `notes/{task-id}.md` が存在すれば**必ず** read する
- タスク完了時、`notes/` の要点を `progress.md` の「判断ログ」へ要約反映する
- `scratch/` は `.gitignore` 必須。コミットしない
- 新規ディレクトリ作成時は `.claude/notes/.gitkeep` を置く

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

失敗記録の保存先とschemaは `failure-logging` skillを正本とする。

- `failure-log` hookが登録されている場合だけ、コマンド失敗が `claude_tmp/failure_log/auto-fail.log` へ自動捕捉される。hook登録が無いruntimeでは自動捕捉を前提にしない。
- 判断を伴う構造化記録は `claude_tmp/failure_log/[連番範囲]-fail.md` に置く。
- `.claude/notes/{task-id}.md` の `## failure-log` は、継続に必要な失敗の要点を任意にまとめる領域であり、skillの正式な書き込み先ではない。
- SessionStartのnotes loaderが登録されている場合は対応するnotesを読む。scratchの失敗ログ全体を自動注入することはない。

#### notesへ要約する場合のフォーマット

```markdown
### YYYY-MM-DD HH:MM
- 試したこと: (1 文で)
- 結果: 失敗 (エラーメッセージは原文引用)
- 理由: (根本原因。推測なら推測と明示)
- 次に試すこと: (1 文で)
```

## 🔄 削除・整理

- マージ済みブランチに対応する `notes/{task-id}.md` は `git-cleanup-branch` 時に `notes/archive/` へ移動する
- `scratch/` は 30 日以上更新のないファイルを自由に削除可
