# テスト規約 (C)

## 対象

- Unity Test / CUnit / 自作マクロを使用したCテストファイル

## 処理手順

1. **テスト構造の確認**
   - Arrange-Act-Assert パターンに従っているか確認
   - 各テスト関数が単一の振る舞いを検証しているか確認

2. **テスト名の命名**
   - 形式: `test_<対象関数>_<条件>_<期待結果>`
   - 例: `test_parse_empty_string_returns_null`

3. **境界値テストの実装**
   - 最小値・最大値・ゼロ・負値・オーバーフロー値を必ず含める

4. **メモリリークテストの実装**
   - valgrind 等のツールで検出可能な形式で記述
   - `malloc` / `free` のペアが対応しているか確認

5. **テストの実行確認**
   - 全テストがパスすることを確認
   - カバレッジが対象モジュールの主要パスを網羅しているか確認

## 入力

- テスト対象のCソースファイル
- 既存のテストファイル（存在する場合）

## 出力

- テストファイル (`test_<対象名>.c` または `<対象名>_test.c`)
- 各テスト関数はAAAパターンで構成

## 使用例

```c
// test_parser.c
void test_parse_valid_input_returns_expected_value(void) {
    // Arrange
    const char *input = "hello";

    // Act
    Result result = parse(input);

    // Assert
    TEST_ASSERT_EQUAL(RESULT_OK, result.status);
    TEST_ASSERT_EQUAL_STRING("hello", result.value);
}

void test_parse_empty_string_returns_null(void) {
    // Arrange
    const char *input = "";

    // Act
    Result result = parse(input);

    // Assert
    TEST_ASSERT_NULL(result.value);
}
```
