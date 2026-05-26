---
name: implementation-router
description: 実装・修正・テスト・リファクタ作業の risk 判定と skill chain 選定に使用。feat/fix/test/refactor prompt の前段 router。
---

# Implementation Router

## Purpose

作業開始時に risk と作業種別を判定し、必要な skill chain だけを起動する。過剰な workflow と承認待ちを減らしつつ、high-risk では止まる。

## Step 1: classify task

| Type | Signal | Primary skill |
| --- | --- | --- |
| feature | 新機能、追加、create, feat | `tdd` + optional `interface-first-design` |
| bugfix | バグ、エラー、fix, failing test | `systematic-debugging` → `tdd` |
| test | テスト追加、テスト品質 | `tdd` or `test-coverage-guard` |
| refactor | 振る舞い変更なし、構造改善 | `refactoring` |
| review | 差分レビュー | `deep-review` or focused review skill |
| plan | 方針相談 | `consultation` |

## Step 2: risk gate

### low-risk

- 50行未満
- 1-2ファイル
- DB / public API / auth / secrets / dependency 変更なし
- 仕様明確

Action: 最小計画 → 作業 → 検証 → 報告。

### normal-risk

- 50-150行
- 複数 module
- テスト追加が必要
- 既存 contract 内

Action: 変更方針と検証方針を短く出して進める。

### high-risk

いずれかに該当:

- DB schema / migration
- public API / SDK / CLI contract
- auth / authorization / payment / secrets
- dependency add / remove / update
- 100行超または5ファイル超
- 既存データ破壊の可能性
- 仕様曖昧
- production / external service への書き込み

Action: 実装前に計画と承認。`premise-questioning` を検討。機能棚卸しがあるなら `feature-pruning`。

## Step 3: skill chain

| Situation | Chain |
| --- | --- |
| new component | `interface-first-design` → `tdd` |
| simple feature | `tdd` |
| high-risk feature | `premise-questioning` → optional `feature-pruning` → `interface-first-design` → `tdd` |
| reproducible bug | `systematic-debugging` → `tdd` |
| non-reproducible bug | reproduce first; do not modify |
| refactor with tests | `refactoring` → optional `test-coverage-guard` |
| test quality concern | `test-coverage-guard` |

## Output

作業前に必要十分な範囲で以下を出す。

```text
分類: feature|bugfix|test|refactor|review|plan
risk: low|normal|high
skill chain: ...
承認要否: yes|no
理由: ...
```
