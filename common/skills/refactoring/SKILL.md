---
name: refactoring
description: 振る舞いを変えない構造改善を、明示的なrefactoring workflowとして行う場合に使用する。通常の小規模整理はmodel自身で処理し、skillの固定手順を前提にしない。
disable-model-invocation: true
---

# Refactoring

外部から観測できる振る舞いを維持したまま、現在の変更目的に必要な構造だけを改善する。

## 使用条件

- userがrefactoring workflowを明示的に求めた
- 広い構造変更で、守るinvariantとverificationを明文化する価値がある

rename、局所抽出、明白な重複除去などは通常の実装判断として処理してよい。

## 原則

- 変更前に守るbehavior、public contract、data semanticsを特定する
- 既存testがあればbaselineとして使う。testがないことだけを理由にrefactoringを禁止せず、必要ならcharacterization testや静的contract確認で補う
- 現在の目的と無関係なcleanupを混ぜない
- 変更単位は検証可能な大きさにする。固定行数、固定commit数、固定phaseを設けない
- 新しい抽象化は現在の重複・責務・変更理由から必要性を説明できる場合だけ追加する
- behavior変更が必要になった場合はrefactoringから切り離して扱う

## 進め方

1. scopeと維持するinvariantを確認する
2. 現在の構造で問題になっている具体的なcoupling、duplication、責務混在を特定する
3. 最小の構造変更を行う
4. relevant test / typecheck / lint / buildでbehavior維持を確認する
5. 追加変更が同じ目的に必要か再評価し、不要なら止める

## 出力

```text
Scope:
Preserved invariants:
Structural changes:
Verification:
Behavior change: none | separated
Remaining risk:
```

## 禁止事項

- 将来利用だけを理由に抽象化を増やす
- refactoringの名目で仕様やpublic contractを変える
- testの有無だけで機械的に可否を決める
- 変更数やcommit数を成果指標にする
- unrelated cleanupを同じ差分へ混ぜる
