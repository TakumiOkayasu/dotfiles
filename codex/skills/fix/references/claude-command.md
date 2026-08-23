# バグ修正ガイド

<!-- codex-port: managed; source=common/commands/fix.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/commands/fix.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

症状を証拠へ落とし、根本原因を最小差分で修正し、回帰を防ぐ。

## 入力

`ユーザー指定の対象`に症状、期待値、環境、既知の再現条件が渡される。

## 原則

- 再現、境界トレース、原因特定、回帰保護の順で進める
- 「なぜ」を固定回数繰り返さない。根本原因へ到達するために必要な分だけ掘る
- methodology skill、subagent、承認stepを一律に追加しない
- `systematic-debugging`は原因が不明、境界が複数、再現が不安定な時に使う
- `tdd`は回帰テストを作れる振る舞い変更で使う
- `premise-questioning`は修正方針が不可逆、高影響、または前提自体を疑う必要がある時だけ使う
- 親が十分に調査できる場合はsubagentへ委譲しない

## 手順

### 1. 症状を確定する

- expected / actual / environment / reproductionを記録する
- 実行可能なら再現する
- 再現できない場合は修正を禁止するのではなく、`static trace only`として証拠の強さと未確認事項を明示する

### 2. 根本原因を特定する

- 入力から失敗地点まで境界を追跡する
- 変更履歴、呼び出し元、呼び出し先、設定、テストを一次ソースとして読む
- 仮説は「原因候補」「予測される観測」「反証方法」の組で検証する
- 複数の独立仮説を並行調査する価値がある場合だけsubagentを使う

### 3. 回帰を証明する

可能なら、修正前に失敗し修正後に通る最小テストを追加する。

テストが作れない場合は、再現コマンド、静的契約、型検査、ログ等で代替し、代替の限界を明示する。

### 4. 最小修正を行う

- 症状を隠すのではなく確定した原因を修正する
- 無関係な整理、将来用抽象化、広範囲な置換を混ぜない
- 既存契約の新実装で対応できる場合は契約を変更しない

### 5. 検証とレビュー

- 回帰テストと関連テストを実行する
- 同じfailure modeが別経路に残っていないか確認する
- 禁止操作、承認必須操作、破壊的・不可逆操作に触れる差分は`HUMAN_REVIEW_REQUIRED`とし、人間承認なしでmerge可と判定しない

## 出力

- Reproduction: reproduced / static trace only / unavailable
- Root cause and evidence
- Fix summary
- Regression protection
- Tests/checks: passed / failed / skipped
- Human review gate: required / not required
- Remaining risk
