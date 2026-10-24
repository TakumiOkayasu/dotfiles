# 独立したテスト設計と審査

この段階式審査は explicit opt-in。通常の basic TDD を置き換えない。mode を選択済みなら失敗時の省略や basic TDD / 別 provider への自動降格は禁止する。Codex runtime 未対応を理由に一般の Codex TDD 自体を停止させない。

## 入力の準備

親は今回の要件、仕様、対象実装、実際の呼び出し元を source bundle に収める。
根拠を追跡できる source ID を付け、秘密値や無関係な履歴を渡さない。
既存テストは接続や規約の参考にはなるが、期待値の唯一の根拠にはしない。
親のテスト候補やレビュー結論を source bundle に混ぜない。
仕様が矛盾する場合は、その矛盾を明示して必要な判断を求める。

## 段階と閲覧範囲

| 段階 | 新規 worker に渡すもの | 成果物 |
| --- | --- | --- |
| derive | source bundle と担当観点 | 独立したテスト候補 |
| expectations | source bundle と担当観点だけ | 候補を見ない状態での期待事項 |
| review | source bundle、担当観点、自分の期待事項、全候補 | 漏れ/oracle/faulty-pass/correct-fail の指摘 |
| integrate | source bundle、全候補、全期待事項、全指摘 | 全項目の処遇と実装順序 |

3〜5 の異なる観点で設計と独立審査を行う。
標準 runner は contract (公開契約と呼び出し元)、state (状態遷移と境界)、dependencies (依存失敗と副作用) の 3 観点を使う。
同じ担当者の言い換えや persona の数を観点数に数えない。
`--views contract state-and-boundaries dependencies-and-failures` で 3〜5 の異なる観点名を指定できる。標準は 3 観点、逐次実行なので並列上限 3 を越えない。観点名だけで独立した意味が保証されるわけではない。

全 expectations が記録されるまで、reviewer に候補を開示しない。
review は各 reviewer 自身の記録と全候補を使い、他 reviewer の指摘や親の統合案を渡さない。
各段階を新しい subprocess に分け、前段の会話履歴を再利用しない。

## 審査する内容

- omission: 要件や呼び出し元が要求するが、候補にない振る舞いは何か。
- oracle: 期待値を実装や実行結果から写していないか。仕様と観測点が対応するか。
- faulty-pass: どの具体的な不正実装が、弱い assertion や過剰な mock によって通り得るか。
- correct-fail: どの仕様上正しい実装が、内部実装への過剰な結合や不正な前提で落ちるか。

各候補には前提/操作/期待結果/観測点/根拠/検出したい違反を残す。
統合時は全候補/期待事項/指摘に accepted/rejected/deferred を付け、reason と test_ids を残す。修正や重複統合は accepted の理由に明示し、対応先 ID を共有する。rejected は test_ids を空にする。deferred は記録を保存して ready を発行せず停止する。
重複は ID の対応を保存して統合し、指摘ゼロという結論にも確認範囲と根拠を添える。
点数、多数決、固定 case 数、persona では品質を保証しない。

## runner と停止条件

実行資産の正本は `bin/tdd-review-check`、配布先は `~/.local/bin/tdd-review-check`。
この references 配下には手順文書だけを置き、実行スクリプトを置かない。
bundle は以下の JSON。source path は bundle 自身のディレクトリを起点とする明示的な相対 regular file のリスト。requirements は合意した要求を含め、既存変更では仕様/呼び出し元/対象実装を不足なく選ぶ。source がない新規設計でも要求は必須。秘密値を含めないことは入力準備側の責務であり、path 検査だけでは内容の安全性や十分性を保証しない。合計 256 KiB を越える場合は対象を分割する。

```json
{"requirements":"追加する振る舞いと未決事項", "sources":["src/cart.py","src/checkout.py","docs/cart-contract.md"]}
```

source snapshot と run ID、schema version、snapshot/input digest を各出力へ結び付ける。新規 output directory だけを許可し、過去の成功結果を再使用しない。input/output/snapshot/error は追跡用に保存する。これらは対象 source を含むため repository に commit せず、適切な私的保存先を使う。

```sh
tdd-review-check run --bundle FILE --runtime claude --output DIR
tdd-review-check verify --bundle FILE --output DIR
```

`--runtime` は `claude` または `codex` を指定する。
Claude は fresh subprocess に `--tools "" --disallowedTools "mcp__*" --no-session-persistence` を指定する。runner は role file を起動せず、段階別契約の inline prompt と JSON schema を渡す。role の model/effort 設定を使ったと主張しない。
これは runner が渡す payload と model tool 設定の境界であり、ambient hooks/global context の注入や外部親 session の書込を封じるものではない。policy hooks は無効にしない。per-run `execution_boundary` へその制限を記録する。strict isolation が必要なら `--require-strict-isolation` で未対応として停止する。CLI flags の mock 検証は実 runtime の edit/read denial 検証ではない。
Codex の read-only sandbox は候補ファイルの読み取りを防げず、role TOML も親の権限を上書きしない。現 adapter は常に未対応として停止する。別 provider や弱い sandbox へ自動代替しない。
別の working directory やプロンプトの禁止文だけで読み取り隔離済みとみなさない。
CLI の存在だけで実行済みとはせず、実際の起動結果と未確認範囲を残す。

runner は project の実装やテストを書き換えない。
`ready.json` は段階順序、出力形式、参照と処遇の手続き的検証に使うもので、テスト設計の正しさや品質の認定ではない。
出力欠損、phase 不整合、strict isolation 要求、未解決の仕様判断があれば RED に進まない。
親は今回の入力に対応した `ready.json` と統合結果を読み、根拠と保留項目を確認してから test-writer へ 1 つの振る舞いを渡す。

## TDD への引き継ぎ

テスト候補を一括でコード化してから実装へ進むのではなく、選んだ 1 つの振る舞いを RED、最小実装を GREEN、必要な整理を REFACTOR として進める。
生成しただけでは RED ではないため、親が意図した契約違反による失敗を実行確認する。
要件や対象が変わった時は古い設計結果を使い回さず、変更を反映した入力で審査し直す。
通常の段階間で人間承認を増やさず、仕様判断や明示承認が必要な副作用がある時だけ確認する。

## 残る信頼境界

verify は source drift、欠けた段階、開示 payload、参照/処遇、ready と保存報告の整合を再検証する。書込可能な親が全報告を書き換えたり runner を呼ばず実装したりする行為は防げない。これは認証署名や OS 権限境界ではなく、協調的な workflow の fail-closed 手続きである。配置先の policy や人間承認を置き換えない。

全 AI が同じ誤りを犯すことはある。CLI 未実行、実 model の審査精度未評価、source 根拠不足を成功扱いしない。synthetic protocol test、既知の weak/good test fixture 実行、実 AI の指摘精度評価は別々に報告する。
