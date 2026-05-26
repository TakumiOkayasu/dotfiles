---
name: refactor
summary: 振る舞いを変えずに構造改善する
profile: safe-write
skills:
  - refactoring
  - test-coverage-guard
  - premise-questioning
---

# refactor

$ARGUMENTS

## Purpose

振る舞いを変えずにコード構造を改善する。

## Required routing

1. 既存テストと検証コマンドを確認する。
2. `refactoring` skill を使う。
3. 100行超・公開 API・レイヤー再編・依存変更を伴う場合は `premise-questioning` を使う。
4. GREEN 後、必要に応じて `test-coverage-guard` を使う。

## Constraints

- public API と入出力を変えない。
- 1変更 = 1目的。
- 無関係な整形・命名変更を混ぜない。
- テストがない場合は、先に characterization test または安全網の提案をする。

## Output

- 対象:
- 変更したスメル:
- 変更ファイル:
- 振る舞い不変の確認:
- 検証:
- 未検証:
