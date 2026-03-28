# テスト規約 (Rust)

## 適用条件

- 対象パス: `tests/**/*`, `**/tests.rs`
- トリガー: Rustのテストコードを新規作成・修正するとき

## 手順

1. テストの種別を判断する
   - ユニットテスト → ソースファイル末尾の `#[cfg(test)]` モジュールに記述
   - 結合テスト → `tests/` ディレクトリに独立ファイルで記述

2. テスト関数を `#[test]` アトリビュートで宣言する

3. テスト名を「何を_どの条件で_どうなるか」の形式で命名する
   - 例: `add_with_positive_numbers_returns_sum`
   - 例: `parse_empty_string_returns_error`

4. テスト本体を Arrange-Act-Assert の3ブロックで構成する
   - `// Arrange`: テスト対象の入力・前提条件を用意する
   - `// Act`: テスト対象の関数・メソッドを呼び出す
   - `// Assert`: 期待する結果を `assert_eq!` / `assert!` で検証する

## 入力・出力

| 項目 | 内容 |
|------|------|
| 入力 | テスト対象の関数・構造体・モジュール |
| 出力 | `#[test]` 関数（パス時: 何も返さない / 失敗時: `panic!`） |

## 使用例

```rust
// ユニットテスト（ソースファイル末尾）
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_with_positive_numbers_returns_sum() {
        // Arrange
        let a = 2;
        let b = 3;

        // Act
        let result = add(a, b);

        // Assert
        assert_eq!(result, 5);
    }
}
```

```rust
// 結合テスト（tests/integration_test.rs）
use my_crate::add;

#[test]
fn add_integrates_with_public_api() {
    // Arrange
    let a = 10;
    let b = 20;

    // Act
    let result = add(a, b);

    // Assert
    assert_eq!(result, 30);
}
```

## 禁止事項

- テスト名を `test1` / `test_foo` のような意味のない名前にしない
- Arrange・Act・Assert を混在させない
- 1テスト関数で複数の独立した振る舞いを検証しない
