# テスト規約 (C++)

## トリガー条件

以下のファイルが対象:
- `tests/**/*`
- `**/test_*.cpp`

## 手順

1. **フレームワーク選択**: Google Test または Catch2 を使用する
2. **テスト構造**: Arrange-Act-Assert パターンで記述する
   - Arrange: テスト対象の初期化・前提条件の設定
   - Act: テスト対象の実行
   - Assert: 結果の検証
3. **テスト名**: `テスト名は「何を」「どの条件で」「どうなるか」の形式で命名する`
   - 例: `Add_WhenBothPositive_ReturnsSum`
4. **モック**: 外部依存が避けられない場合のみ使用し、最小限に留める

## 入力

- テスト対象のソースファイル
- テスト要件・仕様

## 出力

- `tests/` または対象ディレクトリ配下に `test_*.cpp` ファイルを作成
- 各テストファイルは対応するソースファイルの責務に対応させる

## 使用例

```cpp
// Arrange
Calculator calc;
int a = 3, b = 5;

// Act
int result = calc.Add(a, b);

// Assert
EXPECT_EQ(result, 8);
```
