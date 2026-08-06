# Repository Guidelines

## プロジェクト構成

このリポジトリは Shell/Git/Vim と Claude Code/Codex の個人設定を管理する。
`config/` は通常の dotfiles、`bin/` は `~/.local/bin/` 向け CLI、`claude/` と `codex/` は各ランタイム固有資産を置く。
共有する command/rule/skill は `common/` を正本とし、`scripts/` で Codex 向け生成物と plugin bundle に変換する。
`tests/` には shell テスト、pytest、Docker 定義がある。
`.stow-work/` と `plugins/dotfile-work-codex*` は生成物なので直接編集しない。

## 開発と検証のコマンド

```bash
./install.sh -n
docker compose -f tests/compose.yml run --rm hooks-test
docker compose -f tests/compose.yml run --rm codex-hooks-test
docker compose -f tests/compose.yml run --rm shell-lint-test
docker compose -f tests/compose.yml run --rm install-test
uv run python scripts/verify-codex-plugin.py --repo .
```

`./install.sh -n` は実ホームを変更せず配置予定を確認する。
Docker サービスは hook、CLI、ShellCheck、installer/asset pipeline を分離して検証する。
共有資産を変更した場合は README の generate、port、profile、sync、verify の順で再生成する。

## コーディング規約

Shell は既存の POSIX `sh` を優先し、必要な場合だけ Bash を使う。
Python は4スペース、型注釈、`snake_case` を用いる。
関数は単一責務に保ち、早期 return と具体的な名前を選ぶ。
生成済み view を修正せず、必ず正本と生成スクリプトを直す。

## テスト

変更は失敗する回帰テストから始め、対象テストを通してから関連 Docker サービスを実行する。
pytest は `Test...` クラスと `test_<behavior>` 関数、shell テストは明示的な期待値を使う。
数値の coverage 閾値はないが、変更した配置、削除、再実行、異常入力を検証する。

## AI 駆動開発

作業前に `git status --short`、`README.md`、`codex/rules/RULES_CORE.md`、`RULES_INDEX.md` と該当する full rule を読む。
機能、修正、レビューは plugin skill の `$feat`、`$fix`、`$review` または `$deep-review` から開始する。
リポジトリ内の実装、テスト、生成 manifest を一次ソースとして source から生成物、配置先まで追跡する。
既存差分を戻さず、実行していない検証を成功と報告しない。
完了報告では各検証を `passed`、`failed`、`skipped` に分け、未確認リスクを残す。
モデルの出力は候補として扱い、差分、テスト結果、実行ログで採否を決める。
長い作業では `.codex/progress.md` に目的、判断理由、実行済み検証を残す。
独立した調査だけを、現在の tool contract が許可する場合に subagent へ分け、親が一次ソースで結果を確認する。
モデル名や資産件数を文書へ固定せず、現行設定と manifest を参照する。

## 安全な設定変更

API access token、秘密値、端末固有パスを追跡対象へ入れない。
実ホームを変更する `./install.sh -f` や uninstall の前には dry-run と対象差分を確認する。
commit、push、破壊的操作、依存更新は明示された範囲でだけ実行する。

## コミットと Pull Request

履歴に合わせて `feat(codex): ...`、`fix(shell): ...`、`refactor: ...` のような Conventional Commit を使う。
PR には目的、影響する配置先、正本と生成物、実行したコマンドと結果、関連 issue を記載する。
画面出力が変わる場合だけ比較画像を添付する。
