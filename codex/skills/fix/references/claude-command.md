# バグ修正ガイド

<!-- codex-port: managed; source=common/commands/fix.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/commands/fix.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

バグを修正する(再現→原因特定→TDD修正)

## 引数

ユーザー指定の対象 にバグの現象・状況が渡されます。

## 入出力

| 項目 | 内容 |
| ------ | ------ |
| 入力 | `ユーザー指定の対象`: バグの現象・状況（例: "ログイン時にNullPointerExceptionが発生する"） |
| 出力 | 修正サマリー（原因・修正内容・変更ファイル一覧・再発防止策） |

## 実行手順

### Phase 0: スキル読み込み

- **実装スキル** (Phase 1 以降で活用):
  - `$tdd`
  - `$systematic-debugging`
  - `$optimize`
- **方針検証スキル**: Phase 2.5 で発動条件に該当した場合に `$premise-questioning` を読み込む (利用直前に読む)

### Phase 1: 現象確認

- バグの症状の画面上での確認、ログの確認 + 正確に記録
- 再現手順の確立(100%再現可能にする)
- エラーメッセージ・ログの収集
- 再現できなければ修正提案禁止

### Phase 2: 根本原因分析

- **読み込んだスキルを活用** (Phase 2 は `systematic-debugging` が主、`TDD` は Phase 3 以降で主)
- `systematic-debugging` skill の 4 フェーズを順に実施:
  1. **再現** — Phase 1 の再現手順が成立していることを確認
  2. **境界トレース** — どの層 (クライアント / API / Service / DB / 環境) で問題が発生しているか特定
  3. **特定** — 「なぜ?」を **5 回以上**繰り返して**根本原因を掘り下げる**
  4. **仮説** — 根本原因の候補を複数列挙し、各候補の検証方法を併記する
- 根本原因が複数仮説に分かれた場合、または 3 ファイル以上にまたがる場合は **`debugger` subagent に dispatch する** (仮説生成・検証・最小修正まで担う。起動後は結果を `.codex/notes/{task-id}.md` へ集約し、Phase 3 の RED テスト作成へ進む)
- 実コードを読まずに推測で決定しない (**一次ソース確認必須**)
- **推測での修正禁止。根本原因と修正方針をユーザーに報告し、承認を得てから Phase 3 へ**
  - 承認の定義: ユーザーから明示的な OK（「承認」「このまま進めて」等の文言）が返るまで Phase 3 に進まない。**自己承認・暗黙の承認は禁止**
  - 情報不足時は `## 承認要求` 節に **確認項目を箇条書きで列挙** して提示する (推測で埋めない)

### Phase 2.5: 方針検証 (Phase 3 前に判定)

Taskのscopeとriskを確認し,該当するskill descriptionに従う。Phase 2 で確定した修正方針が以下のいずれかに該当する場合は **premise-questioning skill のワークフロー全体を実行**し、✅ 採用判定が出るまで Phase 3 へ進まない:

- 根本原因の修正がアーキテクチャ変更を伴う
- 公開 API I/F 変更を伴う
- DB スキーマ変更を伴う
- 100 行以上の変更見込み
- 外部依存 (ライブラリ / API / SDK) の追加・削除を伴う

該当しない局所修正 (null チェック追加 / 境界値修正 / typo 等) の場合は `premise-questioning: skipped (理由: 局所修正)` を 1 行明示してスキップ。

feature-pruning は通常不要 (機能追加でないため)。既存機能の削減を伴う場合のみ起動。

### Phase 3: 失敗テスト作成 (RED)

- バグを再現するテストを書く
- テストが失敗することを確認(バグの証明)
- リグレッション防止のためのテストも検討
- qa_nightmare を**必ず**使用して嫌なテストを作成

### Phase 4: 修正 (GREEN)

- 根本原因に対する最小限の修正
- 対症療法禁止(根本原因を直す)
- 全テストが通ることを確認

### Phase 5: リグレッション確認・報告

- 既存テストが全て通ることを確認
- 修正サマリー(原因・修正内容・変更ファイル)を出力
- 再発防止策の提案(あれば)

## 使用例

```text
$fix ログイン時に特定ユーザーのみ500エラーが返る
$fix テスト実行時に test_foo が NullPointerException で落ちる
```
