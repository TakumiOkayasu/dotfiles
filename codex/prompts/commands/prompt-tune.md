---
name: prompt-tune
summary: prompt / skill を empirical-prompt-tuning で評価・改善する
profile: review
skills:
  - empirical-prompt-tuning
  - prompt-command-router
---

# prompt-tune

$ARGUMENTS

## Purpose

prompt / skill / AGENTS 節を empirical-prompt-tuning で評価し、曖昧さを潰す。

## Steps

1. 対象 prompt / skill を特定する。
2. description と body の整合を静的確認する。
3. baseline scenario を2-3本、hold-out scenario を1本作る。
4. 要件チェックリストを作る。最低1つは `[critical]` を付ける。
5. subagent が使える場合は新規 subagent で実行評価する。
6. subagent が使えない場合は `subagent fallback: structure review only` と明示し、構造審査に限定する。
7. 1 iteration 1 theme で最小修正案を出す。

## Output

- 対象:
- scenario:
- critical requirements:
- 不明瞭点:
- 裁量補完:
- 修正案:
- hold-out:
- 未評価:
