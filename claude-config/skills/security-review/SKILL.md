---
name: security-review
description: 認証、ユーザー入力、機密データを扱う際に使用。OWASP Top 10をカバー。
---

# Security Review

## 🚨 鉄則

**入力は信用しない。権限は常に確認。機密は暗号化。**

## OWASP Top 10 要点

### A01: アクセス制御

```typescript
// ⚠️ 必須チェック
if (req.user.id !== resourceOwnerId && !req.user.isAdmin) {
  return res.status(403).json({ error: 'Forbidden' });
}
```

### A02: 暗号化

```typescript
// パスワード: bcrypt (⚠️ saltRounds 12以上)
const hash = await bcrypt.hash(password, 12);
```

### A03: インジェクション

```typescript
// 🚫 絶対禁止: 文字列結合
db.query(`SELECT * FROM users WHERE id = ${id}`);

// ✅ パラメータ化
db.query('SELECT * FROM users WHERE id = $1', [id]);
```

## 入力バリデーション

```typescript
// ⚠️ サーバーサイドで必ず検証(クライアントは信用しない)
const validated = schema.parse(req.body);
```

## 🚫 シークレット禁止事項

```
❌ コードにハードコード
❌ ログに出力
❌ エラーメッセージに含める
✅ 環境変数/シークレット管理サービス
```
