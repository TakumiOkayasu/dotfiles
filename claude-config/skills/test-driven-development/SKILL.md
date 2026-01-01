---
## name: test-driven-development
description: 機能実装やバグ修正時に使用。RED-GREEN-REFACTORサイクルとTesting Trophy手法を強制。
---

# Test-Driven Development

## トリガー

- 新機能実装時
- バグ修正時
- リファクタリング前
- テストコード追加時

## 🚨 鉄則

**テストを先に書く。実装コードを書く前にユーザー確認。**

## RED-GREEN-REFACTOR

1. **RED**: 失敗するテストを書く → **⚠️ ユーザー確認**
1. **GREEN**: 最小限の実装でテストを通す
1. **REFACTOR**: テストを維持しながら改善

```text
🛑 テスト先に書いた? → 書いてから実装前にユーザー確認した?
NO → コード削除。やり直し。
```

## TDD実践テクニック(t-wada流)

### 基本姿勢

- 小さなステップで進める
- 不安なところからテストを書く
- 複数のテストを同時に書かない(1つずつ)

### 実装戦略

- **仮実装**: テストを通すためにベタ書き(`return 42`)でもOK
- **三角測量**: 2つ目、3つ目のテストケースで一般化する
- **明白な実装**: 答えが分かる場合は直接実装してもOK

### TODOリスト

- テストリストを常に更新する
- 実装中に思いついたことは即リストに追加
- 完了したらチェックを入れる

### コミットルール

- 🔴 テスト追加: `test: add failing test for [feature]`
- 🟢 実装: `feat: implement [feature] to pass test`
- 🔵 リファクタ: `refactor: [description]`
- テストが通ったらすぐコミット(小さく頻繁に)

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