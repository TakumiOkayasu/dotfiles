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

現在の変更で証明すべき振る舞いを短く列挙する。

- normal path
- failure path
- 変更に固有のboundary
- regression condition

網羅性を装うため、無関係なnull/empty/max等を機械的に追加しない。

### RED

最小のテストを追加し、期待した理由で失敗することを確認する。

既存bugを再現できない場合は、static trace、contract test、typecheck等の代替証拠を使い、RED未確認を明示する。

### GREEN

現在のテストを通す最小実装を行う。

- 将来用abstract layerを追加しない
- production codeをtestだけのために歪めない
- existing seamがあれば再利用する

### REFACTOR

テストが通る状態を維持して、重複、命名、責務だけを必要な範囲で整理する。

### VERIFY

対象テスト、関連テスト、lint、buildをproject commandで実行する。実行していないcheckを成功扱いしない。

## Test doubles

projectの既存方針に従う。real dependency seam、fake、stub、mockのいずれも目的とcostで選ぶ。module mockを一律に要求または禁止しない。

## 追加検証

`qa-nightmare`、property-based test、fuzzing、mutation test、独立reviewは次の場合だけ追加する。

- securityまたはdata integrity boundary
- state spaceが広い
- 過去に同種のregressionがある
- userが明示要求した
- 通常testでは重大failure modeを十分に表現できない

固定agent数、固定case数、承認roundを設けない。

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

- Test list
- RED evidence
- GREEN summary
- REFACTOR summary
- Verification: passed / failed / skipped
- Remaining untested risk