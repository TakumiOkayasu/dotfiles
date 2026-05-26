---
name: feat
summary: 新機能を risk-based TDD で実装する
profile: safe-write
skills:
  - implementation-router
  - premise-questioning
  - feature-pruning
  - interface-first-design
  - tdd
  - test-coverage-guard
---

# feat

$ARGUMENTS

## Purpose

新機能を実装する。詳細手順をこの prompt に閉じ込めず、risk 判定で必要な skill を選ぶ。

## Required routing

1. まず `implementation-router` skill の risk gate を適用する。
2. high-risk の場合は実装前に計画と承認を得る。
3. 新規 class / module / interface を伴う場合は `interface-first-design` を使う。
4. 仕様が確定している実装は `tdd` を使う。
5. UI / API / DB column など機能粒度の過剰設計が疑われる場合は `feature-pruning` を使う。
6. 100行超、外部依存、DB schema、公開 API、認証認可、課金、secrets に触れる場合は `premise-questioning` を使う。

## Constraints

- 未読ファイルを編集しない。
- 既存テスト・命名・層構造を先に確認する。
- 依存追加、DB schema、公開 API、破壊的変更は確認なしに進めない。
- 仕様が曖昧な場合は `[要確認: ...]` を出す。推測で仕様を作らない。
- low-risk で仕様が明確なら、過剰な承認待ちは避けて最小実装まで進める。

## Done when

- 変更ファイルが目的に対して最小。
- テスト / lint / typecheck / build のうちプロジェクトで定義された検証を実行、または未実行理由を明示。
- 完了報告に変更・検証・未検証・注意を含める。
