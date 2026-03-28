# テスト規約 (C)

## 概要

Cプロジェクトのテストファイル作成・レビュー時に適用するテスト規約。

## 対象

- `tests/**/*`
- `test/**/*`
- `**/test_*.c`

## テストフレームワーク

使用するフレームワーク（いずれか）:

- Unity Test
- CUnit
- 自作マクロ

## 処理手順

1. **テスト名の決定**: 「何を」「どの条件で」「どうなるか」を明示する命名とする
   - 例: `test_parse_integer_returns_zero_when_input_is_empty`
2. **テスト構造**: Arrange-Act-Assert (AAA) パターンで記述する
   - `// Arrange` — 前提条件・データ準備
   - `// Act` — テスト対象の実行
   - `// Assert` — 結果検証
3. **境界値テスト**: 最小値・最大値・ゼロ・負数・オーバーフロー値を必ず含める
4. **メモリリークテスト**: `valgrind` 等のツールで動的メモリの解放漏れを検証するテストを含める

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | テスト対象の `.c` / `.h` ファイル |
| 出力 | AAA構造・命名規約に準拠したテストファイル |

## 使用例

```c
void test_add_returns_sum_when_both_positive(void) {
    // Arrange
    int a = 3, b = 5;

    // Act
    int result = add(a, b);

    // Assert
    TEST_ASSERT_EQUAL_INT(8, result);
}
```
