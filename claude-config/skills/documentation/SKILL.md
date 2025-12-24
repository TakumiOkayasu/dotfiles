---
name: documentation
description: ドキュメント、README、コードコメントを書く際に使用。
---

# Documentation

## 鉄則

**読者が必要な情報を素早く見つけられる構造にする。**

## README構造

```markdown
# プロジェクト名

簡潔な説明(1-2文)

## クイックスタート

npm install && npm start

## 使用例

コード例

## ドキュメント

詳細はdocs/を参照
```

## コードコメント

```typescript
// ✅ WHY(なぜ)を説明
// Rate limitを超えたため指数バックオフ
await delay(Math.pow(2, retryCount) * 1000);

// ❌ WHAT(何)を説明(見ればわかる)
// カウンターをインクリメント
counter++;

// ✅ ワークアラウンドの理由
// HACK: Safari 15.4のバグ回避 https://bugs.webkit.org/...
```

## JSDoc

```typescript
/**
 * 月利を計算する
 * @param principal - 元本(円)
 * @param rate - 年利(0.05 = 5%)
 * @returns 月利(円)
 */
function calculateMonthlyInterest(principal: number, rate: number): number
```

## アンチパターン

```
❌ 古いまま放置
❌ コードと矛盾
❌ 「明らかだから書かない」
❌ 専門用語を説明なく使用
```
