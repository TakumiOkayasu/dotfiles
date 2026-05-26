# Codex Rules Bundleこのファイルは hook/context injection 用の連結 rules bundle です。直接編集せず、元 rule を編集して再生成してください。
---

## Source: `codex/rules/coding-conventions.md`

# Coding Conventions

<!-- codex-port: managed; source=claude/rules/coding-conventions.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/coding-conventions.md`.
- Codex skills are installed under `~/.agents/skills/<skill>/SKILL.md` by `install.sh`.
- Global and project rules live under `~/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through `/prompt:<name>` or `codex/prompts/commands/<name>.md`.
- Subagent usage must follow `~/.codex/SUBAGENTS.md` and the current Codex tool contract.

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

アサーションは具体値を検証し、振る舞いを実際に判定するテストだけを書く。トートロジー・`toBeDefined()` のみ・カバレッジ稼ぎは書かない。書く前に「何を検証するか」を 1 行で言語化できること。AAA 構造 (Arrange/Act/Assert)、1 テスト 1 概念、テスト間の状態共有・順序依存をなしにする。命名は `should_<expected>_when_<condition>`。詳細は `~/.agents/skills/tdd/SKILL.md` を参照。


## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `~/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.


---

## Source: `codex/rules/hallucination-prevention.md`

# Hallucination Prevention

<!-- codex-port: managed; source=claude/rules/hallucination-prevention.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/hallucination-prevention.md`.
- Codex skills are installed under `~/.agents/skills/<skill>/SKILL.md` by `install.sh`.
- Global and project rules live under `~/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through `/prompt:<name>` or `codex/prompts/commands/<name>.md`.
- Subagent usage must follow `~/.codex/SUBAGENTS.md` and the current Codex tool contract.

「たぶん正しい」で出力しない。不確実なものは不確実と明示する。

## 基本

- 確認済みの情報のみを回答に含める
- 不確実な箇所は `[要確認: <理由>]` マーカーで明示する
- パッケージ・API・引数・戻り値の型・コマンドオプション・設定ファイル名・環境変数名は、公式レジストリ / 公式リファレンスで実在を確認してから使う
- 出典の信頼性は 公式ドキュメント > 査読済み論文 > その他 の順で評価する

## URL の扱い

- 公知の公式ドメイン root とパス断片 (例: `nodejs.org`, `docs.github.com/en/rest/pulls/comments`) は、パッケージ名・API 名と同格の参照先として提示してよい
- フルパス URL (`https://...`) を提示する場合は `[要確認: 実在確認推奨]` を付ける
- WebFetch / 実行ログで実在確認できない URL は提示しない
- コマンド引数中の REST API パス (例: `gh api repos/{owner}/{repo}/pulls/{n}/comments`) はコマンド仕様の一部として扱い、この制限の対象外とする

## 不確実な場合の対処

既定は `[要確認: <理由>]` を付けて出力する。誤情報が致命的、明確な代替が存在する、訂正が必要などのケースでは次を行う:

- 確認できないものは出力しない
- 確実に存在する代替案を提示する
- ユーザーが自分で確認できる手順を案内する
- 間違いに気づいたら影響範囲を説明し、即訂正する


## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `~/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.


---

## Source: `codex/rules/hierarchical-architecture.md`

# Architecture Invariants

<!-- codex-port: managed; source=claude/rules/hierarchical-architecture.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/hierarchical-architecture.md`.
- Codex skills are installed under `~/.agents/skills/<skill>/SKILL.md` by `install.sh`.
- Global and project rules live under `~/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through `/prompt:<name>` or `codex/prompts/commands/<name>.md`.
- Subagent usage must follow `~/.codex/SUBAGENTS.md` and the current Codex tool contract.

アーキテクチャ上、常に守る不変条件。設計の手順・判断は `architecture-design` スキルを参照する。

## 依存方向

- 依存は上位→下位の一方向のみ。下位→上位の依存をしない
- 横参照 (同一レイヤー間の直接参照) をしない
- 段階飛ばしのアクセスをしない (中間レイヤーを必ず経由する)
- 上位は指示のみ。下位の内部操作を代行しない

## 合成と継承

- 継承より合成を優先する。能力・振る舞いの差分はコンストラクタ注入で合成する
- 継承深度は 2 段まで
- 具象クラスではなくインターフェースに依存する (DI)

## インターフェース

- インターフェースは単一責任。薄く保つ (必要最小限のメソッドのみ)
- 入力と出力は論理的責務で分離する

## 命名

レイヤー役割をサフィックスで表す。

| 役割 | サフィックス |
| --- | --- |
| 管理 (下位のライフサイクルを持つ) | `*Context`, `*Manager` |
| 提供 (同種能力を束ねる) | `*Provider`, `*Registry` |
| 操作 (特定リソースに直接アクセス) | `*Accessor`, `*Client` |

`*Service` / `*Repository` / `*Handler` 等は、責務が管理/提供/操作のいずれかに一致すれば許容する。

## 入力の境界

アプリケーションコードは `Intent` (意図レベルのデータ) のみに依存し、`Raw Input` (引数・パス文字列等の生データ) を直接扱わない。


## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `~/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.


---

## Source: `codex/rules/implementation-policy.md`

# Implementation Policy

<!-- codex-port: managed; source=claude/rules/implementation-policy.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/implementation-policy.md`.
- Codex skills are installed under `~/.agents/skills/<skill>/SKILL.md` by `install.sh`.
- Global and project rules live under `~/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through `/prompt:<name>` or `codex/prompts/commands/<name>.md`.
- Subagent usage must follow `~/.codex/SUBAGENTS.md` and the current Codex tool contract.

車輪の再発明をしない。技術選定・ライブラリ利用・データアクセスの方針。

## 基本

- 標準ライブラリ / 定評 OSS / 採用済みフレームワークで解決できるなら自前実装しない
- 自前実装するなら「なぜ既存で不可か」を明示して承認を得る
- 汎用ユーティリティ (配列・オブジェクト操作, 日時, UUID, 乱数, エンコード, 正規表現) は再発明しない
- 実行時計算量は**最悪でも** `線形 / 線形対数`で終わらせる

## 依存管理

- 新規ライブラリ追加前に、既存依存で代替できないか確認する
- 選定基準: 利用実績 + メンテ状況 (6 ヶ月以内コミット) + ライセンス (MIT/Apache/BSD 系)
- lockfile は必ずコミットする。`latest` / ワイルドカード指定はしない
- 依存の追加・更新時に脆弱性スキャン (npm audit, pip-audit 等) を実行する

## 必須経由 (自前実装・直接操作をしない領域)

| 領域 | 方針 |
| --- | --- |
| DB アクセス | ORM 経由を原則とする (生 SQL の例外は後述) |
| スキーマ変更 | マイグレーションツール経由。本番 DDL の直接実行をしない |
| ロギング | 本番コードはロギングライブラリ経由。`print` / `console.log` / `echo` を直接使わない (使い捨てスクリプトは対象外) |
| バリデーション | 定評ライブラリ (zod / pydantic / joi / valibot 等)。自前 if 羅列をしない |
| 暗号・ハッシュ | 自前実装をしない。言語標準または定評ライブラリのみ。アルゴリズムは公式推奨に従う |
| HTTP クライアント | プロジェクト内で 1 つに統一する |
| 設定値 | 環境変数または設定ファイルで外部化する。ハードコードしない |

## 生 SQL を許可するシナリオ

次の場合のみ生 SQL を許可する。いずれもプリペアドステートメント必須、理由を PR 本文・コメントに記載、レビュー対象として明示する。

- バルク処理: パフォーマンス計測結果を根拠に示す
- 複雑な集計 (CTE / window 関数): ORM で表現困難なことを示す
- DB 固有機能: 移植性を捨てる判断を明示する
- 読み取り専用レポート: ビュー定義または生 SQL、レビュー必須


## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `~/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.

