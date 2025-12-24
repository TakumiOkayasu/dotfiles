---
name: environment-configuration
description: 環境変数やシークレットを管理する際に使用。
---

# Environment Configuration

## 🚨 鉄則

**設定はコードから分離。機密情報はコードに書かない。**

## .env

```bash
# .env.example (✅ コミットする)
DATABASE_URL=postgres://user:pass@localhost/db

# .env (🚫 コミットしない)
DATABASE_URL=postgres://real:pass@prod/db
```

## バリデーション

```typescript
// ⚠️ 起動時に検証
const required = ['DATABASE_URL', 'JWT_SECRET'];
const missing = required.filter(k => !process.env[k]);
if (missing.length) throw new Error(`Missing: ${missing}`);
```

## 🚫 禁止事項

```typescript
// ❌ ハードコード
const API_KEY = 'sk-live-xxxxx';

// ❌ ログ出力
console.log('Password:', password);

// ❌ エラーに含める
throw new Error(`Failed with token: ${token}`);
```

## .gitignore

```
.env
.env.local
.env.*.local
!.env.example  # ⚠️ テンプレートはコミット
```
