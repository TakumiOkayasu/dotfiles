# PROGRESS

## 現在のタスク
- [x] Codex Sub-Agent運用ルール整備 — 目的: 調査・レビュー・検証の並列化をread-only前提で安全に運用する

## 判断ログ
- 2026-05-15: Gitリポジトリとして認識されなかったため、ブランチ作成は省略。理由: `git branch --show-current` が repository 外エラーを返したため。
- 2026-05-15: `max_threads = 4` を採用。理由: PRレビュー観点を security / correctness / tests / maintainability の4系統に分けるため。
- 2026-05-15: `max_depth = 1` を維持。理由: Sub-Agentのネストを禁止し、調査結果の統合責任をmain Agentに固定するため。
- 2026-05-15: `.codex/agents/reviewer.toml` と `.codex/agents/explorer.toml` を追加。理由: read-only範囲、禁止操作、返却形式を毎回プロンプトに書かず参照できるようにするため。
- 2026-05-15: TOML構文をDocker上のPython標準`tomllib`で検証し、`toml ok`を確認。理由: ローカルに`taplo`/`tomlq`が存在しなかったため、固定実行環境としてDockerを使用した。
- 2026-05-15: Agent定義とSpawnプロンプトの本文を日本語化。理由: 運用時に毎回読む内容を日本語で統一するため。設定キーやAgent名などの識別子は互換性維持のため英語のまま残した。

## 完了
- [x] `.codex/config.toml` に `agents.max_threads = 4` と `agents.max_depth = 1` を設定
- [x] `AGENTS.md` にbuild/lint/typecheck/test/review/Sub-Agent運用ルールを明記
- [x] `.codex/agents/reviewer.toml` にPRレビュー用read-only Agent定義を追加
- [x] `.codex/agents/explorer.toml` に調査用read-only Agent定義を追加
- [x] Agent説明・プロンプト本文を日本語化
