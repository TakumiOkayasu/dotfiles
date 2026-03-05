---
paths:
  - "tests/**/*"
  - "test/**/*"
  - "**/test_*.c"
---

# テスト規約 (C)

- Unity Test / CUnit / 自作マクロを使用
- Arrange-Act-Assert パターン
- テスト名は「何を」「どの条件で」「どうなるか」
- メモリリークテストを含める (valgrind 等)
- 境界値テストを必ず含める
