# Coding Conventions

<!-- codex-port: managed; source=claude/rules/coding-conventions.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/coding-conventions.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Global and project rules live under `${HOME}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

言語非依存のコード規約。プロジェクト固有の規約があればそれを優先する。

## 比較・制御フロー

- 厳密等価 (`===`, `!==`) を原則とする。緩い比較を使うなら理由を明示する
- boolean は truthy/falsy で評価する。`=== true` / `=== false` は使わない
- 早期リターン (ガード節) でネストを減らす。制御構造のネストは 3 階層まで、超えたら関数抽出
- 早期 return 後の `else` は書かない

## 関数・変数

- 引数は 3-4 個まで。超えたらオブジェクト/構造体にまとめる
- 関数は 30 行を目安に。超えたら分割を検討する
- 1 関数 = 1 責務。副作用のある関数は名前で示す (`saveUser`, `fetchData`)
- 再代入不可の宣言を第一選択にする。可変は必要な場合のみ
- 変数は使用箇所の直前で宣言する
- マジックナンバー・マジック文字列は意味のある定数名にする

## null / Optional

- null 可能性は型で示す (`User | null`, `Optional[User]`)
- 関数冒頭のガード節で早期に null を検出する
- 原則 null ではなく空配列/空オブジェクトを返す。「未取得」と「空結果」を区別する必要がある場合のみ null を許容する

## 型

- 公開 API (関数/メソッドの引数・戻り値) には型注釈を付ける
- `any` は使わない。不明な型は `unknown` / `object` / ジェネリクスにする
- 自明なローカル変数は型推論に任せる (過剰注釈をしない)

## 非同期

- async/await を優先し、Promise chain (`.then`) は避ける
- 独立処理は `Promise.all` で並列化する
- エラーは握り潰さない。意味のある回復・文脈付与・ログができるなら捕捉、できなければ上位へ伝播する

## コメント

- WHY を書く。WHAT は書かない (読めば分かる)
- コメントが必要なら、まず変数名・関数名で表現できないか検討する
- 不要コードはコメントアウトせず削除する (履歴は git で追う)
- docstring は公開 API のみ。内部関数には付けない
- TODO は `TODO(@user): 内容` 形式。プロジェクト既存形式があればそれに従う

## 命名

- 名前は意図 (なぜ存在するか) を表現する。略語を避け、検索可能にする
- ブール値は `is_` / `has_` / `can_` で始める
- 対になる概念は対になる名前にする (open/close, start/stop)
- 曖昧な接頭辞・名前を使わず、具体的な動詞・名詞にする:

| 避ける | 具体化の例 |
| --- | --- |
| `handle*` / `process*` / `do*` / 単独の `execute` | `validateOrder`, `parsePayload`, `sendEmail` |
| `*Helper` / `*Util` | 役割別に分割 (`DateFormatter`, `PathResolver`) |
| `data` / `info` / `item` / `obj` / `temp` | `userRecord`, `invoiceRow`, `parsedConfig` |

例外: フレームワーク規約 (React の `handleClick` 等、イベントを直接受信する関数) は従う。受信内から呼ぶ業務関数は具体名にする。ループ変数・極小スコープ (2-3 行) の `item` / `temp` は許容。目的語付きの `executeQuery` 等は許容。レイヤー役割のサフィックスは `hierarchical-architecture.md` を参照。

## 設計原則

- SOLID に従う
- DRY: 重複を避ける。ただし早すぎる抽象化もしない (3 回繰り返したら抽出)
- KISS / YAGNI: 最も単純な解を選び、現在必要な機能だけ実装する
- ビジネスロジックと I/O、表示ロジックとデータ処理を混在させない

## エラーハンドリング

- fail-fast。不正な状態は早期に検出して即報告する
- バリデーションはシステム境界 (入力受付点) で行う
- 空 catch、`catch (Exception e)` での一括捕捉、例外の制御フロー利用をしない
- 種類別の対応: 業務エラー = ユーザーへ明確なメッセージ / システムエラー = ログ + リトライ・フォールバック / プログラムエラー = バグとして例外を投げる

## ログ

ロガー経由で構造化ログ (キー・バリュー) を出力する。レベル (ERROR/WARN/INFO/DEBUG) を使い分け、コンテキストを付与し、機密情報は含めない。`print` 等の直接使用は `implementation-policy.md` を参照。

## テスト

アサーションは具体値を検証し、振る舞いを実際に判定するテストだけを書く。トートロジー・`toBeDefined()` のみ・カバレッジ稼ぎは書かない。書く前に「何を検証するか」を 1 行で言語化できること。AAA 構造 (Arrange/Act/Assert)、1 テスト 1 概念、テスト間の状態共有・順序依存をなしにする。命名は `should_<expected>_when_<condition>`。詳細は `$tdd` を参照。


## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.
