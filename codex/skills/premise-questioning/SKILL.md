---
# codex_port_source: common/skills/premise-questioning/SKILL.md
name: premise-questioning
description: 高影響・不可逆・前提不確実な方針を、実装前に白紙から問い直す。通常の機能追加や局所修正では使わない。「そもそも必要か」「前提を疑って」「go/no-goを検証して」で明示起動する。
disable-model-invocation: true
effort: high
---

# Premise Questioning

<!-- codex-port: managed; source=common/skills/premise-questioning/SKILL.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/skills/premise-questioning/SKILL.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

方針の妥当性を検証する。目的は考える回数を増やすことではなく、誤った問題設定や不可逆な判断を実装前に止めることである。

## 使用条件

次のいずれかに該当する場合だけ使用する。

- architecture、public contract、data migration、dependency等の高影響判断
- rollbackが困難または失敗時の損失が大きい
- 根本目的、前提、対象範囲について実質的な不確実性がある
- ユーザーが明示的に方針検証を要求した

routine change、局所bug fix、既存patternに沿う実装では使用しない。

## 手順

### 1. 方針を1段落へ固定する

次を記述する。

```text
Problem:
Desired outcome:
Proposed approach:
Constraints:
Known alternatives:
Unknowns:
```

### 2. 必要なlensだけ選ぶ

固定ラウンドや固定順序は使わない。対象の不確実性に応じて1-3個を選ぶ。

- First principles: 慣習を外して最小構成から再構築する
- Inversion: 失敗済みと仮定し、最も現実的な失敗経路を探す
- 5 Whys: 症状ではなく根本目的を確認する
- Constraint removal: 制約由来の選択か本質的選択かを分ける
- Reframing: 問題文を別の責務・境界から書き直す

親が十分に独立検討できる場合は親だけで行う。高コスト判断で、独立した見方が結論を変え得る時だけsubagentを使う。

### 3. 証拠と仮定を分ける

- source、measurement、contract等で確認できた事実
- 推論
- 未確認の仮定

を分離する。架空の確率や根拠のないscoreを作らない。

### 4. 最小の結論を出す

- `ADOPT`: 現方針を採用
- `REVISE`: 条件またはscopeを修正して採用
- `REJECT`: 問題設定または方針を撤回
- `UNKNOWN`: 判断に必要な証拠が不足

結論が明確なら追加roundを行わない。

## 出力

```text
Decision:
Reason:
Evidence:
Assumptions:
Rejected alternatives:
Required validation:
```

## 禁止事項

- 毎回3round以上を強制する
- subagent数やmodelを固定する
- 結論が出ているのにscore収束のため反復する
- 実装の小ささではなく行数だけで起動する
- 方針検証自体を実装開始の儀式にする
