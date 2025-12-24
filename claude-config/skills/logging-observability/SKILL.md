---
name: logging-observability
description: ロギングやモニタリングを実装する際に使用。
---

# Logging and Observability

## 鉄則

**本番で何が起きているかを把握できる状態を作る。**

## 構造化ログ

```typescript
// ❌
console.log(`User ${id} logged in`);

// ✅
logger.info('User logged in', {
  userId: id,
  ip,
  requestId,  // ⚠️ 全ログに含める
  timestamp: new Date().toISOString()
});
```

## 🚫 機密情報

```
❌ password, token, secret をログ出力
✅ サニタイズしてからログ
```

## リクエストID

⚠️ 全ログに含める。リクエスト追跡用。

```typescript
app.use((req, res, next) => {
  req.requestId = req.headers['x-request-id'] || uuid();
  next();
});
```

## 4つのゴールデンシグナル

1. レイテンシ(応答時間)
2. トラフィック(リクエスト数)
3. エラー率
4. サチュレーション(リソース使用率)
