---
paths:
  - "**/*Tests.cs"
  - "**/*Test.cs"
  - "tests/**/*"
---

# テスト規約 (C#)

- xUnit を標準使用 (NUnit も可)
- Arrange-Act-Assert パターン
- テスト名は「何を」「どの条件で」「どうなるか」
- モックは Moq または NSubstitute を使用、最小限に
- `[Theory]` + `[InlineData]` でパラメータ化テスト
