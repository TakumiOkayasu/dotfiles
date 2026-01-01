---
name: performance-optimization
description: パフォーマンス最適化やプロファイリング時に使用。計測とよくあるボトルネックをカバー。
---

# Performance Optimization

## トリガー

- パフォーマンス問題発生時
- ボトルネック調査時
- クエリ最適化時
- プロファイリング実施時

## 鉄則

**計測なき最適化は推測。Profile → Measure → Optimize → Verify**

## プロファイリング

```bash
# Node.js
node --prof app.js

# Python
python -m cProfile -o output.prof script.py
```

## よくあるボトルネック

### N+1クエリ

```typescript
// ❌
for (const user of users) {
  const orders = await db.orders.findByUser(user.id);
}

// ✅
const orders = await db.orders.findByUserIds(users.map(u => u.id));
```

### O(n²)アルゴリズム

```typescript
// ❌ O(n) 検索
const items = ['a', 'b', 'c'];
items.includes(target);

// ✅ O(1) 検索
const itemSet = new Set(['a', 'b', 'c']);
itemSet.has(target);
```

### 不要な再計算

```typescript
// メモ化
const cache = new Map();
function expensive(key) {
  if (cache.has(key)) return cache.get(key);
  const result = /* 重い計算 */;
  cache.set(key, result);
  return result;
}
```

## データベース

```sql
-- インデックス
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- 必要なカラムのみ
SELECT id, name FROM users;  -- ✅
SELECT * FROM users;         -- ❌

-- EXPLAIN で確認
EXPLAIN ANALYZE SELECT ...;
```

## アンチパターン

```
❌ 早すぎる最適化(計測前に最適化)
❌ 1%の処理を10倍速くする(50%の処理を2倍速くすべき)
```
