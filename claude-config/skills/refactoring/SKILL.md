---
name: refactoring
description: 振る舞いを変えずにコード構造を改善する際に使用。
---

# Refactoring

## トリガー

- コード品質改善時
- 重複コード発見時
- 可読性向上時
- 技術的負債解消時

## 🚨 鉄則

**テストがある状態で始める。振る舞いは変えない。**

## ⚠️ 進め方

```
1. テストが通ることを確認
2. 小さな変更
3. テスト実行
4. 繰り返し
```

## コードスメル

### 長いメソッド → 抽出

```typescript
// ❌
function processOrder() { /* 100行 */ }

// ✅
function processOrder() {
  validate();
  calculate();
  save();
}
```

### 条件分岐 → ポリモーフィズム

```typescript
// ❌
if (type === 'a') { ... } else if (type === 'b') { ... }

// ✅
interface Handler { handle(): void }
class HandlerA implements Handler {}
class HandlerB implements Handler {}
```

### マジックナンバー → 定数

```typescript
// ❌
if (speed > 9.8)

// ✅
const GRAVITY = 9.8;
if (speed > GRAVITY)
```

## 🛑 しない場合

- デッドライン直前
- テストがない
- 動作を理解していない
