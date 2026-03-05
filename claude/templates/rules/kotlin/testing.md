---
paths:
  - "src/test/**/*"
  - "**/*Test.kt"
  - "**/*Tests.kt"
---

# テスト規約 (Kotlin)

- JUnit 5 + MockK を使用
- Arrange-Act-Assert パターン
- テスト名は「何を」「どの条件で」「どうなるか」
- バッククォートでテスト名を日本語可: `` `ユーザーが存在しない場合にnullを返す` ``
- `@Nested` でテストをグルーピング
