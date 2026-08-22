# 機能実装ガイド

<!-- codex-port: managed; source=common/commands/feat.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/commands/feat.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

現在のユースケースを満たす最小差分を、既存設計に合わせて実装する。

## 入力

`ユーザー指定の対象`に機能の目的、期待する振る舞い、制約が渡される。

## 原則

- 現在必要なユースケースから始め、将来予測だけの機能・抽象化・拡張機構を追加しない
- 既存プロジェクトでは既存architecture、framework、規約、テスト構成を優先する
- methodology skillを一律に連鎖起動しない。現在の判断に必要なskillだけを使う
- 新しい責務境界や契約が必要な場合だけ`interface-first-design`を使う
- 方針自体に高い不可逆性・外部影響・未解決の前提がある場合だけ`premise-questioning`を使う
- 機能一覧の削減が目的または主要論点である場合だけ`feature-pruning`を使う
- subagentは独立調査、専門性、並列性に実益がある場合だけ使う。親単独で成立するなら委譲しない
- テスト設計や実装の各段階で、通常は逐次承認を要求しない。仕様判断または副作用承認が必要な時だけ停止する

## 手順

### 1. スコープとリスクを確定する

- 期待結果と非目標を1-3文で定義する
- 変更対象と既存の正本、生成物、公開契約を確認する
- DB schema、公開API、auth、secret、dependency、destructive operation、external writeを含む場合はhigh-riskとする
- 不明点が実装判断を左右する場合だけユーザーへ確認する

### 2. 既存実装を読む

- entry point、類似実装、テスト、設定、生成pipelineを一次ソースから追跡する
- 既存の差し替え境界で対応できるなら、新しいinterfaceやFactoryを増やさない
- 利用側が区別しない実装差を新しい型階層へ持ち込まない

### 3. 必要な設計だけ行う

新しい契約が必要な場合は、現在のユースケースだけでcontract-only walkthroughを行う。

```text
Current use case
  -> 最小の役割
  -> 最小の協調
  -> 必要な契約
  -> 実装と生成境界
```

完成形のclass図、将来用Registry、汎用Factoryを先に作らない。

### 4. テストと実装

振る舞い変更では、プロジェクトで実行可能な範囲で次を行う。

1. 変更前に失敗するテストまたは再現手順を用意する
2. 期待どおり失敗することを確認する
3. 最小実装で通す
4. 振る舞いを保持したまま必要な整理だけ行う

テスト不能な場合は、静的根拠と未検証範囲を明示する。`qa_nightmare`等の追加検証は、境界条件が多い、高リスク、またはユーザーが明示した場合だけ使う。

### 5. 検証とレビュー

- 対象テスト、関連テスト、lint、buildをリポジトリの一次情報に従って実行する
- 実行していない検証を成功扱いしない
- 差分が禁止操作、明示承認必須操作、破壊的・不可逆操作を追加・変更・到達可能化する場合は`HUMAN_REVIEW_REQUIRED`とし、人間承認なしでmerge可と判定しない

## 出力

- Risk: low / normal / high
- 変更内容と変更ファイル
- 設計判断と、追加しなかったもの
- Tests/checks: passed / failed / skipped
- Human review gate: required / not required
- 未確認リスク
