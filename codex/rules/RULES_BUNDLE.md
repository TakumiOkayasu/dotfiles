# Codex Rules Bundle

このファイルは参照・検証用の連結 rules bundle です。直接編集せず、元 rule を編集して再生成してください。

---

## Source: `codex/rules/RULES_CORE.md`

# RULES_CORE

These are the short, always-on invariants for dotfile-work Codex.

## Priority

1. User instruction
2. Nearest project `AGENTS.md`
3. Plugin/project markdown rules
4. Active skill workflow
5. General best practice

When instructions conflict, follow the higher-priority source and report the conflict.

## Mandatory behavior

- Read and apply the full applicable rules before editing files, running mutating commands, reviewing code, or giving implementation conclusions.
- Do not edit unread files.
- Do not overwrite user changes or unrelated diffs.
- Do not run destructive commands, dependency changes, DB/API changes, `sudo`, commit, push, deploy, or external writes without explicit user approval.
- Prefer existing project conventions, pinned tool versions, and project-defined test/lint/build commands.
- Do not invent APIs, options, packages, paths, environment variables, schemas, or test results. Verify or mark `[要確認: reason]`.
- Report verification honestly: passed, failed, skipped with reason, and remaining risk.

## Routing

- Feature implementation -> `$feat` -> `tdd` and design skills only when needed.
- Bug/failing test -> `$fix` -> `systematic-debugging` before patching.
- Review -> `$review` or `$deep-review`.
- Rule uncertainty -> `$rules-required`.

## High-risk triggers

Treat as high-risk: DB schema, public API/SDK/CLI contract, auth/authorization, secrets, payments, dependency add/remove/update, data migration/destructive change, 100+ changed lines, multiple services, or unclear requirements.

---

## Source: `codex/rules/coding-conventions.md`

# Coding Conventions

<!-- codex-port: managed; source=common/rules/coding-conventions.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/rules/coding-conventions.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
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

This rule applies when selected through `RULES_INDEX.md` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the runtime instruction hierarchy and report the conflict.

---

## Source: `codex/rules/contract-driven-object-collaboration.md`

# Contract-Driven Object Collaboration

<!-- codex-port: managed; source=common/rules/contract-driven-object-collaboration.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/rules/contract-driven-object-collaboration.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

ソフトウェアを実装やデータ表現ではなく、理想的な役割を持つオブジェクト間の協調として設計するための不変条件。
実装は契約へ追随し、契約を既存実装から逆算しない。

## 設計順序

1. 利用目的を定義する
2. 必要な役割を抽出する
3. 役割間の理想的な協調を定義する
4. 協調に必要な最小契約を定義する
5. 契約だけでユースケースが成立するか確認する
6. 最後に具体実装を割り当てて構成する

次の逆方向は禁止する。

```text
実装 / フレームワーク / 外部仕様 / 保存形式
  -> 扱いやすいデータ構造
  -> 契約を後付け
```

## オブジェクトの独立性

- 各オブジェクトは、協調相手が内部的にどのような状態・値・表現を持つかを知らないし、知る必要もない
- 協調相手の内部状態を取得して呼び出し側で解釈・分岐するより、必要な能力を契約として要求する
- 契約に存在しない操作を行うために具象実装へ変換・キャストしない。必要なら契約不足または責務配置を見直す
- 実装内部の正規化、識別方法、等価性、キャッシュ、シリアライズ、永続化方式は契約へ漏らさない

## 契約

- 契約は実装の形ではなく、理想上の役割・意味・操作を定義する
- ドメイン上の契約は、原則として別のドメイン契約を受け取り、別のドメイン契約を返す
- `string`、数値、日時、パス、URI、バイト列、JSONなどの実装表現を、便利だからという理由でドメイン契約へ露出しない
- primitiveや外部表現が実装内部に存在することは問題ではない。外部境界で必要になった時だけ具体表現へ変換する
- `Value`、`Raw`、`Code`、`Index`等を公開し、呼び出し側に内部表現の解釈を委ねる抜け道を作らない
- 状態一覧を公開するだけのDTO的契約ではなく、現在必要な協調を表す契約にする
- 1つの役割が複数の独立能力を持つ場合は、小さな契約を複数満たす形を優先する
- 将来の可能性だけを理由に契約やメンバーを追加しない

## 実世界と理想世界

外部・実世界の概念と、アプリケーションが理想的に扱う概念を同一視しない。

例:

```text
実入力 != 仮想入力
実コントロール != 仮想コントロール
外部プラグイン != 内部プラグイン
外部プロファイル != 内部プロファイル
```

両者の差異を埋める処理が必要になった場合、それは実装時に具体的差異が判明した結果として配置する。
設計段階で特定製品・プロトコル・保存形式を前提にAdapter等を先回りして作らない。

## 責務分離

異なる責務を1つのオブジェクトへ混ぜない。特に次を独立させる。

- データ取得とレンダリング
- インポートと実行
- 入力の解釈とAction実行
- 外部形式の解釈と内部ドメインの利用
- 永続化とドメイン上の操作

データ取得側は表示方法を知らず、レンダリング側は取得方法を知らない。
Importerは外部資産を内部契約へ解釈するだけで、取り込み中に対象コードを実行しない。

## DIとの関係

DIを目的にinterfaceを作らない。

```text
理想的な役割と協調
  -> 契約
  -> 契約に追随する実装
  -> 実装を選択して構成
  -> 結果としてDI
```

DIコンテナ、コンストラクタ注入、Factory等は実装・構成手段であり、この設計手法の起点ではない。

## YAGNI / KISS

YAGNI/KISSは次を削るために使う。

- 現在不要な契約メンバー
- 将来予測だけの拡張機構
- 不要な継承・レジストリ・動的探索
- 現在の協調に不要な層や抽象化

現在の利用側を実装表現から切り離すために必要な契約を、primitiveで代用する理由にはしない。

## トラブルシューティング

設計・実装・レビューで問題が起きたら、次の順で確認する。

1. 呼び出し側が相手から値を取り出して意味を解釈・分岐していないか
2. 契約からprimitive、外部形式、フレームワーク固有型が漏れていないか
3. 具体製品、通信方式、保存形式等がコア契約へ入り込んでいないか
4. 取得と描画、取込と実行など異なる責務を混ぜていないか
5. 種別値や具象型を見て`if`/`switch`する代わりに、能力契約で協調できないか
6. 「この実装ならこうだから」を理由に契約を変更していないか
7. 契約にない操作を具象型へ変換して呼んでいないか
8. 抽象化が現在のユースケースではなく将来予測のためだけに存在していないか

代表的な症状と最初に疑う箇所:

| 症状 | 疑う箇所 |
| --- | --- |
| 新しい実装を追加するたび既存の条件分岐が増える | 能力契約不足、状態照会 |
| ある実装だけ特別扱いが必要 | 理想契約と実装詳細の混在 |
| Renderer変更で取得処理まで変わる | 責務混在 |
| 外部形式変更でコアロジックが壊れる | 外部表現漏洩 |
| Mockに大量の内部値設定が必要 | 状態漏洩、DTO的契約 |
| castしないと必要な操作が呼べない | 契約不足または責務配置違反 |
| DI設定だけが複雑化する | 抽象化過多、契約境界不良 |

## レビュー時の5問

1. この契約は、実装ではなく理想的な役割と協調から作られているか
2. 呼び出し側は、相手の内部状態・内部表現を取得して判断していないか
3. 必要な操作は契約として表現され、その契約だけで処理できるか
4. 異なる責務、または実世界と理想世界を混同していないか
5. 現在必要でない抽象化を追加していないか

## 適用範囲

新規設計だけでなく、機能追加、バグ修正、リファクタリング、レビュー、トラブルシューティングでも適用する。
既存コードにこの原則と異なる構造がある場合、変更範囲外まで無条件に全面改修せず、今回の変更が新たな違反を増やさない最小の改善境界を選ぶ。

## Codex rule loading

This rule applies when selected through `RULES_INDEX.md` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the runtime instruction hierarchy and report the conflict.

---

## Source: `codex/rules/hallucination-prevention.md`

# Hallucination Prevention

<!-- codex-port: managed; source=common/rules/hallucination-prevention.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/rules/hallucination-prevention.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

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

This rule applies when selected through `RULES_INDEX.md` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the runtime instruction hierarchy and report the conflict.

---

## Source: `codex/rules/hierarchical-architecture.md`

# Architecture Invariants

<!-- codex-port: managed; source=common/rules/hierarchical-architecture.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/rules/hierarchical-architecture.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

アーキテクチャ上、常に守る不変条件。理想契約とオブジェクト協調の原則は `contract-driven-object-collaboration`、設計の手順・判断は `arch` スキルを参照する。

## 依存方向

- 依存は上位→下位の一方向のみ。下位→上位の依存をしない
- 横参照 (同一レイヤー間の直接参照) をしない
- 段階飛ばしのアクセスをしない (中間レイヤーを必ず経由する)
- 上位は指示のみ。下位の内部操作を代行しない

## 契約と構成

- 実装やデータ構造から契約を逆算せず、利用目的・役割・協調から理想契約を先に定義する
- 具象実装ではなく契約に依存する。実装は契約へ追随する
- 各オブジェクトは他の実装や内部状態を知らず、契約に定義された操作だけで協調する
- 実装の選択・組み合わせは構成点で行う。DI はこの構成の結果であり、契約設計の起点にしない
- コンストラクタ注入、Factory、DI container 等の具体方式は、実装時に必要な最小手段を選ぶ

## 合成と継承

- 継承より合成を優先する
- 独立した能力・振る舞いは小さな契約として分離し、必要なオブジェクトが複数の契約を満たす
- 継承深度は 2 段まで

## インターフェース / 契約

- 契約は単一責任。現在必要な操作だけに保つ
- ドメイン契約から primitive、外部形式、フレームワーク固有型を漏らさない
- 状態や種別を取得して呼び出し側で分岐するより、必要な能力を契約として表現する
- 入力と出力、取得と描画、取込と実行など異なる論理責務を分離する

## 命名

レイヤー役割をサフィックスで表す。

| 役割 | サフィックス |
| --- | --- |
| 管理 (下位のライフサイクルを持つ) | `*Context`, `*Manager` |
| 提供 (同種能力を束ねる) | `*Provider`, `*Registry` |
| 操作 (特定リソースに直接アクセス) | `*Accessor`, `*Client` |

`*Service` / `*Repository` / `*Handler` 等は、責務が管理/提供/操作のいずれかに一致すれば許容する。

## 入力の境界

外部の生データや外部形式をアプリケーションの理想契約として扱わない。
外部表現から内部の理想入力へ変換する具体方式は実装側へ閉じ込め、アプリケーションコードは理想入力の契約だけに依存する。

## Codex rule loading

This rule applies when selected through `RULES_INDEX.md` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the runtime instruction hierarchy and report the conflict.

---

## Source: `codex/rules/implementation-policy.md`

# Implementation Policy

<!-- codex-port: managed; source=common/rules/implementation-policy.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/rules/implementation-policy.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

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

This rule applies when selected through `RULES_INDEX.md` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the runtime instruction hierarchy and report the conflict.

---

## Source: `codex/rules/natural-japanese.md`

# Natural Japanese

<!-- codex-port: managed; source=common/rules/natural-japanese.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/rules/natural-japanese.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

あなたの日本語は AI だと簡単に分かる。表層の癖を消すだけでなく、論証に穴を残さない。書き上げたら本ルールで点検する。

## 前提

人は怠惰なので、できるだけ簡単な書き方/言い回し/変換を選ぶ。まずこれを念頭に置く。

## 記号と整形

- 日本語は助詞が要なので、助詞を省略しない。
- ダッシュ (em ダッシュ —、horizontal bar ―、いわゆる2倍ダッシュ ——) を地の文/見出しで使わない。同格/補足の挿入は丸括弧 () に、言い換えは句点で二文に分けるか読点でつなぐ。範囲を示す en ダッシュ – や英語の複合語 (Curry–Howard など)、コードブロック/書誌情報は対象外。
- 中黒 (・) を並列で使わない。/ (スラッシュ) に置き換える。単一の固有名詞の内部では使ってよい。
- 引用/通称はダブルクォート "" を使う。かぎかっこ 「」 は使わない。"" も多用しない。
- 太字 (`**`) による強調を使わない。際立たせたい語は文の順序と構造で立たせる。
- 見出しに区切り線 (罫線 ─ やダッシュ類) で "種別──主題" のように二要素を詰め込まない。見出しは単一の自然な句にする。
- 段落番号/見出し番号をハードコードしない (`1.` や `## 1.` `### 1.1` を振らない)。後の編集で順番や増減が起きてずれるため、標準のリスト記法で書く。
- アスキーアートで構造を描かない。人間はまず書かない。図が要るなら mermaid などコードで図を表記できる手段を使う。
- 既出の語をカッコで言い換え補足するのは冗長。"共通化 (抽象化)" のような並べ方をしない。ただし指示対象が一意に決まらないときに、丸括弧の同格挿入でその場で特定するのは可。
- 文書/原稿を書くときは一文ごとに改行し、段落の区切りを空行で示す。コード/差分/ログ/設定の断片はコードブロックに入れる。本筋から一段外れる補足は本文に並べず脚注に降ろす。(会話の応答までは一文改行しなくてよい)
- 用語とその定義を並べるときは、区切り線ではなく全角コロンで "用語: 説明" と書く。

## 段落と論証の構成

パラグラフライティングを基本とする。段落は論証の一歩で、読者は段落単位で論理を追えなければならない。

- 一つの段落に一つのトピックだけ置く。調査/報告/検証/評価が混ざった長い段落は一歩ずつに分割する。
- 段落の最初の文を読めば、その段落が何の話か分かるようにする。
- 段落の先頭で、前の段落との論理関係を接続表現で示す (であれば/実際/しかし)。
- 論証は一方向に進める。結論を出してから反論を処理し結論を言い直す構成にしない。疑念の処理を終えてから結論を一度だけ置く。
- 読者が立てそうな誤った解釈は、明示的に否定してから本当の理由を述べる。
- "A ではなく B" と否定するときは、否定の根拠を一文添える。反実仮想 (もし A なら〜だっただろう) が使えることが多い。
- 譲歩 (確かに〜) では事実の確認にとどめる。あとで訂正する内容を著者の声で因果として断定すると自己矛盾になる。
- 山場で効かせたい情報 (数値/固有の事実) を、その手前の段落で先出ししない。
- 何かを否定/限定するときは、否定する命題そのものを正確に書き出す。"何もかもが解決するわけではない" のような漠然とした否定で済ませない。
- "後の章で扱う" のような前方参照は、論証が一段落した位置 (段落末/節末) に置く。途中に挟んで流れを切らない。

## 論証の厳密さ

文章の論理にツッコミどころを残さない。読み手の反論を先回りして点検する。

- 推量/可能性/疑念/反実仮想として書かれた文を、機械的に断定へ変えない。"かもしれない" "だろう" は根拠なく主張を弱めている場合だけ削る。事実未確認の可能性や読者が抱きそうな疑念を表す場合は、その不確実性を保つ。断定に直せるのは本文内の根拠で命題が確定している場合に限る。
- 異なるものを "同じ" とまとめない。区別すべき対象 (別々の決定/別々の原因/種類の違う問題) を一括りにしない。
- 複数の要因がある事象を単一の原因に還元しない。例が複数種類の問題を含むなら切り分け、どの道具がどれを説明するか対応づける。
- 章/節をまたいで同じ概念の扱いを一致させる。ある節で "人間が決める" と分類したものを別の節で "チームで合意する" と書かない。
- 因果を主張するときは、その機構 (なぜそうなるか) を一文で示す。"A だと B になる" とだけ書いて理由を省略しない。
- 検出/保証/解決を "必ず" できるかのように書かない。条件付きで述べる (〜しやすい/〜が成り立つときに限り)。
- 主張は、挙げた例が実際にその全体を支えているか確認する。例が一部しか支えないなら主張の範囲を狭める。
- 前方に逃がした論点が本当にそこで回収されることを確認する。回収しない伏線を張らない。
- 譲歩/限定 (ただし/とはいえ) を置いたら、その後で必ず論を進める。逆接で終えて宙吊りにしない。
- 節の中心となる語は、その節以前に定義/対象範囲を述べてから使う。

## 読み手の負荷の管理

読者の記憶と注意は有限の資源として扱う。

- 後で参照しない固有名 (ファイル名/関数名/識別子) を出さない。"仕様書" "金額計算のユーティリティ" のような一般的な言い方で済ませる。
- 抽象的な言い回しの指す内容が文脈から一意に決まらないときは、同格挿入でその場で特定し、読者に前を読み返させない。
- 新しい例を足して読者が保持すべき文脈が増えるときは、前の例と何が違うか、なぜもう一つ要るかを前置きする。
- 章/節の導入に、これから扱う内容に関係しない過剰な詳細を詰め込まない。

## 視点と語り

- 例示では、結果の羅列や受動態ではなく、行為者を主語にした動作の連なりで書く。
- 架空の人物設定 (入社2年目のエンジニアが、など) を無意味に冠しない。
- 読者を "あなた" と呼ばず役割名 (開発者/読者) で書く。二人称は場面への導入や結びなど要所にとどめる。
- 対象を指す語は具体的に選ぶ。"AI" "ツール" のような広い語でぼかさない。
- 術語を導入したら以後はその語で通す。曖昧語に後退しない。
- 術語/訳語はその分野で慣用される語を選ぶ。意味の近い漢語を一般語の感覚で充てない。

## 演出の抑制

修辞は効果を生む箇所でのみ使う。

- 溜め (ここには〜が潜んでいる) や修辞疑問で導出を演出するのは、緊張が議論に効く要所に限る。説明で足りる箇所はそのまま述べる。
- 短い決め台詞を独立段落にして緊張を作る演出を多用しない。
- 命令調の断定 (〜してはならない) より、作業者の判断として書く形 (〜するわけにはいかない) を選ぶ。
- 転回点を過剰に劇的にしない。事実を述べる一文で足りることが多い。
- 帰結の列挙で事故や危険を煽らない。
- "重要なのは〜である" のような前置きで主張を予告しない。主張をそのまま書く。
- "A ではなく B だった" という対句の決め台詞を多用しない。
- 慣用表現をひねった言い回しや、指す内容が一意に決まらない比喩を使わない。平易な動詞でそのまま言う。

## LLM っぽい表現の禁止

中身のない型に誘惑されない。次の言い回しは、論点を増やさず "ちゃんと書いている感" だけを付ける LLM 口調なので使わない。

- 予告と総括: "重要なのは〜である" "本章では〜を扱う/探求する" "ここでは〜について見ていく" "まとめると" "要するに" (直前の言い換えだけのとき) "〜に他ならない"
- 正面から系: "正面から扱う/回収する/見る" — 中身の代わりに姿勢だけを宣言する
- 空虚な形容: "不可欠" "核心的" "鍵となる" "根本的な" (中身を説明せず強調だけ)、"多角的" "包括的" "総合的" (何をどう見たか書かない)
- 空虚な動詞: "掘り下げる" "深掘りする" "言語化する" (何をどう書いたか示さず終わる)、"触れる" "言及する" (一段落で済ませるだけ)
- 接続の型: "〜において" "〜という側面から" "〜の観点から" (新情報なし)、"さらに" "また" "加えて" の連打
- 弱い緩和と称賛: "〜と言えるだろう" (根拠なく弱める場合だけ。推量/仮定/疑念なら残す)、"非常に" "極めて" "大いに" (中身のない強調)

悪い例: "本章では、〇〇の理論を正面から扱う" "多角的に分析すると、重要なのは〜である"
良い例: "本章では、〇〇の理論を扱う" "評価の核心は、正しさを誰が知っているかにある"

## 冗長の排除

無駄な文章をなるべく残さない。

- 同じ主張を言い換えて繰り返さない。一つの主張は一度だけ書く。隣接する節が同じことを別角度で述べているなら片方に吸収する。
- 場面を描写した直後に、その内容を要約し直さない。意味づけの一文だけを置く。
- 同じ論理的役割を持つ並列の事実は、文を分けて重ねず一文にまとめる。数文の議論を一文に圧縮できるなら圧縮した一文だけを残す。
- 読者が自力で補える中間段階の説明は書かない。
- 接続や評価のためだけの文 (それ自体はよいことである、など) を置かない。
- 想像上の読者との問答を修辞として使わない。読者の反応を演じて応答する形 (〜と感じたかもしれない。そのとおりである) も避け、譲歩は地の文で簡潔に行う。
- 著者の立場の弁明や断り (本書もそれを否定しない、など) を書かない。事実の記述だけ置く。
- 本文でまだ導入していない概念や文書名を先回りして持ち出さない。

## 見出しの付け方

見出しは内容を特定できる具体的なものにする。その節が答える問い、または扱う対象を指す句にする。

- 作業の手順だけを述べる見出し (例に戻す、〜を読み直す) や情報量のない見出しにしない。
- 見出しを、節の結論を言い切る決め台詞にしない。見出しの時点で読者がオチを知る状態を避ける。
- 扱う対象を指す名詞句でもよい。疑問形か断定形かは本文のトーンに合うほうを選ぶ。

## 読者への誠実さ

- 例が作為的に見えうるなら隠さない。読者の疑念を先回りして認め、現実にあり得る根拠を短く添える。
- その根拠は著者の断定ではなく、読者自身の経験に訴える一般的事実や通説に求める。
- 確認していないことを、確認したかのように滑らかに書かない。

## Codex rule loading

This rule applies when selected through `RULES_INDEX.md` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the runtime instruction hierarchy and report the conflict.

---

## Source: `codex/rules/opus-47-policy.md`

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

---

## Source: `codex/rules/referent-before-label.md`

# 語より先に指示対象を固定する

<!-- codex-port: managed; source=common/rules/referent-before-label.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/rules/referent-before-label.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

<!-- codex-runtime-summary -->
- IMPORTANT: 対象文書 (設計文・調査報告・対策案・命名・推論順序の要約) では、対応表を独立提出してから本文を書く。対応表なしの本文提出は禁止。表なしで書き始めたら本文を破棄し、対応表から作り直す。
- IMPORTANT: 骨組み・見出しに作業ラベル (未整理の作業を抽象名詞で包んだ句) を使わない。新語・造語は初出定義を書けなければ導入せず、指す対象を具体記述に分解する。
- IMPORTANT: 対象文書の着手時は semantic-generation skill を発火する。skill が使えない場合も、最低 6 列 (出典・目的・具体対象・役割・前後関係・候補語) の対応表を独立成果物として先に保存する。
<!-- /codex-runtime-summary -->

対象が曖昧なまま語 (しばしばその場の造語) を先に置き、その語を土台に思考を進めると、指示対象とのずれが訂正されないまま設計文・状態名・条件名・メソッド名・型名まで波及する(TASK-52 の「圧縮時点」「観測を一つに集める」事例)。
本 rule はこの生成の進め方そのものを止める。誤用語のリストとの照合 (言葉狩り) は対策にしない。造語は列挙できないためである。
本 rule は、語の揺れを判定する基準ではなく「語を置く前の手順」を持つ。

## 適用範囲 (対象文書)

次のいずれかに該当する作業だけに適用する。該当するか判断できない場合は適用する。

1. 設計資料、要求からの設計、調査報告、原因切り分け案、対策案を書く。
2. 命名する (公開仕様・状態名・条件名・事象名・値や記録の型名・メソッド名・boolean 名)。
3. ユーザーが与えた推論順序を短い作業ラベルへ要約しようとしている。

ユーザー原文の引用、単純な機械編集、既存名の再利用、定型出力、雑談、確立した用語だけで書ける短文には適用しない。

## 常時適用 (3 禁則)

- IMPORTANT: 対象文書で、対応表 (referent table) を独立提出せずに本文を提出しない。対応表は本文とは別のファイルまたは別の turn で先に保存し、本文はその後に書く(完成文書の先頭に表を置くだけでは「先に作った」ことの証明にならない)。
- IMPORTANT: 骨組み・見出し・結論に作業ラベルを使わない。作業ラベルとは、目的・対象・判断を省いたまま未整理の作業を抽象名詞で包んだ句を指す (例: 「観測をまとめる」)。
  - 使いたくなったら、その句が指す対象を対応表に書けるか試し、書けなければ句を捨てて具体文で書く。
- IMPORTANT: ユーザーの用語・確立した用語以外の新語を導入する時は、初出に「X とは〜を指す」の定義文を書く。定義文が書けない語は導入せず、指す対象をそのまま文で書き下す。

## 通常の流れ

1. 対象文書に該当するか判定する (迷ったら該当扱い)。
2. `$semantic-generation` skill を発火し、対応表を独立成果物として先に保存する。
3. 本文は対応表に載った語だけを中心語彙として書き、日本語文・設計要素・コード識別子の三層で同じ対応を保つ。

## 問題時の予備動作

- 対象文書なのに対応表を提出せず本文を書き始めたことに気づいたら、後付けで表を追記して継続しない。本文を破棄し、対応表を独立提出し直してから本文を再生成する。
- skill が利用できない環境では、最低 6 列 (出典・目的・具体対象・役割・前後関係・候補語)の対応表を作業ディレクトリに独立ファイルとして保存してから本文に着手する。

## Codex rule loading

This rule applies when selected through `RULES_INDEX.md` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the runtime instruction hierarchy and report the conflict.
