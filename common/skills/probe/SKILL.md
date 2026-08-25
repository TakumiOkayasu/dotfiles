---
name: probe
description: profiler/APMでは見えない区間へ一時的な手計装を入れて性能原因を切り分ける必要がある場合に使用する。通常の性能調査では使用しない。
disable-model-invocation: true
effort: high
---

# Instrumentation Probe

自動profilingで必要な粒度が得られない場合だけ、一時的な計装を追加してruntime evidenceを取る。

## 使用条件

- profiler/APMが使えない、または対象区間を分解できない
- 呼び出し回数、区間時間、特定stateなどを追加観測しないと仮説を判定できない
- userまたは計測workflowが手計装を明示した

自動profilingで十分なら`measure`を使い、本skillは使わない。

## 原則

- 先に判定したい仮説と必要な観測値を決める
- 計装点は仮説を区別できる最小範囲にする
- hot loop等では観測overheadを測り、ログ自体が症状を作らないようにする
- project既存logger/telemetryを再利用し、調査だけの新しい基盤を作らない
- 複数箇所の並列調査は、独立性と速度に実益がある場合だけ行う。subagent数は固定しない
- temporary instrumentationは検証後に撤去する。ただし恒久的なobservability要件が別途確認された場合は別taskとして扱う

## 進め方

1. baselineと未解決の仮説を確認する
2. 各仮説を判定する最小の計装点を選ぶ
3. 相関可能な識別子と必要最小限の値だけ記録する
4. 実行して実測値を取得する
5. 仮説を採用または棄却し、必要なら次の計装点へ移る
6. 原因特定後に計装を撤去し、同一条件で再確認する

## 出力

```text
Question:
Instrumentation:
Observed data:
Conclusion:
Observer effect:
Cleanup:
Remaining uncertainty:
```

## 禁止事項

- 仮説なしに広範囲へログを埋める
- 固定数の仮説、固定人数のsubagent、固定phaseを要求する
- 1回の測定値だけで性能原因を断定する
- 調査用ログを理由なくproduction codeへ残す
- profilerで十分な場面に手計装を追加する
