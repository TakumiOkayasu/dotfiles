---
# codex_port_source: common/skills/feature-pruning/SKILL.md
name: feature-pruning
description: 機能、UI要素、API、data項目の要否を、実データ・主要動線・既存代替から削減レビューする。機能一覧の棚卸しや「これは本当に要るか」を明示された時に使用する。
disable-model-invocation: true
effort: high
---

# Feature Pruning

<!-- codex-port: managed; source=common/skills/feature-pruning/SKILL.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/skills/feature-pruning/SKILL.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

現在のリリースに必要な機能だけを残す。目的は機能数を減らすことではなく、利用価値のない実装・運用・認知コストを除くことである。

## 入力

- 対象機能の一覧
- 主要ユーザーと主要動線
- 想定または実測のデータ量・利用頻度
- platform、accessibility、compatibility等の制約
- 既存代替手段

情報がない場合は不足を明示し、架空の使用率を作らない。

## 手順

### 1. 1機能ずつ目的を確認する

各項目について次を確認する。

```text
誰が、いつ、何を達成するために使うか
現在のreleaseで必要か
無い場合に成立しない具体的scenarioがあるか
```

### 2. 必要なlensだけ当てる

- YAGNI: 将来の可能性だけで追加されていないか
- Convention: 慣習だけで存在していないか
- Existing substitute: browser、OS、framework、既存toolで代替できないか
- Operational cost: support、migration、monitoring、security負担に見合うか
- Accessibility: 削除・代替で利用可能性を損なわないか

全lensを固定回数で実行しない。独立したdomain知識が必要な時だけsubagentを使う。

### 3. 判定する

- `KEEP`: 現在必要
- `REDUCE`: scopeまたは表現を縮小
- `DEFER`: evidenceが得られるまで実装しない
- `REPLACE`: 既存手段へ置換
- `REMOVE`: 現在の目的に不要
- `UNKNOWN`: 証拠不足

### 4. 変更後の主要動線を確認する

削減後も主要ユースケース、accessibility、rollback、運用が成立することを確認する。

## 出力

```text
Current set:
Decision per feature:
Reduced set:
Evidence:
Unknowns:
Risk of removal:
Validation after release:
```

## 禁止事項

- 根拠なく使用確率を数値化する
- 3round、3agent、score matrixを常に要求する
- 削除数を成果指標にする
- platform標準なら無条件に代替可能と決める
- 方針自体のgo/no-goまで扱う
