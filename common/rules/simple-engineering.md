# Simple Engineering

コードの計画,実装,修正,リファクタリング,レビューで常に適用する.
通常のmethodologyを追加するruleではなく,変更時に破ってはいけないhard invariantを定義する.

<!-- simple-engineering-invariants:start -->
## Mandatory invariants

- 識別可能なroot causeがあるfailureは原因を修正する. fallback,retry,catch-all,alternate pathで症状だけを消さない. これらは要件または既存contractが回復動作として要求する場合だけ追加する.
- fallbackによってerrorまたはtest failureが見えなくなっただけではbug fixとみなさない.
- backward compatibilityは既存consumer,released public contract,persisted data,explicit compatibility requirementのいずれかがあり,同一変更でconsumerまたはdataを移行できない具体的理由がある場合だけ追加する. 未リリースでconsumerがないbehaviorへcompatibility layerやshimを足さない.
- 現在の要件に不要なabstraction,configuration,branch,error handling,dependencyを将来予測だけで追加しない.
- 新しい実装やdependencyを追加する前に,project内の既存実装,標準library,既存dependencyで満たせないか確認する. dependency選定の詳細は`implementation-policy.md`に従う.
- 行数の最小化ではなく,要件を満たす最小のmaintainable changeを選ぶ. 現在必要なcontractや責務分離をKISS/YAGNIを理由に崩さない.
- branch,error handling,validationを削る場合は,到達不能または冗長であることをtype,contract,actual call pathから確認する. 外部入力,I/O,deserialize等のboundaryに必要なdefensive checkを推測で削らない.
- 完了前にfinal diffを行単位で確認し,要求された結果に不要な変更を除く.
<!-- simple-engineering-invariants:end -->

## Boundary

- 固定round,固定人数のsubagent,全選択肢列挙等のceremonyを要求しない.
- root causeが不明な複雑障害は`systematic-debugging`を必要に応じて使う. 通常の明白なbug fixへ強制しない.
- 機能要否の棚卸しは`feature-pruning`,高影響なgo/no-go判断は`premise-questioning`の責務とする.
