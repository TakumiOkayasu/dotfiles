# Coding Conventions

共通のコード指針. project 固有の規約と対象言語の semantics を優先し, 言語・API 固有の項目は対応する runtime だけへ適用する. 数や行数の目安だけを理由に, 現在必要な契約を分割したり wrapper を追加したりしない.

## 比較・制御フロー

- JavaScript / TypeScript では厳密等価 (`===`, `!==`) を原則とする. 他言語ではその言語の型と比較 semantics に従う. 意図的な coercion は理由を示す
- boolean 型は条件として直接評価する. 欠損・空・0 と false を区別する contract では, truthy/falsy でまとめず必要な判定を行う
- 早期 return でネストを減らす. 関数抽出は責務と読みやすさから判断し, nesting の固定段数だけで要求しない
- 早期 return 後の `else` は書かない

## 関数・変数

- 引数は必要な入力を明示する. 同じ概念を表す入力は適切な型にまとめるが, 個数を減らすためだけの object / struct を作らない
- 関数は責務に沿って保つ. 分割は可読性・変更理由・独立した境界から判断し, 行数だけを契機にしない
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
- DRY: 同じ理由で変わる重複を減らす. 抽出は責務と変更の共通性が確認できる場合に行い, 出現回数だけで要求しない
- KISS / YAGNI: 最も単純な解を選び、現在必要な機能だけ実装する
- ビジネスロジックと I/O、表示ロジックとデータ処理を混在させない

## エラーハンドリング

- fail-fast。不正な状態は早期に検出して即報告する
- バリデーションはシステム境界 (入力受付点) で行う
- 空 catch、`catch (Exception e)` での一括捕捉、例外の制御フロー利用をしない
- 業務エラー: ユーザーへ明確なメッセージを返す
- システムエラー: 必要な文脈を付与して上位へ伝播またはログする。retry / fallback は、一時障害等に対する意図された回復動作として要件または既存 contract が要求する場合だけ使う
- プログラムエラー: root cause を修正する。fallback、catch-all、alternate path で症状だけを隠さない

## ログ

運用ログは標準または既存の logger で level と文脈を扱い, project の形式に従う. 機密情報は含めない. CLI の標準出力等の出力契約とは区別する. 具体的な選択は `implementation-policy.md` を参照.

## テスト

アサーションは具体値を検証し、振る舞いを実際に判定するテストだけを書く。トートロジー・`toBeDefined()` のみ・カバレッジ稼ぎは書かない。書く前に「何を検証するか」を 1 行で言語化できること。AAA 構造 (Arrange/Act/Assert)、1 テスト 1 概念、テスト間の状態共有・順序依存をなしにする。命名は `should_<expected>_when_<condition>`。詳細は `${HOME}/.claude/skills/tdd/SKILL.md` を参照。
