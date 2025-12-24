---
name: database-design
description: スキーマ設計やマイグレーション作成時に使用。
---

# Database Design

## 🚨 鉄則

**データモデルは変更コストが高い。慎重に設計。**

## 必須カラム

```sql
CREATE TABLE posts (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  -- ...
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

## マイグレーション

```sql
-- ✅ 安全: NULL許可で追加
ALTER TABLE users ADD COLUMN phone VARCHAR(20) NULL;

-- ⚠️ NOT NULLは段階的に
-- 1. NULL許可で追加
-- 2. データ移行
-- 3. NOT NULL制約追加
```

## 🚫 N+1回避

```sql
-- ❌
SELECT * FROM users;
SELECT * FROM orders WHERE user_id = ?;  -- N回

-- ✅
SELECT * FROM orders WHERE user_id IN (1, 2, 3);
```

## ページネーション

```sql
-- ❌ OFFSET(大きいと遅い)
SELECT * FROM orders LIMIT 20 OFFSET 10000;

-- ✅ カーソル
SELECT * FROM orders WHERE id > :last_id LIMIT 20;
```
