---
name: systematic-debugging
description: 既知障害のroot causeを証拠ベースで深掘りする必要がある場合に使用する。通常の明白なbug fixではmodel自身の通常debuggingを優先し、workflowやuserが明示した場合に使う。
disable-model-invocation: true
effort: high
---

# Systematic Debugging

原因を決め打ちせず、実コード・ログ・再現結果からroot causeを特定してから最小修正へ進む。

## 使用条件

- 原因が不明、または複数仮説が競合している
- 一度以上の修正が外れ、前提を再検証する必要がある
- 複数layer、状態遷移、並行性、外部I/Oなどを跨ぐ障害
- userや`fix` workflowがroot-cause analysisを明示した

syntax typo等、原因と修正が一次情報から明白な局所bugでは使わない。

## 原則

- エラー原文、実コード、contract、test結果を一次情報とする
- 再現できるなら最小再現を作る。ただし静的に因果関係を証明できる場合や実行環境がない場合、再現不能だけを理由に停止しない
- 仮説は検証可能な形で置き、反証できたものを捨てる
- subagentは独立調査や専門性に実益がある場合だけ使う。人数やround数を固定しない
- root causeと修正方針を分ける。原因が確定する前に大きな修正へ進まない

## 進め方

1. expected / actual / evidence / environmentを整理する
2. failureが最初に現れる境界を追跡する
3. 必要な仮説だけ立て、test・ログ・code traceで反証する
4. root causeを、症状ではなく壊れたcontractまたはstate transitionとして説明する
5. 可能なら回帰testを先に失敗させ、最小修正を行う
6. 関連checkを実行し、同種問題の横展開は必要な場合だけ別taskにする

## 出力

```text
Reproduction: reproduced | static-proof | unavailable
Root cause:
Evidence:
Fix:
Regression protection:
Verification:
Remaining risk:
```

## 禁止事項

- 根拠のない原因断定
- 再現手順を作ること自体を目的化する
- 固定回数の`why`、固定人数のsubagent、固定phaseを成功条件にする
- test環境がないことだけを理由に、有効な静的証拠を無視する
- 症状だけを隠す変更をroot-cause fixと呼ぶ
