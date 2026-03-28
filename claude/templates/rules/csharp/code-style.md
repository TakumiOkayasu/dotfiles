# テスト規約 (C#)

## 適用対象

- `**/*Tests.cs`
- `**/*Test.cs`
- `tests/**/*`

## テストフレームワーク

| 項目 | 内容 |
|------|------|
| 標準 | xUnit |
| 代替 | NUnit も可 |
| モック | Moq または NSubstitute（最小限に使用） |

## 処理手順

### 1. テストクラス・メソッドの命名

- テスト名は **「何を」「どの条件で」「どうなるか」** の3要素を含める
- 例: `Calculate_WhenInputIsZero_ReturnsZero`

### 2. テスト構造 (Arrange-Act-Assert)

```csharp
[Fact]
public void MethodName_Condition_ExpectedResult()
{
    // Arrange: テスト対象の準備
    var sut = new TargetClass();

    // Act: テスト対象の実行
    var result = sut.Method(input);

    // Assert: 結果の検証
    Assert.Equal(expected, result);
}
```

### 3. パラメータ化テスト

```csharp
[Theory]
[InlineData(0, 0)]
[InlineData(1, 1)]
[InlineData(-1, 1)]
public void Abs_GivenInput_ReturnsExpected(int input, int expected)
{
    // Arrange
    var sut = new Calculator();

    // Act
    var result = sut.Abs(input);

    // Assert
    Assert.Equal(expected, result);
}
```

### 4. モックの使用

```csharp
// Moq
var mock = new Mock<IService>();
mock.Setup(s => s.GetValue()).Returns(42);

// NSubstitute
var sub = Substitute.For<IService>();
sub.GetValue().Returns(42);
```

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | C# テストファイル (`*Tests.cs`, `*Test.cs`, `tests/**/*`) |
| 出力 | xUnit / NUnit 規約に準拠したテストコード |

## 禁止事項

- Arrange / Act / Assert コメントの省略
- モックの過剰使用（テスト対象外の依存まで全モック化）
- テスト名に `Test1`, `Method_Test` 等の意味のない命名
