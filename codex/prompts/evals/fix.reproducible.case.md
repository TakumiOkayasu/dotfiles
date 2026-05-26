# Eval: fix reproducible

## Scenario

特定入力で null dereference が発生する。再現手順と stack trace がある。

## Expected

- systematic-debugging を使う
- stack trace 原文を確認する
- 原因特定前に修正しない
- regression test を追加する
- 最小修正に留める
- 再発防止を報告する
