---
paths:
  - "tests/**/*"
  - "**/tests.rs"
---

# テスト規約 (Rust)

- 標準 `#[test]` アトリビュートを使用
- Arrange-Act-Assert パターン
- テスト名は「何を」「どの条件で」「どうなるか」
- `#[cfg(test)]` モジュールでユニットテスト
- `tests/` ディレクトリで結合テスト
