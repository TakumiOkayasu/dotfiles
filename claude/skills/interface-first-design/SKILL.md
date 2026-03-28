# Interface-First Design

---
name: interface-first-design
description: 機能追加・クラス設計・interface設計・依存関係整理・責務分割時に使用。疑似コードから interface→クラス→TDD→実装の順で設計する。TDDスキルの前段。
---

**理想の処理フローを疑似コードで先に描け。そこからinterfaceが生まれる。実装は最後。**

## 入力・出力

| 項目 | 内容 |
|------|------|
| 入力 | 設計対象の機能・クラス・依存関係の説明 |
| 出力 | 疑似コード → interface定義 → クラス構造 → TDD移行準備 |

## 処理手順

1. **疑似コードを書く** — 言語・FW非依存で「こうだと良い」を書く（省略禁止）
2. **interfaceを逆算する** — フロー実現に必要な契約を抽出する
3. **メソッドを設計する** — 1メソッド = 1責務。メソッド名が振る舞いを限定しないこと
4. **interfaceだけで処理を完結させる** — 利用側はinterfaceに従うだけ
5. **クラスを生成する** — interfaceの集合体としてクラスができる
6. **TDD → 実装**

---

## Step 1: 疑似コードテンプレート

```
# [機能名] の理想フロー

given [入力・前提条件]

when [トリガー・操作]

then
  [手順1]: [何をするか]
  [手順2]: [何をするか]
  ...
  return [期待する出力]

when [例外ケース]
then [どう扱うか]
```

### 例: 注文処理

```
given 注文内容(商品リスト, ユーザーID)
when 注文確定ボタンが押された
then
  在庫チェック: 全商品が注文可能か確認する
  合計計算:    単価 × 数量を合算する
  決済処理:    合計金額を課金する
  通知送信:    ユーザーに確定メールを送る
  return 注文ID
when 在庫不足 → エラーを返す(不足商品を含める)
when 決済失敗 → 在庫を元に戻す → エラーを返す
```

**疑似コードから読み取るもの:**
- 動詞ひとつ = interfaceのメソッドひとつ
- 名詞 = interfaceが扱うデータ型
- 分岐 = エラー型 or 戻り値の型バリアント

---

## Step 2: interfaceへの変換

疑似コードの各「手順」をinterfaceのメソッドに1:1対応させる。

```
疑似コード「在庫チェック」→ interface StockChecker   check(items)         -> Ok | OutOfStockError
疑似コード「合計計算」    → interface PriceCalculator calculate(items)      -> Money
疑似コード「決済処理」    → interface PaymentGateway  charge(amount,userId) -> PaymentId | PaymentError
疑似コード「通知送信」    → interface OrderNotifier   send(orderId,userId)  -> void
```

**変換ルール:**
- 動詞ひとつ = メソッドひとつ
- FW固有の型 (Request / Response / Model 等) はinterfaceに含めない
- 戻り値は Ok/Error の2値で成功/失敗を明示する
- メソッドは原則1つ。2つ必要に感じたら責務混在を疑う
- 最終的なinterfaceは責務名のみで定義する（→ Anti-pattern 3 参照）

---

## Step 3: 上位層での組み立て

```
class OrderService
  depends-on: StockChecker, PriceCalculator, PaymentGateway, OrderNotifier

  confirm(order):
    stock.check(order.items)                     -> error? return it
    amount    = price.calculate(order.items)
    paymentId = payment.charge(amount,order.userId) -> error? return it
    notifier.send(paymentId, order.userId)
    return paymentId
```

`OrderService` は「何を使うか」を知るが「どう実装されているか」は知らない。依存はすべてinterfaceを通じて注入する。

---

## アンチパターン集

### ❌ Anti-pattern 1: 実装都合がinterfaceに漏れる

```
BAD:  interface UserRepository
        findByEmailFromUsersTable(email) -> UserRow  # テーブル名が漏れている
        executeRawQuery(sql) -> unknown              # SQL言語が漏れている

GOOD: interface UserRepository
        findByEmail(email) -> User | null
```

### ❌ Anti-pattern 2: 1メソッドが複数責務を持つ

```
BAD:  interface ReportService
        fetchAndFormatAndSend(userId) -> void   # andが入ったら要注意

GOOD: interface Fetcher   → class ReportFetcher   -> fetch(userId) -> RawReport
      interface Formatter → class ReportFormatter -> format(raw)   -> FormattedReport
      interface Sender    → class ReportSender    -> send(report)  -> void
      # 組み立ては上位層で
```

### ❌ Anti-pattern 3: interfaceの肥大化 (ISP違反)

```
BAD:  interface UserService
        find/save/delete/sendWelcomeEmail/exportToCsv  # 責務が混在

GOOD: 1 interface = 1メソッド = 1責務
      interface Reader   → class UserReader   -> read(id)          -> User
      interface Writer   → class UserWriter   -> write(user)       -> void
      interface Notifier → class UserNotifier -> notify(id,msg)    -> void
```

### ❌ Anti-pattern 4: 疑似コードを書かずにinterfaceを作る

```
BAD:  既存実装からそのままinterfaceを写す → 実装都合が全部漏れる
        interface ArticleInterface
          get(id) -> array          # "array" はORM都合の型
          paginateAll() -> Paginator  # ORMのPaginatorが漏れている

GOOD: 疑似コードから「記事一覧表示」フローを先に描く
      interface Reader → class ArticleReader -> read(id)     -> Article | null
      interface Lister → class ArticleLister -> list(filter) -> Article[]
```

---

## 原則

- クラスの責務は1つ。メソッドの責務も1つ
- interfaceにFW固有の型を含めない。言語が変わっても同じ構造で書けること
- 実装側の都合をinterfaceに漏らさない
- 組み立て・方式選択は上位層の責務
- 徹底すればhierarchical-architectureは自然に満たされる

---

## 設計完了チェックリスト

```
[ ] 疑似コードを書いたか（Step 1を省略していないか）
[ ] 各interfaceのメソッドは1つか（複数なら分割候補）
[ ] interfaceにFW固有の型が含まれていないか
[ ] 実装を差し替えても利用側が変わらないか
[ ] 組み立て処理は上位層に集約されているか
[ ] エラーケースがinterfaceの戻り値型に反映されているか
[ ] interfaceにメソッドを追加しても既存実装が壊れないか（壊れるなら責務混在）
[ ] 1メソッドが2つ以上の理由で変更されないか
```
