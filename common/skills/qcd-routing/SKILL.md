---
name: qcd-routing
description: subagentや別workerへtaskを渡す際に、品質を落とさずmodel/effort/実行経路を最小コストへ寄せるために使用する。promptをtaskへ分解した後、task complexityとriskを分類し、`.ai/` の実測QCD結果からrouteを選ぶ。model/effortの固定値を勘で上げ下げしない。
---

# QCD Routing

品質をgateにし、その品質を満たすrouteの中からcost/usage/latencyが小さいmodel × effortを選ぶ。

`高いmodel = 常に良い`、`低effort = 常に安い`とは仮定しない。modelとeffortは組として実測する。

route候補とbaselineは `common/qcd/routes.json` を正本とする。model名やeffortの組を本skillへ重複定義しない。

## 対象

親agentがpromptから独立したtaskを切り出し、次のいずれかを行う直前に使う。

- subagentへdelegateする
- 別worker/sessionへtaskを渡す
- roleの既定model/effortより高いrouteへ上げる
- 安価なrouteへ下げる

main thread内で数十秒で終わる単純処理に、routingだけのための追加agentを起動しない。

## Task class

各prompt全体ではなく、**delegateするtask単位**で分類する。

| class | 基準 |
| --- | --- |
| `lookup` | 読取、検索、要約、所在確認。writeなし。判断失敗の影響が小さい |
| `bounded` | 対象file/contractが明確な局所実装、test追加、定型変換。reversible |
| `reasoning` | root cause、設計比較、未知の相互作用、広い影響範囲、複数仮説の反証が必要 |
| `critical` | security/auth、不可逆操作、production、schema migration、release-blocking判断など、見落としcostが高い |

迷った場合は1段上へ分類する。単に変更行数が多いだけで上げない。

## Route選択

1. task classを決める。
2. `ai-qcd route --runtime <codex|claude> --task-class <class> --json` を使える場合は実行する。
3. `source = observed-paired` なら、paired experimentのquality gateを満たした実測winnerとして優先する。
4. `source = baseline` なら `common/qcd/routes.json` の先頭routeを安全側の初期値として扱い、実測winnerとは呼ばない。
5. semantic roleに合う既存subagentが同じrouteを持つなら、そのagentを優先する。
6. runtimeがper-invocation overrideを**現在のtool contractで公開しており、effective model/effortを確認できる場合だけ**model/effort overrideを使う。
7. overrideが公開されない、または実効値を検証できない場合は既存role/defaultを使う。prompt本文にmodel名を書くだけで切替わったとみなさない。

## Runtime別適用

### Codex

Multi-agentのtool contractを実行時の一次ソースにする。

- `spawn_agent` に `model` / `reasoning_effort` が公開されている場合だけoverride候補にする。
- custom agent TOMLの指定がchildへ適用されたことを仮定しない。可能ならsession/rolloutのeffective contextで確認する。
- override不能なら、現在のrole profileまたは親agentへfallbackする。
- requested model/effortとeffective model/effortを区別する。

### Claude Code

- taskとsubagent `description` の対応でdelegate先を選ぶ。
- per-invocation `model` が利用できる場合はrouteのmodelを渡せる。
- effortはsubagent/skill/session設定の実効値を使い、変更できていないeffortを変更済みと報告しない。
- adaptive reasoningは指定effort内の思考配分をmodelへ任せる機能であり、task classそのものを置き換えない。

## Escalation

同じrouteで無制限にretryしない。

次の場合だけ`ai-qcd route`の`escalation`を次へ進める。

- critical requirementを満たさない
- 根拠不足で採否を決められない
- tool/runtime capability不足ではなく、推論能力不足の兆候がある

syntax error、network error、権限不足、test environment不備はmodel escalationで解決しない。

## Observation

通常業務のrunも `.ai/state/qcd-observations.jsonl` へtelemetryとして残せる。ただしtask難易度が揃っていないため、**通常runだけではrouteを自動昇格しない**。

requested/effectiveの両方を区別して記録する。effective値を確認できないrunはprovisional observationであり、paired experimentにも使わない。

## Paired experiment

routeを自動昇格する場合は、同じtask classで同一scenario集合を複数routeに実行する。

各runに共通の`cohort-id`とscenarioごとの`scenario-id`を付ける。

```bash
ai-qcd record \
  --runtime <runtime> \
  --task-class <class> \
  --requested-model <requested-model> \
  --requested-effort <requested-effort> \
  --effective-model <verified-model> \
  --effective-effort <verified-effort> \
  --quality pass \
  --cohort-id <experiment-id> \
  --scenario-id <scenario-id> \
  --duration-ms <duration> \
  --input-tokens <input> \
  --cached-input-tokens <cached> \
  --output-tokens <output>
```

比較対象routeは**同じscenario multiset**を持たなければならない。片方だけ簡単なscenarioを多く実行したcohortは無効とする。

## Promotion gate

`ai-qcd route` は既定で次を全て満たすpaired cohortだけをobserved winnerにする。

- effective model/effort確認済み
- routeが `common/qcd/routes.json` の現行candidateに含まれる
- 2 route以上を比較
- 全比較routeで同じscenario集合
- 各route 5 samples以上
- 各routeのquality pass rate 100%

通常業務telemetryはこのgateを満たさない。`--cohort-id`で特定実験だけを評価でき、省略時は最新の有効paired cohortを使う。

winnerは全比較routeで同じmetricが観測できる場合だけ、次の優先順位で比較する。

1. quota delta中央値
2. `uncached input + output` のusage proxy中央値
3. duration中央値

cached input、cache write、reasoning outputは別の診断値として保持する。runtimeが出す内訳の包含関係を確認せず加算して「cost」とみなさない。

品質未達routeは、安くてもwinnerにしない。
