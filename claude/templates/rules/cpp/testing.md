# テスト規約 (C++)

## 入力

- C++テストファイル (`tests/**/*`, `**/test_*.cpp`)

## 出力

- Google Test または Catch2 形式のテストコード

## 処理手順

1. テストフレームワークを確認する（Google Test または Catch2）
2. Arrange-Act-Assert パターンで構造化する
   - **Arrange**: テスト対象の初期化・前提条件セット
   - **Act**: テスト対象の操作・実行
   - **Assert**: 期待値との比較・検証
3. テスト名を `何を_どの条件で_どうなるか` の形式で命名する
4. モックは必要最小限に留める

## 命名規則

```
TEST(対象クラス名, 何を_どの条件で_どうなるか)
```

## 使用例

```cpp
// Google Test
TEST(Calculator, Add_PositiveNumbers_ReturnsSum) {
    // Arrange
    Calculator calc;

    // Act
    int result = calc.add(2, 3);

    // Assert
    EXPECT_EQ(result, 5);
}
```

## 禁止事項

- テスト名に曖昧な表現 (`test1`, `checkIt` 等) を使用しない
- 複数の責務を1テストに詰め込まない
- 不要なモックを追加しない
