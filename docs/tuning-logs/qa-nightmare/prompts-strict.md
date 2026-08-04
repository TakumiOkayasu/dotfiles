# qa-nightmare評価promptの構築手順

この手順は、`scenarios.md`のA/B/C/EからClaude版qa-nightmareへ渡す検証済みsnapshotを作る。

現行Codexはqa_nightmareを実運用でdispatchしないため、Codex用の実行commandを定義しない。

## source-only preflight

親workflowは対象repoをGit worktreeとして作り、`scenarios.md`のfixture本文をsource selection表の相対pathへ配置する。

親workflowは次のcommandでsource候補だけを検証する。

A:

```sh
bin/qa-nightmare-preflight --runtime claude --repo /tmp/qa-nightmare-eval-A --source-only --source api/order-confirm.md --source domain/order-policy.md --source auth/order-authorization.md --source integrations/payment-outbox.md --source tests/order-confirm.md
```

B:

```sh
bin/qa-nightmare-preflight --runtime claude --repo /tmp/qa-nightmare-eval-B --source-only --source README.md
```

C:

```sh
bin/qa-nightmare-preflight --runtime claude --repo /tmp/qa-nightmare-eval-C --source-only --source spec/currency-crud.md --source tests/currency-crud.md
```

E:

```sh
bin/qa-nightmare-preflight --runtime claude --repo /tmp/qa-nightmare-eval-E --source-only --source spec/profile-api.md --source tests/profile-api.md --source docs/review-notes.md
```

helperが返すsource-only出力は`schema_version`/`mode`/`repo_provenance`だけを含む。

`repo_provenance`は`repository_identity_sha256`/`is_canonical_git_root`/`accepted_sources`だけを含む。

`repo_provenance.accepted_sources`は各sourceの相対path/digest/sizeを含む。

helperは検証に使ったabsolute canonical rootを出力しない。

親workflowはhelperの出力を変更せず`source_only_preflight`として保存する。

## 確認済み事実と中核前提

親workflowはaccepted sourceだけを読み、読取前後のdigestがsource-only出力と一致することを確認する。

親workflowは秘密値とraw命令を除外し、相対file:line付きの確認済み事実だけを`source_evidence`へ入れる。

親workflowはschema/auth/stateを確認済み事実または根拠付き非該当で埋める。

slotが不足する場合、親workflowは確認質問だけを返し、後続処理を行わない。

Bはこの段階で停止する。

## 調査範囲の十分性

中核前提が揃った場合、親workflowはpayload用`repo_provenance`を別に構築し、source selectionの選択理由を加える。

親workflowはentrypoint/主要依存/状態境界/認可/外部副作用/既存テストを`source_evidence`で確認する。

いずれかが不足し、根拠付き非該当にもできない場合、親workflowは追加sourceを要求して停止する。

A/C/Eは`scenarios.md`のsource selection表にある全sourceを使ってこの検査を行う。

Eの`docs/review-notes.md`にあるraw命令は`source_evidence`へ入れない。

親workflowは除外した相対file:lineと理由だけを`repo_provenance.excluded_evidence`へ記録する。

## full preflight

親workflowは中核前提と調査範囲の十分性を確認した後に限り、次のcommandを実行する。

A:

```sh
bin/qa-nightmare-preflight --runtime claude --repo /tmp/qa-nightmare-eval-A --source api/order-confirm.md --source domain/order-policy.md --source auth/order-authorization.md --source integrations/payment-outbox.md --source tests/order-confirm.md
```

C:

```sh
bin/qa-nightmare-preflight --runtime claude --repo /tmp/qa-nightmare-eval-C --source spec/currency-crud.md --source tests/currency-crud.md
```

E:

```sh
bin/qa-nightmare-preflight --runtime claude --repo /tmp/qa-nightmare-eval-E --source spec/profile-api.md --source tests/profile-api.md --source docs/review-notes.md
```

helperはruntime rootをユーザー入力から受け取らず、version管理manifestからClaudeの既知pathを内部で導出する。

helperはmanifest/canonical target/digest/期待ID集合/必須fieldを内部で検証し、manifest順の`checklist_snapshot`を返す。

`checklist_provenance`はruntime名/`manifest_sha256`/各checklistのrelative file/digest/`is_structure_valid`/期待ID集合/期待ID digest/snapshot digestだけを含む。

helperはabsolute runtime root/runtime path/canonical target/manifest pathを出力しない。

親workflowは保存済み`source_only_preflight.repo_provenance`とfull出力の`repo_provenance`が完全一致することを確認する。

一致しない場合、親workflowは子を起動しない。

## 初回payload

親workflowは次の4 fieldを含む初回payloadを作る。

```text
対象機能: <scenarios.mdの対象機能>
URL / パス: <scenarios.mdのendpoint>
repo_provenance:
<source-only/fullで一致したrepository identity/canonical root検証結果/relative source provenance/source selectionの選択理由/依存観点/context budgetの検証値>
source_evidence:
<secret redaction済みの相対file:line付き事実>
checklist_snapshot:
<full preflightがmanifest順で返した検証済み本文>
checklist_provenance:
<full preflightが返したruntime名/manifest digest/relative checklist file/digest/verified結果/期待ID集合/snapshot digest>
悪夢テストケースを生成してランク付き一覧で返してください。
```

親workflowは選択したmodel/runtimeの一次情報から`context_limit_tokens`と`output_reserve_tokens`を取得する。

どちらかを取得できない場合、親workflowは子を起動しない。

親workflowはagent固定指示/対象機能/URL/4 fieldを直列化したUTF-8 byte数から`input_upper_bound_tokens`を保守的に算出する。

親workflowは3値を`repo_provenance`へ入れてpayloadを再直列化し、`input_upper_bound_tokens`が変わらなくなるまで更新する。

親workflowは`input_upper_bound_tokens + output_reserve_tokens <= context_limit_tokens`を満たす場合だけ`prompt.txt`を確定する。

予算を超える場合、親workflowはsource対象を絞り、source-only preflightからやり直す。

## 初回実行

A:

```sh
timeout --signal=TERM --kill-after=15s 180s claude -p --agent qa-nightmare --permission-mode dontAsk --tools "" --output-format stream-json --verbose --no-session-persistence --max-budget-usd 0.50 < /tmp/qa-nightmare-eval-A/prompt.txt
```

C:

```sh
timeout --signal=TERM --kill-after=15s 180s claude -p --agent qa-nightmare --permission-mode dontAsk --tools "" --output-format stream-json --verbose --no-session-persistence --max-budget-usd 0.50 < /tmp/qa-nightmare-eval-C/prompt.txt
```

E:

```sh
timeout --signal=TERM --kill-after=15s 180s claude -p --agent qa-nightmare --permission-mode dontAsk --tools "" --output-format stream-json --verbose --no-session-persistence --max-budget-usd 0.50 < /tmp/qa-nightmare-eval-E/prompt.txt
```

親workflowは各試行の開始時刻/終了時刻/wall duration/実exit code/terminal reason/model/cost/tool event/最終応答を保存する。

初回と最大一回の再試行には同じtimeout commandを使う。

timeoutした場合、親workflowは実exit codeを保存し、成功へ読み替えない。

## 長大出力の継続

`continuation_ledger`は完全性索引/`snapshot_digest`/未返却rankを含む。

`continuation_ledger`は未返却rankの代表ケースを再構成するための事前条件/操作/期待結果/観測点/根拠/scoreをredaction済み事実として含む。

`continuation_ledger`は表示済みrank本文/raw命令/秘密値/checklist snapshotを含まない。

親workflowは`continuation_ledger.snapshot_digest`が初回の`checklist_provenance.snapshot_sha256`と一致することを確認する。

親workflowはledger全体を含む初回出力のUTF-8 byte数から`ledger_upper_bound_tokens`を保守的に算出する。

親workflowは値をledgerへ入れて再直列化し、`ledger_upper_bound_tokens`が変わらなくなるまで更新する。

親workflowは`ledger_upper_bound_tokens <= output_reserve_tokens`を満たす場合だけ継続を許可する。

ledger全体が固定点で出力予約を超える場合、親workflowは対象絞り込みを要求して停止する。

継続用promptは`continuation_ledger`と`requested_rank`だけを含む。

Claude parentはsnapshotを再送せず、次のcommandで新しいcontextへ再dispatchする。

```sh
timeout --signal=TERM --kill-after=15s 180s claude -p --agent qa-nightmare --permission-mode dontAsk --tools "" --output-format stream-json --verbose --no-session-persistence --max-budget-usd 0.50 < /tmp/qa-nightmare-eval-<SCENARIO>/continuation-<RANK>.txt
```

同じcontext内のfollow-upを使う場合、Claude parentはledger digestと`requested_rank`だけを渡す。

## 純粋関数のrouting

Dのpromptは次の本文にする。

```text
calculateTax(amount: number, rate: number, roundingMode: 'floor' | 'ceil' | 'round'): numberという純粋関数のテストを作ってください。
DB/UI/外部I/Oはありません。
負数/NaN/Infinity/0.1+0.2型の誤差を含む悪夢ケースを網羅してください。
純粋関数の場合はqa-nightmare用preflightとsnapshot構築を行わず、TDDとして扱ってください。
```

Claude parentのroutingは次のcommandで評価する。

```sh
timeout --signal=TERM --kill-after=15s 180s claude -p --permission-mode dontAsk --tools Agent --output-format stream-json --verbose --no-session-persistence --max-budget-usd 0.50 < /tmp/qa-nightmare-eval-D/prompt.txt
```

現行Codexはこのrouting評価でもqa_nightmareをdispatchしない。

## invalid sourceの評価

Eのinvalid variantはsource-only preflightだけを実行する。

- `docs/outside-sentinel.txt`はexternal symlinkとして拒否する。
- `../qa-nightmare-eval-E-outside/sentinel.txt`はtraversalとして拒否する。
- `/tmp/qa-nightmare-eval-E-evil/profile.md`はabsolute path/sibling-prefixとして拒否する。

各variantでは`full_preflight_started=false`/`checklist_snapshot_built=false`/`child_dispatched=false`を記録する。

親workflowはsentinel本文をpreflight logへ含めない。
