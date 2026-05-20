# Claude Code 運用ルール

## 出力

応答は簡潔に。前置き・締めの定型文 (了解 / ありがとう / 以上です 等) は省く。
形式はテーブル・箇条書きを優先し、状態は記号で示す (✅ 完了 / ❌ 失敗 / ⚠️ 注意)。
1 応答あたり 1 万トークン以内を目安とする。

## 🎯 作業フロー

1. `.claude/progress.md` を読む。未完了タスクがあればそこから再開する
2. `git branch --show-current` でブランチを確認する。main の場合は新規ブランチを作成する (→ Git ワークフロー)
3. タスクに対応するスキルを `~/.claude/skills/` から探して読む
4. スキルの手順に従って着手する

## 制約

以下は常時適用される。多くは hook が機械的に enforce する。

| 操作 | 判定 |
| --- | --- |
| git commit / push | 不可 (hook) |
| main ブランチの編集 | 不可 (hook) |
| 素のランタイム直接実行 | 不可 (hook) |
| コマンドの難読化・間接実行 | 不可 (hook) |
| 管理者権限 (sudo 等) | 不可 (hook) |
| 秘密情報のハードコード | 不可 (hook) |
| 単一案での実装 | 不可。最低 2-3 案を提示する |
| スキル未読での実装 | 不可。先に該当スキルを読む |
| 読んでいないファイルの変更 | 不可。先に view する |

加えて、おべっかや根拠のない称賛はしない。反論すべき点は率直に指摘する。

### 秘密情報

パスワード・API キー・トークンをコマンド文字列に平文展開しない。`.env` に記載し環境変数経由で参照する。

| 避ける | 使う |
| --- | --- |
| `curl -u user:password123` | `source .env && curl -u "$USER:$PASS"` |
| `PASS='secret' command` | `.env` に記載し `$PASS` で参照 |

### コマンド難読化

hook を迂回するための難読化・間接実行 (文字列分割 / 変数構築 / base64・hex デコード実行 / curl・wget パイプ / Write+実行 等) は行わない。検知とブロックは hook が担う。

## 実行と検証

素のランタイム (`python3`, `node`, `bun`, `deno`, `php`, `ruby`, `go`, `rustc` 等) の直接実行は、ローカル環境の版ズレで再現性が失われるため行わない。バージョン固定された環境を使う。

| 方式 | 例 |
| --- | --- |
| コンテナ | `docker run --rm`, `docker compose run --rm`, `docker exec` |
| Runner サブコマンド | `npm run <script>`, `npm test`, `poetry run <cmd>`, `cargo (run\|build\|test)`, `./gradlew build`, `mvn test`, `dotnet (run\|build\|test)` |
| バージョンマネージャ | `mise exec`, `uv run`, `pyenv exec`, `asdf exec` |

リンター・型チェッカー・テスト・スクリプトはいずれも上記の方式で実行する。実行方法はプロジェクトの `CLAUDE.md` / `package.json` scripts / `pyproject.toml` / Dockerfile から確認し、指定がなければユーザーに確認する。すべてパスしたことを確認してから完了報告する (未確認での完了報告はしない)。

依存セットアップが未済 (`node_modules` / `.venv` / lockfile 不在 等) の場合は install 系コマンドを実行せず、ユーザーに依存インストールを依頼する。ビルド・テスト系は `run_in_background=true` を推奨。

## 🔧 リソース

`~/.claude/` 配下のリソースを活用し、既存で実現できる処理を自前実装しない。

常時適用の規約は以下を import する (毎セッション自動ロードされる)。

@~/.claude/rules/coding-conventions.md
@~/.claude/rules/implementation-policy.md
@~/.claude/rules/hierarchical-architecture.md
@~/.claude/rules/hallucination-prevention.md

| リソース | 場所 | 用途 |
| --- | --- | --- |
| skills | `~/.claude/skills/` | オンデマンドの作業手順。タスクに応じて読む |
| commands | `~/.claude/commands/` | トリガーワード対応 |
| hooks | `~/.claude/hooks/` | 自動処理 (機械的 enforce) |

skills はタスク着手前に該当するものを確認して読む。

## 🔀 Git ワークフロー

main の場合は新規ブランチを作成してから着手する。

| コマンド | 用途 |
| --- | --- |
| `git-new-feature <名前>` | feat/ |
| `git-new-feature -f <名前>` | fix/ |
| `git-new-feature -d <名前>` | docs/ |
| `git-new-feature -r <名前>` | refactor/ |
| `git-new-feature -c <名前>` | chore/ |
| `git-cleanup-branch` | マージ済みブランチ削除 |

コミットは Conventional Commits に従う (feat / fix / docs / refactor / test / chore)。例: `feat: ログイン機能を追加`。

- 1 ブランチ = 1 機能 = 1 PR。「ついでに」の修正を混ぜない
- 1 コミット = 1 つの論理的変更
- ロックファイル (`package-lock.json`, `poetry.lock` 等) はコミットする
- commit / push は Claude では実行せず、作業完了後にユーザーへ依頼する
- PR マージ確認後は `git-cleanup-branch` でローカルブランチを削除する

## 📋 PROGRESS.md (セッション継続)

`.claude/progress.md` でセッションをまたいだ作業継続と判断履歴を保持する。

| タイミング | 操作 |
| --- | --- |
| タスク着手時 | 「現在のタスク」を更新 |
| 設計判断時 | 「判断ログ」に Why を追記 |
| Plan 確定時 | 実装前に書き出す |
| タスク完了時 | 完了マーク + 次タスクを記載 |
| コンテキスト 70% / 85% | 即更新 |

フォーマット:

```
# PROGRESS

## 現在のタスク
- [ ] タスク名 — 目的: xxx

## 判断ログ
- YYYY-MM-DD: 判断内容。理由: ...

## 完了
- [x] 完了したタスク
```

セッション開始時に読み、未完了タスクがあればそこから再開する。

## 着手前の方針検証 (2 段階)

戦略 → 戦術の順で行う。簡易モードや skip 時はその旨を明示報告する。

### 1. premise-questioning (戦略: 方針自体)

次のいずれかで発動する。

- 100 行以上の変更
- 外部依存の追加・削除
- DB スキーマ / 公開 API I/F の変更
- バグ修正で根本原因に手を入れる
- 「設計レビューして」「方針確認して」と要求された

### 2. feature-pruning (戦術: 個別機能)

premise-questioning で採用後、または次のいずれかで発動する。

- UI 機能リスト 5 個以上
- API エンドポイントの複数新設
- DB テーブルに 5 列以上の新設
- 既存画面 / API の削減レビュー
- 「機能多すぎないか」「これ要るか」と要求された

## ⚙️ 環境

- 文字: UTF-8、半角記号
- 権限: `$(whoami):$(whoami)`

## 💡 原則

- 最小出力、本質のみ
- 推測で実装せず、指示された内容を一次ソースとして実装する
- 言語バージョンは最新の LTS を使う
- sub-agentは必要なら積極的に使用する
