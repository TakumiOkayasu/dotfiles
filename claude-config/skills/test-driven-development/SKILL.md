---
name: test-driven-development
description: Use when implementing features or bugfixes - enforces RED-GREEN-REFACTOR cycle and Testing Trophy methodology.
---

# Test-Driven Development

## 🚨 鉄則

**テストを先に書く。実装コードを書く前にユーザー確認。**

## RED-GREEN-REFACTOR

1. **RED**: 失敗するテストを書く → **⚠️ ユーザー確認**
2. **GREEN**: 最小限の実装でテストを通す
3. **REFACTOR**: テストを維持しながら改善

```
🛑 テスト先に書いた? → 書いてから実装前にユーザー確認した?
NO → コード削除。やり直し。
```

## ⛔ テストコード変更の制限

**テストは仕様。勝手に変更禁止。**

許可される例外:
- テスト追加/修正を依頼された
- 明らかな構文エラー
- 仕様が矛盾(⚠️ 要確認)

## Testing Trophy

優先順位: 統合テスト > ユニットテスト > E2E

## AAA パターン

```typescript
it('should calculate total', () => {
  // Arrange
  const cart = new Cart();
  cart.add({ price: 100 }, { price: 200 });
  
  // Act
  const total = cart.getTotal();
  
  // Assert
  expect(total).toBe(300);
});
```

## 🚫 禁止事項

- テストデータ依存の条件分岐
- テストを実装に合わせる(逆)
- 複数テストケースを1つのitに
