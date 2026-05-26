---
name: commit-msg
summary: staged diff から Conventional Commits の commit message 案だけを作る
profile: read-only
skills:
  - codex-handoff
---

# commit-msg

$ARGUMENTS

## Purpose

ステージ済み差分から commit message 案を作る。commit / push / git add は実行しない。

## Steps

1. `git status --short` を確認する。
2. `git diff --staged` を確認する。
3. staged diff が空なら中止する。
4. 差分を論理単位に分類する。
5. Conventional Commits の候補を1-3件提示する。

## Checks

- secrets らしき値が staged に含まれていないか。
- 無関係な変更が混ざっていないか。
- lockfile 差分がある場合、依存変更と整合しているか。
- 1 commit = 1 logical change になっているか。

## Output

```text
推奨:
<type>: <summary>

本文:
- ...

代替案:
1. ...
2. ...

実行する場合:
git commit -m "<type>: <summary>"
```
