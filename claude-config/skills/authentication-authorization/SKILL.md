---
name: authentication-authorization
description: ログイン、セッション、JWT、OAuth、アクセス制御を実装する際に使用。
---

# Authentication & Authorization

## トリガー

- ログイン機能実装時
- JWT/セッション管理時
- 権限チェック実装時
- パスワード処理時

## 🚨 鉄則

**認証(誰か) ≠ 認可(何ができるか)。両方必要。**

## 認証方式

### JWT

```typescript
// ⚠️ 署名アルゴリズムはHS256以上
const token = jwt.sign({ userId }, SECRET, { 
  expiresIn: '15m',  // 短め
  algorithm: 'HS256'
});

// 検証
const decoded = jwt.verify(token, SECRET);
```

### セッション

```typescript
// ⚠️ セッションIDは十分なエントロピー
app.use(session({
  secret: process.env.SESSION_SECRET,  // 🚫 ハードコード禁止
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,   // ⚠️ 必須
    secure: true,     // ⚠️ 本番では必須
    sameSite: 'lax'
  }
}));
```

## 認可

```typescript
// ⚠️ すべてのエンドポイントで確認
function authorize(requiredRole: string) {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ error: 'Unauthorized' });
    if (req.user.role !== requiredRole) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  };
}

// リソースオーナー確認
if (resource.ownerId !== req.user.id && !req.user.isAdmin) {
  return res.status(403).json({ error: 'Forbidden' });
}
```

## 🚫 禁止事項

```typescript
// ❌ パスワード平文保存
user.password = password;

// ❌ トークンをURLに含める
/api/data?token=xxx

// ❌ フロントエンドのみで認可
if (user.role === 'admin') { showAdminPanel(); }
```

## パスワード

```typescript
// ⚠️ bcrypt, saltRounds 12以上
const hash = await bcrypt.hash(password, 12);
const isValid = await bcrypt.compare(password, hash);
```
