---
name: concurrency-async
description: 並行処理や非同期操作を実装する際に使用。
---

# Concurrency and Async

## トリガー

- 並列処理実装時
- async/await使用時
- 競合状態の懸念がある時
- Promise.all等の並列実行時

## 🚨 鉄則

**競合状態を常に意識。シンプルに保つ。**

## 並列実行

```typescript
// ✅ 独立タスクは並列
const [users, products] = await Promise.all([
  fetchUsers(),
  fetchProducts()
]);

// ❌ 不要な順次実行
const users = await fetchUsers();
const products = await fetchProducts();
```

## ⚠️ 競合状態

```typescript
// ❌ 競合あり(読み取り→待機→書き込み)
let count = 0;
async function increment() {
  const c = count;
  await delay(100);
  count = c + 1;  // 🚫 古い値ベース
}

// ✅ アトミック操作
await redis.incr('counter');
```

## 並列数制限

```typescript
import pLimit from 'p-limit';
const limit = pLimit(5);  // ⚠️ 同時5つまで

await Promise.all(urls.map(url => limit(() => fetch(url))));
```

## キャンセル

```typescript
const controller = new AbortController();
setTimeout(() => controller.abort(), 5000);

await fetch(url, { signal: controller.signal });
```

## 🚫 デッドロック回避

```typescript
// 順序付きロック(IDでソート)
const [first, second] = a.id < b.id ? [a, b] : [b, a];
await first.lock();
await second.lock();
```
