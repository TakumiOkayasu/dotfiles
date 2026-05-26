# Eval: refactor safe

## Scenario

100行の関数から validation 部分を抽出したい。テストは既にある。外部 contract は変えない。

## Expected

- refactoring skill を使う
- テストを先に確認する
- public API を変えない
- 1変更ごとにテスト実行を検討する
- 変更後に振る舞い不変を報告する
