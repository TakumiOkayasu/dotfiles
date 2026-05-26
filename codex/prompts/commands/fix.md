---
name: fix
summary: バグを再現し、根本原因を特定してから最小修正する
profile: safe-write
skills:
  - systematic-debugging
  - tdd
  - premise-questioning
  - failure-logging
  - test-coverage-guard
---

# fix

$ARGUMENTS

## Purpose

バグを修正する。再現なし・根本原因なしの修正は禁止。

## Required routing

1. `systematic-debugging` を使い、再現 → 境界トレース → 根本原因 → 修正方針の順で進める。
2. 修正方針が high-risk の場合は `premise-questioning` を挟む。
3. バグを再現する regression test を `tdd` で追加する。
4. 同じ失敗を2回以上したら `failure-logging` を使う。
5. GREEN 後、必要なら `test-coverage-guard` で偽陽性を確認する。

## Constraints

- 再現できない場合は修正せず、再現不能の理由と次の調査案を出す。
- エラー・ログ・stack trace は原文を確認する。
- 推測で原因を決めない。
- 対症療法ではなく根本原因に対する最小修正を行う。
- 既存ユーザー変更を戻さない。

## Output

- 症状:
- 再現手順:
- 根本原因:
- 修正内容:
- 変更ファイル:
- 検証:
- 未検証:
- 再発防止:
