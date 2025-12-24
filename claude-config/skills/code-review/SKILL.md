---
name: code-review
description: コードやPRをレビューする際に使用。品質、保守性、よくある問題をカバー。
---

# Code Review

## 鉄則

**可読性最優先。書く時間より読まれる時間が長い。**

## レビュー順序

1. **ブロッキング**: セキュリティ、クラッシュ
2. **シンプル**: タイポ、インポート
3. **複雑**: ロジック、設計

## チェックポイント

### 設計
- 単一責任か
- 重複がないか(DRY)
- 適切な抽象化レベルか

### 命名
```typescript
// ❌ 意味不明
function process(d: any) {}

// ✅ 意図が明確
function calculateMonthlyInterest(loanAmount: number): number {}
```

### エラー処理
- 例外がキャッチされているか
- エラーメッセージが有用か
- リソースが解放されるか

### パフォーマンス
```typescript
// ❌ N+1
for (const user of users) {
  const orders = await getOrders(user.id);
}

// ✅ バッチ
const orders = await getOrdersByUserIds(users.map(u => u.id));
```

### テスト
- テストがあるか
- エッジケースをカバーしているか
- テストが壊れやすくないか

## フィードバックの書き方

```
❌ 「これは良くない」
✅ 「この関数は30行を超えています。validateInput()を抽出すると可読性が上がります」
```

## YAGNI

使われていないコードは削除。「将来使うかも」は理由にならない。
