---
name: prompt-command-router
description: ユーザー入力 `prompt:<name>` を repo-local prompt command として解釈し、対応する `prompts/commands/<name>.md` を主指示として実行する。prompt command / custom prompt / slash風コマンドの処理で使用。
---

# Prompt Command Router

## Purpose

`prompt:*` は built-in slash command ではなく、この dotfiles が提供する repo-local prompt command である。Codex がこの入力を見たら、literal な `prompt:*` をタスク本文とは扱わず、対応する prompt file の展開結果を実行する。

## Resolution

1. 入力が `prompt:<name> <arguments>` なら `<name>` を prompt 名、残りを `$ARGUMENTS` として扱う。
2. 入力が `/prompt <name> <arguments>` なら同様に扱う。
3. 探索順:
   - `./codex/prompts/commands/<name>.md`
   - `./.codex/prompts/commands/<name>.md`
   - `~/.codex/prompts/commands/<name>.md`
4. 見つからない場合は `prompt:list` を案内する。
5. `$ARGUMENTS` を置換した prompt 本文をこのターンの主指示とする。

## Available commands

- feat
- fix
- deep-review
- review
- security-review
- commit-msg
- commit
- plan
- explain
- test
- refactor
- prompt-tune
- handoff

## Rules

- prompt command は「起動 router」。詳細手順は skills を参照する。
- prompt file と skill が矛盾する場合は、より具体的な project `AGENTS.md` とユーザー指示を優先する。
- unknown slash として処理できない環境では、`codex-prompt expand /prompt:<name> ...` を使う。
- `prompt:*` 自体を shell command として実行しない。

## Output when expanded

展開時は以下を明示する。

```text
[prompt-command expanded: /prompt:<name>]
Arguments: ...
Expanded prompt: ...
```
