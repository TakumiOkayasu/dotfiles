---
name: deep-review
description: 差分を security / performance / maintainability の3観点で統合レビューする。subagent が使える場合は並列 dispatch、使えない場合は親セッション内 fallback。
---

# Deep Review

## Purpose

差分を多角的にレビューし、actionable な指摘だけを重要度順に統合する。

## Inputs

- review target: branch / commit / path / working tree diff
- `git diff` or equivalent patch
- applicable `AGENTS.md`
- applicable rules / project conventions

## Workflow

1. 差分取得: 引数ありなら対象、なしなら `git diff HEAD`。
2. 全体把握: 目的、変更ファイル、依存関係、公開 contract を整理する。
3. ルール特定: 今回の差分で違反しうるルールだけ読む。
4. 観点分割:
   - security
   - performance
   - maintainability
5. subagent dispatch:
   - 可能なら3観点を並列 dispatch。
   - 不可能なら `subagent fallback: parent-session review` と明示して親セッションで同じ観点分解を行う。
6. synthesis:
   - 同一 file:line を統合。
   - 重要度は最高位を採用。
   - Critical → Warning → Suggestion、同重要度内は file:line 昇順。
7. 自己検証:
   - 推測指摘がないか。
   - 修正案が実在 API に基づくか。
   - 指摘に fix proposal があるか。

## Severity

| Severity | Meaning |
| --- | --- |
| Critical | マージ不可。本番障害・データ損失・脆弱性・破壊的 contract 変更 |
| Warning | マージ前に対処推奨 |
| Suggestion | 任意改善 |

## Decision

| 判定 | 条件 |
| --- | --- |
| BLOCK | Critical 1件以上 |
| WARN | Critical 0件 かつ Warning 3件以上 |
| PASS | Critical 0件 かつ Warning 2件以下 |

## Output

```text
## 判定: BLOCK|WARN|PASS

| 重要度 | 件数 | 観点内訳 |
| --- | ---: | --- |

### [重要度] [観点タグ] カテゴリ
N. file:line — 要約
❌ 現状: <コード>
✅ 修正案: <コード>
理由: <根拠>
```

## Prohibitions

- 修正案なしの指摘
- 推測指摘
- style-only 指摘
- 良い点セクション
- 観点外への侵食
