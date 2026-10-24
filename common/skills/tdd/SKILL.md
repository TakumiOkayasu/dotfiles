---
name: tdd
description: 振る舞いをテストで定義し、RED-GREEN-REFACTORで実装する。新しい振る舞い、bug regression、public contract変更で使用する。テスト不能な設定・文書変更には機械的に適用しない。
---

# Test-Driven Development

テストを儀式ではなく、期待する振る舞いと回帰証拠として使う。

## 適用判断

使用する:

- 新しい振る舞い
- bugの回帰防止
- public contract、state transition、boundary condition
- 既存テスト可能なcodeの変更

機械的に使用しない:

- 文書、comment、formatのみ
- 実行環境のない外部system
- generated artifactのみの変更
- 既存projectでテスト基盤がなく、導入自体が別taskになる場合

適用できない時は理由と代替検証を明示する。

## Cycle

### Test list

現在の変更で証明すべき振る舞いを短く列挙する。期待値は合意した要件・public contractから導き、根拠を短く添える。現在の実装や実行結果の写しを正解にしない。

`interface-first-design` の Given / When / Then / Failure を再利用し、前提・操作・期待結果・想定内の失敗を具体化する。要件が曖昧なら `[要確認: ...]` として確認し、期待値を推測で埋めない。

- normal path
- failure path
- 変更に固有のboundary
- regression condition

網羅性を装うため、無関係なnull/empty/max等を機械的に追加しない。

### Independent test design review (explicit opt-in)

ユーザーが独立した複数観点の設計審査を明示要求した時、または今回この mode を明示選択した時だけ、RED の前に [独立したテスト設計と審査](references/test-design-review.md) を行う。通常の TDD は上の Test list から RED へ進む従来の流れを維持し、この runner を必須にしない。選択済みの mode が実行できない場合は basic TDD へ黙って降格しない。
対象実装/呼び出し元/仕様/要件から 3〜5 観点で候補を独立に導き、別の reviewer が候補開示前に期待事項を記録する。
標準 runner は contract/state/dependencies の 3 観点で derive → expectations → review → integrate を実行する。
runtime は明示選択する。`tdd-review-check run --bundle FILE --runtime claude --output DIR` の後、`tdd-review-check verify --bundle FILE --output DIR` で snapshot/全段階/結果を再検証する。親は `ready.json` の実行境界と全候補/全指摘の処遇・根拠を読んでから RED へ進む。Codex runtime は現在未対応で停止し、Claude へ自動代替しない。
runner は project code を編集せず、`ready.json` は品質ではなく手続きを検証する。
未解決の仕様判断や CLI failure は停止する。厳密な隔離が必要な場合は `--require-strict-isolation` を指定すると未対応として停止する。ambient hooks/global context と書込可能な親は runner の制御外であり、hook を無効にして回避しない。

### RED

リストから1つの振る舞いを選び、最小のテストを追加して実行する。テスト名・実行コマンド・実際の失敗を短く残し、選んだ契約違反で失敗したことを確認する。テスト生成だけではRED確認にならない。

環境不備や無関係な例外は意図したREDに数えない。新規APIが存在しないことによるcompile/import失敗は初期段階の証拠として区別し、最小の宣言を用意した後、振る舞いの失敗を確認してからGREENへ進む。

既存bugを再現できない場合は、static trace、contract test、typecheck等の代替証拠を使い、RED未確認を明示する。

### GREEN

現在のテストを通す最小実装を行う。fake-itも許容し、次の振る舞いは次のREDから進める。

通すためだけの期待値の弱体化、assertion削除、skipは禁止する。テスト自体が誤っていた場合は、合意した要件・contractを根拠に訂正理由を示し、REDを再確認する。

- 将来用abstract layerを追加しない
- production codeをtestだけのために歪めない
- existing seamがあれば再利用する

### REFACTOR

テストが通る状態を維持して、重複、命名、責務だけを必要な範囲で整理する。

### VERIFY

対象テスト、関連テスト、lint、buildをproject commandで実行する。実行していないcheckを成功扱いしない。

修正前の再現REDは、その不具合への検出力の証拠として再利用する。検出力に疑いが残る場合、または重大なcontractを扱う場合に限り、`test-coverage-guard` の手順で対象を絞った契約破壊・mutationを検討する。全件mutationや追加reviewを一律に要求しない。

## Test doubles

projectの既存方針に従う。real dependency seam、fake、stub、mockのいずれも目的とcostで選ぶ。module mockを一律に要求または禁止しない。

## 追加検証

`qa-nightmare`、property-based test、fuzzing、mutation test は次の場合だけ追加する。
RED 前の独立したテスト設計審査とは分けて判断する。

- securityまたはdata integrity boundary
- state spaceが広い
- 過去に同種のregressionがある
- userが明示要求した
- 通常testでは重大failure modeを十分に表現できない

追加検証には固定 agent 数、固定 case 数、承認 round を設けない。

### qa-nightmare optional extension

この節は上記条件を満たし、かつClaude runtimeで安全なread-only dispatchが可能な場合だけ使用する。通常の機能単位で自動発火させない。

| スコープ | 例 | optional action |
| --- | --- | --- |
| 機能単位 (画面 / API / エンドポイント / ジョブ) | ユーザー登録画面、決済 API、夜間バッチ | qa-nightmare subagent を起動する |

明示的にこのoptional extensionを選んだ場合に限り、機能単位と判定したら、テストリスト作成に進む前に qa-nightmare subagent を起動して悪夢テストケースを先に列挙する。

### qa-nightmare 起動

Task tool で `subagent_type: qa-nightmare` を起動する。

source selectionの選択理由を記録し、依存観点としてentrypoint、主要依存、状態境界、認可、外部副作用、既存テストを確認する。source_evidence不足ならdispatchせず終了する。

親はcanonicalなrepo_provenanceを作り、sourceはrelative regular fileのみ許可する。directory/absolute/./../external symlink/sibling-prefix/gitignored/credential/secret-bearingを拒否し、component-aware配下判定を行い、秘密値をfactへ含めない。sourceは既知pathから導出し、期待file名/canonical target/digest/ID集合/構造をdispatch直前に検証する。absolute pathを出力しない。子agentへabsolute filesystem pathを渡さず、次のfieldを渡す。

```text
repo_provenance:
source_evidence:
checklist_snapshot:
checklist_provenance:
```

context_limit_tokens、output_reserve_tokens、input_upper_bound_tokensはUTF-8 byte数から保守的に見積もる。対象機能、URL / パス、4 fieldを再直列化して固定点へ収束させ、取得できなければ起動しない。

最初に`--source-only`でaccepted_sourcesと読取前後digestを検証する。この段階ではcore slot用のchecklist_snapshotを構築せず、続くfull preflightでsource-onlyとfullの `repo_provenance` が完全一致することを確認する。

### 結果の扱い

機能単位の場合は `qa-nightmare` subagent の出力を反映する。

採用するcaseは重大度と今回のscopeで選び、全caseの実装を義務化しない。

<!-- qa-continuation:start -->
長大出力で継続が必要な場合はcompact continuation_ledgerを使う。完全性索引とsnapshot digestを持ち、未返却rankについてのみ、各代表ケースを再構成できるredacted事実として事前条件/操作/期待結果/観測点/根拠/scoreを保持する。表示済みrank本文を含めない。UTF-8 byte数からledger上限を算出し、再直列化して固定点へ収束させ、ledger_upper_bound_tokens <= output_reserve_tokensを満たす。超過時は対象絞り込みを要求して停止する。continuation_ledger+requested_rankだけで再dispatchし、source全体を再送しない。
<!-- qa-continuation:end -->

## 承認

通常のRED-GREEN間でユーザー承認を要求しない。次の場合だけ停止する。

- requirementが複数解釈できる
- public API、DB schema、dependency、destructive operation等の明示承認が必要
- テストが仕様そのものを変更する

## 出力

- Test list (opt-in 時は独立審査の統合結果/全項目の処遇も含む)
- opt-in 時は今回の入力に対応する `ready.json` の確認結果
- RED evidence
- GREEN summary
- REFACTOR summary
- Verification: passed / failed / skipped
- Remaining untested risk
