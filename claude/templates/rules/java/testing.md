---
paths:
  - "src/test/**/*"
  - "**/*Test.java"
  - "**/*Tests.java"
---

# テスト規約 (Java)

- JUnit 5 を使用
- Arrange-Act-Assert パターン
- テスト名は「何を」「どの条件で」「どうなるか」
- モックは Mockito を使用、最小限に
- `@Nested` でテストをグルーピング
