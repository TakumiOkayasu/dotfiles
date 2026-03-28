# テスト規約 (C#)

---
paths:
  - "**/*Tests.cs"
  - "**/*Test.cs"
  - "tests/**/*"
---

## 目的

C#プロジェクトのテストコードを規約に沿って記述・レビューする。

## 入力

- テスト対象のC#ソースファイル（`*Tests.cs` / `*Test.cs` / `tests/**/*`）
- 実装コード（テスト対象クラス・メソッド）

## 処理手順

1. **フレームワーク選定**: xUnit を優先採用。既存プロジェクトが NUnit の場合は NUnit を継続使用
2. **テスト構造**: Arrange-Act-Assert パターンで各テストメソッドを3ブロックに分割
3. **テスト名付け**: `[対象メソッド]_[条件]_[期待結果]` の形式で命名
4. **モック設定**: Moq または NSubstitute を使用し、テストに必要な最小限のモックのみ定義
5. **パラメータ化**: 同一ロジックで複数の入力値を検証する場合は `[Theory]` + `[InlineData]` を使用

## 出力

- 規約に準拠したテストメソッド
- 明確な Arrange / Act / Assert コメントブロック（任意）

## 使用例

```csharp
// テスト名: メソッド名_条件_期待結果
public class CalculatorTests
{
    [Fact]
    public void Add_WhenBothPositive_ReturnsSum()
    {
        // Arrange
        var calculator = new Calculator();

        // Act
        var result = calculator.Add(2, 3);

        // Assert
        Assert.Equal(5, result);
    }

    [Theory]
    [InlineData(0, 0, 0)]
    [InlineData(1, -1, 0)]
    [InlineData(int.MaxValue, 0, int.MaxValue)]
    public void Add_WithVariousInputs_ReturnsExpectedSum(int a, int b, int expected)
    {
        var calculator = new Calculator();
        Assert.Equal(expected, calculator.Add(a, b));
    }
}
```

## 規約サマリ

| 項目 | 規約 |
|------|------|
| フレームワーク | xUnit（推奨）/ NUnit（可） |
| パターン | Arrange-Act-Assert |
| 命名 | `対象_条件_期待結果` |
| モック | Moq / NSubstitute、最小限のみ |
| パラメータ化 | `[Theory]` + `[InlineData]` |
