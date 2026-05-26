---
name: deep-review
summary: 差分を security / performance / maintainability の3観点で統合レビューする
profile: review
skills:
  - deep-review
  - security-review
  - performance-optimization
  - refactoring
  - test-coverage-guard
---

# deep-review

$ARGUMENTS

## Purpose

対象差分を多角的にレビューし、BLOCK / WARN / PASS を返す。

## Scope resolution

- `$ARGUMENTS` がある場合はその指定を優先する。
- 指定がない場合は `git diff HEAD` を対象にする。
- working tree が空なら `git diff HEAD~1..HEAD` を確認する。

## Required routing

1. 変更目的・変更ファイル・依存関係を把握する。
2. 適用される `AGENTS.md` と `.codex/rules` を必要範囲だけ読む。
3. subagent が使える場合は security / performance / maintainability を並列 dispatch する。
4. subagent が使えない場合は `subagent fallback: parent-session review` と明示し、同じ3観点で親セッション内レビューを行う。
5. `deep-review` skill で findings を統合する。

## Severity

- Critical: 本番障害、データ損失、脆弱性、破壊的 API 変更、規約の明示的禁止違反、方針検証スキップ。
- Warning: マージ前に対処推奨の設計・性能・テスト・保守性問題。
- Suggestion: 任意改善。

## Output

```text
## 判定: BLOCK|WARN|PASS

| 重要度 | 件数 | 観点内訳 |
| --- | ---: | --- |

### [重要度] [観点タグ] カテゴリ
N. file:line — 要約
❌ 現状: <該当コード>
✅ 修正案: <修正コード>
理由: <根拠>
```

## Prohibitions

- 修正案なしの指摘を出さない。
- 推測指摘を出さない。
- 良い点セクションを作らない。
- style-only 指摘は linter / formatter に委譲する。
