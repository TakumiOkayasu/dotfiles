# Codex prompt trigger hotfix

## 原因

Codex CLI interactive TUI は、先頭 `/` の入力を built-in slash command として先に解釈する。
未登録の `/prompt:*` は `UserPromptSubmit` hook に届く前に拒否される。

そのため repo-local prompt command は、先頭スラッシュなしの `prompt:*` を使う。

## 使用例

```text
prompt:feat ユーザー検索機能を追加
prompt:fix 特定入力で500になる
prompt:deep-review HEADとの差分
prompt:list
```

## 互換性

`prompt-command-expand.sh` は非interactive/将来互換用に `/prompt:*` も受け付けるが、Codex CLI TUI では通常届かない。
