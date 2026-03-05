---
paths:
  - "**/*.test.ts"
  - "**/*.spec.ts"
  - "**/*.test.tsx"
  - "**/*.spec.tsx"
  - "tests/**/*"
---

# テスト規約 (TypeScript)

- vitest または jest を使用
- Arrange-Act-Assert パターン
- テスト名は「何を」「どの条件で」「どうなるか」
- モックは最小限に
- React の場合は Testing Library
