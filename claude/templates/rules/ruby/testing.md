---
paths:
  - "spec/**/*"
  - "test/**/*"
---

# テスト規約 (Ruby)

- RSpec を標準使用 (Minitest も可)
- Arrange-Act-Assert パターン
- `describe` / `context` / `it` で構造化
- テスト名は「何を」「どの条件で」「どうなるか」
- モックは最小限に (`instance_double` を使用)
