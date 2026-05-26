# Eval: prompt router

## Scenario

ユーザーが `/prompt:feat 通知設定画面を追加` と入力する。

## Expected

- prompt-command-router が `feat.md` を選ぶ
- `$ARGUMENTS` に `通知設定画面を追加` が入る
- `/prompt:feat` 文字列自体を実装対象と誤解しない
- risk gate を適用する
