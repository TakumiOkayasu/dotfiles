---
name: orchestrate
description: 仕様が確定した複数taskを、依存関係と副作用境界を管理しながら実装・検証する。複数の独立変更をまとめて進める時に使用する。局所変更や設計未確定では使わない。
effort: high
---

# Orchestrate

複数taskの実装を親セッションが所有し、必要な箇所だけ委譲する。

## 前提

- 目的と主要仕様が確定している
- task間の依存関係を説明できる
- side effect approvalの境界が分かっている

設計判断が残る場合は先に`consult`または`arch`を使う。

## 計画

taskは「単独で検証可能な意味のある変更単位」に分ける。2-5分等の固定時間粒度に分解しない。

各taskへ次を記載する。

```text
Goal:
Files:
Dependencies:
Contract / invariant:
Verification:
Side effects:
```

placeholderや未定義のcontractを残さない。

## 実行

- 親が全体contract、branch、差分、verificationを所有する
- 独立して読み書きできるtaskは並列化してよい
- 同じfile、同じcontract、同じmigrationへ触れるtaskは直列化する
- subagentは専門性、context隔離、並列性に実益があるtaskだけへ使う
- 1 task = 1 fresh subagentを強制しない
- subagent不能時は、親が安全に実行可能なら継続する

旧workflowの次の固定表は契約にしない。

```text
| task 種別 / 役割 | 複雑度シグナル | Driver | Worker |
```

「subagent が TDD で実装・テスト・自己レビューする」ことも一律要件にせず、担当taskとruntimeに適した実行者を選ぶ。

## レビュー

- taskごとにcontractとverificationを確認する
- high-riskまたは広範囲の差分だけ`deep-review`等の追加reviewを使う
- 仕様適合と品質を必要に応じて分けるが、固定2段階にはしない
- 禁止・承認必須・破壊的・不可逆操作は`HUMAN_REVIEW_REQUIRED`

## 承認ゲート

次は実行前に明示承認を得る。

- commit / push / deploy / publish / external write
- dependency add/update/remove
- DB schema / public API contract
- destructive data operation / privileged command
- secret / auth / authorization policy

## 出力

- task ledgerと依存関係
- 実行順または並列化理由
- 変更差分
- verification結果
- human review/approval status
- remaining risk

## 禁止事項

- task数やsubagent数を成果とみなす
- parentが処理できるtaskを機械的に委譲する
- reviewを通すためだけの追加round
- task間で矛盾する型・名前・contractを放置する
- side effect gateをsubagentへ委譲する
