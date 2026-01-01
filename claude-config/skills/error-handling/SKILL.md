---
name: error-handling
description: エラーハンドリングを実装する際に使用。回復戦略と復元パターンをカバー。
---

# Error Handling

## トリガー

- 例外処理実装時
- try-catch設計時
- リトライロジック実装時
- エラーレスポンス設計時

## 鉄則

**回復可能かどうかで処理を分ける。**

## エラー分類

```typescript
// 回復可能(リトライ対象)
class TransientError extends Error { retryable = true; }

// 回復不可能
class PermanentError extends Error { retryable = false; }
```

## パターン

### 早期リターン

```typescript
function process(data: Data | null) {
  if (!data) throw new Error('No data');
  if (!data.isValid) throw new Error('Invalid');
  // 正常処理
}
```

### Result型

```typescript
type Result<T> = { ok: true; value: T } | { ok: false; error: Error };
```

### リトライ(指数バックオフ)

```typescript
for (let i = 0; i <= maxRetries; i++) {
  try { return await fn(); }
  catch { await sleep(Math.pow(2, i) * 1000); }
}
```

### サーキットブレーカー

```
CLOSED(正常) → 失敗増加 → OPEN(遮断) → 時間経過 → HALF_OPEN → 成功 → CLOSED
```

## 非同期

```typescript
// Promise: catchを忘れない
fetch().then(process).catch(handleError);

// async/await: try-catch
try { await fetch(); }
catch (e) {
  if (e instanceof ValidationError) return { status: 400 };
  throw e;
}
```

## フォールバック

```typescript
try { return await primary.get(key); }
catch { return await fallback.get(key); }
```
