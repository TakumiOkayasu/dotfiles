---
name: refactoring
description: 振る舞いを変えずにコード構造を改善する際に使用。
---

# Refactoring

## 鉄則

**テストがある状態で始める。振る舞いは変えない。**

## 進め方

```
1. テストが通ることを確認
2. 小さな変更(変更箇所に集中。無関係なコードに手を出さない)
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

## Maintain Balance(過剰な簡略化の防止)

リファクタリングで構造を壊さないための制約:

- 可読性を損なう過度な圧縮をしない(明示的なコード > 巧妙で短いコード)
- 抽出しすぎない: 1回しか呼ばれない3行の処理を別関数にする必要はない
- 既存のエラーハンドリングやエッジケース対応を削らない
- ネストを減らすために早期returnを導入するのは良いが、ロジックの意味が変わる変形はしない
- 「動いているが汚い」と「壊れる可能性がある変更」なら、前者を残す

## しない場合

- デッドライン直前
- テストがない
- 動作を理解していない

