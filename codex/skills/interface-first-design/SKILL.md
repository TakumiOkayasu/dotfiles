---
codex_port_source: claude/skills/interface-first-design/SKILL.md
name: interface-first-design
description: 機能追加・クラス設計・interface設計・依存関係整理・責務分割時に使用。疑似コードから interface→クラス→TDD→実装の順で設計する。TDDスキルの前段。
---

# Interface-First Design

<!-- codex-port: managed; source=claude/skills/interface-first-design/SKILL.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/skills/interface-first-design/SKILL.md`.
- Codex skills are installed under `~/.agents/skills/<skill>/SKILL.md` by `install.sh`.
- Global and project rules live under `~/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through `prompt:<name>` or `codex/prompts/commands/<name>.md`.
- Subagent usage must follow `~/.codex/SUBAGENTS.md` and the current Codex tool contract.

**理想の処理フローを疑似コードで先に描け。そこからinterfaceが生まれる。実装は最後。**

## トリガー条件

以下のいずれかに該当する場合、このスキルを発動する：

- 新規クラス・モジュールの設計を開始するとき
- 既存クラスの責務が肥大化し、分割を検討するとき
- 依存関係の整理・リファクタリングを行うとき
- 「何をinterfaceにすべきか」が不明なとき
- TDDスキル実行前の設計フェーズ

## 前提条件

- 実装言語・フレームワークは問わない（言語非依存で適用可能）
- 既存実装がある場合でも、必ず疑似コードから書き直す（Anti-pattern 4参照）
- TDDスキルと組み合わせて使用する（本スキルはTDDの前段）

---

## 手順（ステップバイステップ）

### Step 1: 疑似コードで理想フローを描く

**実装コードを一切書く前に**、以下テンプレートで「何が起きるか」を言語非依存で記述する。

**要件に不明点がある場合**: 疑似コードの該当箇所を `[要確認: <不明点の具体>]` 記法で仮置きしてから先へ進み、レポート末尾に確認事項を集約する（`hallucination-prevention` rule 準拠）。推測で埋めない。

```
# [機能名] の理想フロー

given [入力・前提条件]

when [トリガー・操作]

then
  [手順1]: [何をするか]
  [手順2]: [何をするか]
  ...
  return [期待する出力]

# 分岐・エラーケース
when [例外ケース]
then [どう扱うか]
```

**疑似コード例: 注文処理**

```
# 注文確定処理 の理想フロー

given 注文内容(商品リスト, ユーザーID)

when 注文確定ボタンが押された

then
  在庫チェック: 全商品が注文可能か確認する
  合計計算:    単価 × 数量を合算する
  決済処理:    合計金額を課金する
  通知送信:    ユーザーに確定メールを送る
  return 注文ID

when 在庫不足
then エラーを返す(どの商品が不足か含める)

when 決済失敗
then 在庫を元に戻す → エラーを返す
```

**疑似コードから読み取るもの:**
- 動詞ひとつ = interfaceのメソッドひとつ
- 名詞 = interfaceが扱うデータ型
- 分岐 = エラー型 or 戻り値の型バリアント

---

### Step 2: interfaceへの変換

疑似コードの各「手順」をinterfaceのメソッドに1:1対応させる。

```
疑似コード「在庫チェック」→
  interface StockChecker
    check(items) -> Ok | OutOfStockError

疑似コード「合計計算」→
  interface PriceCalculator
    calculate(items) -> Money

疑似コード「決済処理」→
  interface PaymentGateway
    charge(amount, userId) -> PaymentId | PaymentError

疑似コード「通知送信」→
  interface OrderNotifier
    send(orderId, userId) -> void
```

**変換ルール:**
- 動詞ひとつ = メソッドひとつ
- 名詞 = interfaceが扱うデータ型
- フレームワーク固有の型 (Request / Response / Model 等) はinterfaceに含めない
- 戻り値は用途で書き分け: 読取系（`find` / `read` 等、副作用なし）は `T | null` で not-found を明示、副作用系（`write` / `charge` / `delete` 等）は `Ok | Error` で成功/失敗を明示する
- メソッドは原則1つ。2つ必要に感じたら責務混在を疑う

---

### Step 3: 上位層での組み立て

interfaceを組み合わせる処理は上位層の責務。

```
class OrderService
  depends-on: StockChecker, PriceCalculator, PaymentGateway, OrderNotifier

  confirm(order):
    stock.check(order.items)    -> error? return it
    amount = price.calculate(order.items)
    paymentId = payment.charge(amount, order.userId) -> error? return it
    notifier.send(paymentId, order.userId)
    return paymentId
```

**ポイント:** `OrderService` は「何を使うか」を知っているが「どう実装されているか」は知らない。依存はすべてinterfaceを通じて注入する。

**上位層の粒度の目安:**

- 用途単位の薄い組み立て → UseCase（提供層）
- 複数 UseCase を束ねる配線点 → 管理層（Controller / Orchestrator 等）
- 命名は `hierarchical-architecture` の役割サフィックス規則（Manager / Provider / Accessor 等）に従う
- 単一 UseCase で済むなら UseCase 自体が上位層（Controller を無理に作らない）

---

### Step 4: TDDへ移行

設計完了チェックリストを全てクリアしたら、TDDスキルを起動して実装フェーズへ移る。

---

## 禁止事項・制約

| 禁止 | 理由 |
|------|------|
| 疑似コードを省略してinterfaceを作る | 実装都合がinterfaceに漏れる（Anti-pattern 4） |
| 既存実装からそのままinterfaceを写す | ORM・フレームワーク依存が混入する |
| 1つのinterfaceに複数メソッドを定義する | ISP違反・責務混在（Anti-pattern 3） |
| フレームワーク固有の型をinterfaceに含める | 言語・FW変更時に全面改修が発生する |
| 組み立て処理を下位層に書く | 上位層の責務を侵害する（hierarchical-architecture違反） |
| 同レイヤー間でinterfaceを直接参照する | 横参照禁止（hierarchical-architecture参照） |
| 「実装してから設計を後付け」する | 設計は必ず実装の前に行う |

---

## アンチパターン集

### ❌ Anti-pattern 1: 実装都合がinterfaceに漏れる

```
BAD:
  interface UserRepository
    findByEmailFromUsersTable(email) -> UserRow   # テーブル名が漏れている
    executeRawQuery(sql) -> unknown               # SQL言語が漏れている

GOOD:
  interface UserRepository
    findByEmail(email) -> User | null
```

### ❌ Anti-pattern 2: 1メソッドが複数責務を持つ

```
BAD:
  interface ReportService
    fetchAndFormatAndSend(userId) -> void   # andが入ったら要注意

GOOD:
  interface Fetcher
  interface Formatter
  interface Sender

  class ReportFetcher   implements Fetcher   -> fetch(userId) -> RawReport
  class ReportFormatter implements Formatter -> format(raw)   -> FormattedReport
  class ReportSender    implements Sender    -> send(report)  -> void
```

### ❌ Anti-pattern 3: interfaceの肥大化 (ISP違反)

```
BAD:
  interface UserService
    find(id)               -> User
    save(user)             -> void
    delete(id)             -> void
    sendWelcomeEmail(user) -> void    # 通知は別責務
    exportToCsv(users)     -> string  # エクスポートも別責務

GOOD: (1 interface = 1メソッド = 1責務)
  interface Reader
  interface Writer
  interface Deleter
  interface Notifier
  interface Exporter

  class UserReader   implements Reader   -> read(id) -> User
  class UserWriter   implements Writer   -> write(user) -> void
  class UserNotifier implements Notifier -> notify(userId, message) -> void
```

### ❌ Anti-pattern 4: 疑似コードを書かずにinterfaceを作る

```
BAD:
  interface ArticleInterface
    get(id) -> array           # "array" はORM都合の型
    paginateAll() -> Paginator # ORMのPaginatorが漏れている

GOOD: 疑似コードから「記事一覧表示」フローを先に描く
  interface Reader
  interface Lister

  class ArticleReader implements Reader -> read(id)     -> Article | null
  class ArticleLister implements Lister -> list(filter) -> Article[]
```

---

## 原則

- **クラスの責務は1つ。メソッドの責務も1つ。**
- interfaceにフレームワーク固有の型を含めない。言語が変わっても同じ構造で書けること
- 実装側の都合をinterfaceに漏らさない
- 同じinterfaceの複数インスタンスで差異を表現する
- 組み立て・方式選択は上位層の責務。カテゴリごとの上位層で分割し、最上位で接続する
- 徹底すればhierarchical-architectureは自然に満たされる

---

## 出力形式（設計ドキュメント）

設計結果は以下の形式で出力する：

```
## [機能名] 設計

### 疑似コード
[Step 1の内容]

### Interface一覧
| Interface名 | メソッド | 引数 | 戻り値 |
|------------|---------|------|--------|
| FooReader  | read()  | id   | Foo \| null |

### クラス一覧
| クラス名    | 実装Interface | 責務 |
|------------|--------------|------|
| FooReader  | Reader       | DBからFooを取得 |

### 上位層の組み立て
[Step 3の内容]
```

---

## 設計完了チェックリスト

```
[ ] 疑似コードを書いたか（Step 1を省略していないか）
[ ] 各interfaceのメソッドは1つか（複数なら分割候補）
[ ] interfaceにフレームワーク固有の型が含まれていないか
[ ] 実装を差し替えても利用側が変わらないか
[ ] 組み立て処理は上位層に集約されているか
[ ] エラーケースがinterfaceの戻り値型に反映されているか
[ ] interfaceにメソッドを追加しても既存実装が壊れないか（壊れるなら責務混在）
[ ] 1メソッドが2つ以上の理由で変更されないか
[ ] 禁止事項をすべて確認したか
[ ] TDDスキルへの移行準備ができているか
```
