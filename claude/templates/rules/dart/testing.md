---
paths:
  - "test/**/*"
  - "**/*_test.dart"
---

# テスト規約 (Dart)

- dart test / flutter_test を使用
- Arrange-Act-Assert パターン
- `group` / `test` で構造化
- テスト名は「何を」「どの条件で」「どうなるか」
- Widget テストは `testWidgets` + `WidgetTester` を使用
