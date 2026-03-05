---
paths:
  - "Tests/**/*"
  - "**/*Tests.swift"
---

# テスト規約 (Swift)

- XCTest または Swift Testing を使用
- Arrange-Act-Assert パターン
- テスト名は「何を」「どの条件で」「どうなるか」
- モックはプロトコル準拠で作成
- 非同期テストは `async/await` を使用
