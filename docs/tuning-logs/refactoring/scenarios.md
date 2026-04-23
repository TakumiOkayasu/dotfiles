# refactoring シナリオカタログ

empirical-prompt-tuning でチューニングするための評価シナリオ。**iter 開始後は変更しない**。

- 対象スキル: `claude/skills/refactoring/SKILL.md`
- description: 「振る舞いを変えずにコード構造を改善する際に使用。」
- 収束目標: **連続2** イテレーション（典型スキル）

## 隣接スキルとの境界（iter 0 整合確認の焦点）

| スキル | 対比 |
|---|---|
| interface-first-design | iface-first = **新規設計**(interface→クラス→TDD→実装)、refactoring = **既存コード**の構造改善（振る舞い不変） |
| tdd | tdd = **新規実装**を RED-GREEN-REFACTOR、refactoring = REFACTOR フェーズの専門化（テスト存在前提） |
| test-coverage-guard | test-coverage-guard = テストコード品質、refactoring = 本体コード品質 |
| systematic-debugging | sd = バグ原因分析、refactoring = 振る舞い不変なので**バグ修正を含めない** |

## Baseline シナリオ

### シナリオA（中央値: 長いメソッド分割の依頼）

**状況**:
ユーザー「`OrderProcessor.processOrder()` が 120 行あって読めない。リファクタしてほしい。テストは全 PASS してる」

```typescript
// OrderProcessor.ts (抜粋)
class OrderProcessor {
  processOrder(order: Order): Receipt {
    // 1) バリデーション (約30行)
    if (!order.items || order.items.length === 0) throw new Error('empty');
    for (const item of order.items) {
      if (item.quantity <= 0) throw new Error('invalid quantity');
      if (item.price < 0) throw new Error('invalid price');
      // ... 検証続く
    }

    // 2) 在庫確認 (約25行)
    for (const item of order.items) {
      const stock = this.inventory.get(item.sku);
      if (stock < item.quantity) throw new Error('out of stock');
      // ... 続く
    }

    // 3) 価格計算 (約30行)
    let subtotal = 0;
    for (const item of order.items) {
      subtotal += item.price * item.quantity;
    }
    const tax = subtotal * 0.1;
    const total = subtotal + tax;
    // ... 割引適用続く

    // 4) 永続化 (約20行)
    const receipt = { id: this.nextId++, total, items: order.items };
    this.repo.save(receipt);
    this.logger.info('order processed', { id: receipt.id });
    return receipt;
  }
}

// テスト: processOrder の振る舞いを 8 ケースで検証 (全 PASS)
```

**要件チェックリスト**:
1. [critical] **フェーズ1で「テスト全 PASS を確認」を最初に実施宣言**
2. [critical] **振る舞いを変えない**（インターフェース不変、戻り値不変、例外不変）
3. [critical] **1スメル = 1変更 + 都度テスト実行**（複数スメル同時禁止）
4. スメル列挙（少なくとも「長いメソッド」を識別）と優先度順並べ替え
5. 「長いメソッド → 抽出」パターンを適用（`validate()` / `checkInventory()` / `calculateTotal()` / `persist()` 等への分割）
6. 出力フォーマット（変更内容 / テスト結果 / 振る舞い保証）に沿って報告

### シナリオB（edge 1: テストなし状態でのリファクタ依頼）

**状況**:
ユーザー「`PaymentService` が複雑すぎる。リファクタして整理してくれ。テスト? まだ書いてない」

```typescript
// PaymentService.ts: ネスト4階層、200 行、テスト 0 件
class PaymentService {
  process(payment: Payment): void {
    if (payment.type === 'card') {
      if (payment.card.country === 'JP') {
        if (payment.amount > 100000) {
          if (this.fraudCheck(payment)) {
            // ... 処理
          }
        }
      }
    }
  }
}
```

**要件チェックリスト**:
1. [critical] **「前提条件: テストが存在し、全てパスしていること」が満たされていないことを明示**
2. [critical] **リファクタリングを開始せず、先行してテスト作成（特性テスト含む）を提案**
3. **「実施禁止: テストがない状態」を引用**（禁止事項表）
4. テスト不在のままのリファクタはデグレ検出不能であることを説明
5. 推奨経路を提示（特性テストで現状の振る舞いを固定 → リファクタ着手）
6. テスト作成は本スキル外であることを明示（必要なら TDD スキルへ委譲）

### シナリオC（edge 2: バグ修正・機能追加の混入依頼）

**状況**:
ユーザー「`InvoiceCalculator` をリファクタしてほしい。**ついでに**消費税が 10% ハードコードされてるから 8% も切り替えできるようにしてくれ。あと税抜端数の丸め誤差バグも一緒に直して」

```typescript
class InvoiceCalculator {
  calculate(items: Item[]): number {
    let total = 0;
    for (const i of items) total += i.price * i.quantity;
    return total * 1.10; // ← 税率ハードコード + 端数バグ
  }
}
// テスト: 全 PASS
```

**要件チェックリスト**:
1. [critical] **「振る舞いの変更」「ついで修正」をスコープから除外**（禁止事項表「無関係なコードへの変更」「ロジックの意味が変わる早期return」）
2. [critical] **税率切替・バグ修正は別作業（別 PR）として分離提案**
3. リファクタリング対象（純粋な構造改善のみ）と除外対象（仕様変更・バグ修正）を切り分けて列挙
4. バグ修正は systematic-debugging / TDD への委譲を示唆
5. リファクタ完了後にバグ修正・税率切替を行う順序を提示
6. 鉄則「振る舞いは変えない」を引用

## Hold-out シナリオ（収束判定時のみ使用）

### シナリオD（新規 interface 設計依頼 = 発動すべきでない）

**状況**:
ユーザー「決済処理を Stripe / PayPal / 銀行振込に対応させたい。`PaymentGateway` interface を設計して、Stripe 実装をまず作ってほしい。既存コードにはまだ決済処理は無い」

**要件チェックリスト**:
1. [critical] **本スキル（refactoring）を発動せず、interface-first-design / tdd へ委譲**
2. [critical] **「振る舞いを変えずにコード構造を改善」に該当しないことを認識**（新規実装は対象外）
3. 既存コード不在 → リファクタリング対象が存在しない旨を明示
4. interface-first-design スキルで「疑似コード→interface→クラス→TDD→実装」の順序が適切と提案
5. 誤発動を避けるため description「振る舞いを変えずに **コード構造を改善**」を引用して非対象判定

## 運用メモ

- シナリオ A は最頻出「長いメソッド分割」の中央値
- シナリオ B は前提条件違反（テスト不在）の発動阻止試験
- シナリオ C は「ついで修正」誘惑（振る舞い変更混入）の境界試験
- シナリオ D は hold-out として、**新規実装依頼での誤発動回避**（interface-first-design 境界）を試す
