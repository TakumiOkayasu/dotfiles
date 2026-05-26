---
name: test
summary: テスト設計・テスト追加・テスト品質確認を行う
profile: safe-write
skills:
  - tdd
  - test-coverage-guard
  - systematic-debugging
---

# test

$ARGUMENTS

## Purpose

指定機能・バグ・差分に対して意味のあるテストを追加または改善する。

## Routing

- 新しい振る舞いのテスト追加 → `tdd`
- バグ再現テスト → `systematic-debugging` → `tdd`
- 既存テストの品質レビュー → `test-coverage-guard`

## Constraints

- 既存テスト配置・命名・runner を先に確認する。
- 期待値が仕様判断を含む場合は確認する。
- `toBeDefined()` だけ、snapshot 丸投げ、mock 過多のテストを書かない。
- テストが実行できない場合は理由と未検証リスクを明示する。

## Output

- テスト目的:
- 追加 / 変更テスト:
- 検証した振る舞い:
- 実行コマンド:
- 結果:
- 未検証:
