---
name: input-validation
description: ユーザー入力、フォームデータ、APIリクエストを検証する際に使用。
---

# Input Validation

## トリガー

- ユーザー入力処理時
- フォームデータ検証時
- APIリクエスト検証時
- 外部データ受け取り時

## 🚨 鉄則

**クライアントは信用しない。サーバーで必ず検証。**

## バリデーション層

```
クライアント: UX向上(即座のフィードバック)
     ↓
サーバー: ⚠️ 必須(セキュリティ)
     ↓
データベース: 最終防衛(制約)
```

## Zodによる検証

```typescript
import { z } from 'zod';

const userSchema = z.object({
  email: z.string().email(),
  age: z.number().int().min(0).max(150),
  name: z.string().min(1).max(100),
});

// ⚠️ parseは例外をスロー、safeParseはResult型
const result = userSchema.safeParse(req.body);
if (!result.success) {
  return res.status(400).json({ errors: result.error.errors });
}
```

## よくあるバリデーション

```typescript
// 必須
z.string().min(1)

// メール
z.string().email()

// URL
z.string().url()

// 列挙型
z.enum(['admin', 'user', 'guest'])

// 日付
z.string().datetime()

// 配列
z.array(z.string()).min(1).max(10)

// オプショナル
z.string().optional()

// デフォルト値
z.string().default('guest')
```

## 🚫 禁止パターン

```typescript
// ❌ クライアントのみで検証
if (formIsValid) { submit(); }

// ❌ 型アサーションで済ませる
const user = req.body as User;

// ❌ 部分的な検証
if (email) { /* emailの形式は未検証 */ }
```

## サニタイズ

```typescript
// HTMLエスケープ
import { escape } from 'lodash';
const safe = escape(userInput);

// SQLはパラメータ化クエリで対応(バリデーションではない)
```
