# Refactoring

## 鉄則

**テストがある状態で始める。振る舞いは変えない。**

## 入力

- リファクタリング対象のコードファイル（複数可）
- 既存テストスイート

## 出力

- 振る舞いが同一のまま構造が改善されたコード
- 全テストがパスした状態

## 処理手順

```
1. テスト実行 → 全パスを確認（失敗がある場合は中断）
2. コードスメルを特定（下記カタログ参照）
3. 1箇所だけ変更（無関係なコードに手を出さない）
4. テスト実行 → 全パスを確認
5. 2〜4を繰り返す
6. 完了条件: スメルが解消され、全テストがパスしている
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

## Maintain Balance（過剰な簡略化の防止）

リファクタリングで構造を壊さないための制約:

- 可読性を損なう過度な圧縮をしない（明示的なコード > 巧妙で短いコード）
- 抽出しすぎない: 1回しか呼ばれない3行の処理を別関数にする必要はない
- 既存のエラーハンドリングやエッジケース対応を削らない
- ネストを減らすために早期returnを導入するのは良いが、ロジックの意味が変わる変形はしない
- 「動いているが汚い」と「壊れる可能性がある変更」なら、前者を残す

## 実施しない場合

- デッドライン直前
- テストがない（先にテストを書く）
- 動作を理解していない

## 使用例

```
# TypeScriptファイルをリファクタリング
> /refactoring src/order.ts

# 複数ファイルをまとめてリファクタリング
> /refactoring src/order.ts src/payment.ts
```
