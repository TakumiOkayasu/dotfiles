---
name: measure
description: profiler/APM/負荷試験を使った計測作業そのものを明示的に進める場合に使用する。性能改善の通常相談は`optimize`へ任せ、計測実務を独立workflowとして必要な時だけ使う。
disable-model-invocation: true
---

# Performance Measurement

性能改善の判断は`optimize`を正本とする。本skillは、profiler/APM/benchmark/load testを実行して再現可能なbaselineとbefore/afterを取る作業に限定する。

## 使用条件

- userがprofiling、benchmark、load test、APM分析を明示的に求めた
- `optimize`で計測対象が確定し、実測作業を独立させる価値がある

何を最適化すべきか未確定なら、先に`optimize`で対象と指標を決める。

## 原則

- 同一条件のbefore/afterを比較する
- 平均だけでなく、対象に応じてdistribution、tail、throughput、memory、CPU、I/O等を見る
- profilerやproject標準toolを優先し、手計装は自動計測で見えない区間に限定する
- 1回の偶然値を結論にしない
- 計測toolや設定自体のoverheadを考慮する
- 効果がない変更を残さない

## 進め方

1. 対象scenarioと改善したいmetricを固定する
2. projectの既存benchmark/profiler/APM設定を確認する
3. baselineを再現可能な条件で取得する
4. hotspotまたは支配要因を特定する
5. 変更後に同じ条件で再計測する
6. 差分、ばらつき、未確認要因を報告する

## 出力

```text
Scenario:
Metric:
Environment:
Baseline:
Hotspot:
After:
Delta:
Confidence / variance:
Remaining uncertainty:
```

## 禁止事項

- baselineなしの改善率報告
- 1回計測だけで結論を出す
- projectで使われているtoolを確認せず別toolを追加する
- profilerが十分な場面で不要な計装codeを追加する
- 計測結果がないのに改善したと報告する
