---
name: typescript-strict
description: TypeScriptの設定や型エラー対応時に使用。
---

# TypeScript Strict Mode

## 🚨 鉄則

**anyは禁止。型で安全性を保証。**

## 推奨tsconfig

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "exactOptionalPropertyTypes": true
  }
}
```

## 🚫 禁止パターン

```typescript
// ❌ any
function process(data: any) {}

// ❌ 型アサーション乱用
const user = data as User;

// ❌ non-null assertion乱用
const name = user!.name;

// ❌ @ts-ignore
// @ts-ignore
brokenCode();
```

## ✅ 推奨パターン

```typescript
// 型ガード
function isUser(obj: unknown): obj is User {
  return typeof obj === 'object' && obj !== null && 'id' in obj;
}

// unknown + 検証
function process(data: unknown) {
  if (!isUser(data)) throw new Error('Invalid');
  return data.id;  // 型安全
}

// Optional chaining
const name = user?.profile?.name ?? 'Unknown';

// Exhaustive check
type Status = 'pending' | 'done';
function handle(s: Status) {
  switch (s) {
    case 'pending': return 1;
    case 'done': return 2;
    default:
      const _exhaustive: never = s;  // 新しい値追加時にエラー
      return _exhaustive;
  }
}
```

## ユーティリティ型

```typescript
Partial<T>      // 全プロパティをoptionalに
Required<T>     // 全プロパティを必須に
Pick<T, K>      // 特定プロパティのみ抽出
Omit<T, K>      // 特定プロパティを除外
Record<K, V>    // キーと値の型を指定
```
