---
name: design-team
description: 高リスク設計に独立した構築視点と反証視点を追加する。明示要求、または見落としの代償が大きく単一視点では危険な設計で使用する。局所変更や通常設計では使わない。
disable-model-invocation: true
effort: high
---

# Design Team

高リスク設計に必要な独立視点を追加する。目的はagent数や案数を増やすことではなく、アンカリングで見落とす重大条件を検出することである。

## 使用条件

- architecture、security boundary、data migration、public contract等の高影響設計
- 複数の実質的な選択肢があり、trade-offが結論を左右する
- userが独立した反対視点を明示要求した

単一file、既存pattern内、rollback容易な変更では使わない。

## 役割

必要に応じて次を分ける。

- Builder: 現在の要件に対する最小の推奨設計を作る
- Challenger: 前提、failure path、過剰設計、見落とした代替を独立に検査する
- Specialist: security、performance、domain等、一般推論では不足する専門観点

固定人数、固定model、最低案数を設けない。

## 手順

1. 同じsource packageを各独立視点へ渡す
2. 独立性に意味がある場合だけ並列dispatchする
3. 親がsourceと照合して重複、誤認、trade-offを統合する
4. unresolvedな高重大度論点だけ再検証する
5. 結論が出たら追加roundを行わない

subagentが使えない場合でも、親が独立lensを適用できるなら継続する。

## 出力

```text
Recommended design:
Meaningful alternatives:
Critical assumptions:
Challenges and resolutions:
Accepted risks:
Evidence still required:
```

## 禁止事項

- 常に5案以上を要求する
- 常に2round以上を要求する
- subagent不能だけを理由に設計をBLOCKする
- 軽微な変更へ起動する
- 独立視点を装い、先行案をそのまま言い換える
