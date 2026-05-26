# Validation Fragment

優先順:

1. プロジェクト定義の test
2. lint
3. typecheck
4. build
5. focused test
6. smoke test

ルール:

- 実行していない検証を「通った」と書かない。
- 実行できない場合は理由を書く。
- 新規依存を追加した場合は脆弱性スキャンを検討する。
- テストが重い場合は focused test を先に実行し、全体検証を未実行として明記する。
