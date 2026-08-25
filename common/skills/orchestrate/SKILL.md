---
name: orchestrate
description: 複数taskの依存関係とside effect境界を明示した実行ledgerを、ユーザーまたは上位workflowが明示的に必要とした場合だけ使用する。通常のtask分解や並列判断はmodel自身に任せる。
disable-model-invocation: true
effort: high
---

# Orchestrate

通常のtask分解、順序付け、並列化、subagent利用はmodel/runtimeの通常能力として扱う。本skillは、複数taskの実行ledgerを独立成果物として残す必要がある場合だけ使う。

## 使用条件

- userがorchestrationまたは実行ledgerを明示した
- 複数の独立変更を、共通contractとside effect gateの下で追跡する必要がある
- 上位workflowが複数workerの結果統合を明示的に要求した

局所変更、通常の実装、単純な並列化では使わない。

## Ledger

必要なtaskだけ、次を記録する。

```text
Goal:
Files:
Dependencies:
Contract / invariant:
Verification:
Side effects:
```

親セッションが全体contractと最終verificationを所有する。subagentは専門性、context隔離、並列性に実益がある場合だけ使い、人数やround数を固定しない。

互換性上、旧workflowが参照していた表記は次のとおりだが、固定表や実行規則としては扱わない。

| task 種別 / 役割 | 複雑度シグナル | Driver | Worker |
| --- | --- | --- | --- |

「subagent が TDD で実装・テスト・自己レビューする」ことも一律要件ではない。taskの性質とruntimeに合う実行者・検証方法を選ぶ。

## Side effect gate

commit / push / deploy / publish / dependency変更 / destructive operation 等は、それぞれの既存approval policyに従う。本skillが承認権限を追加しない。

## 禁止事項

- skillを使うためにtaskを分割する
- task数やsubagent数を成果とみなす
- modelが通常処理できる分解や順序付けを形式化する
- 固定phase、固定worker、固定review roundを成功条件にする
