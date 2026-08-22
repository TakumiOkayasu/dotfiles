---
# codex_port_source: common/skills/consult/SKILL.md
name: consult
description: 実装前の方針決定、技術選定、設計上のtrade-off整理に使用する。比較する実質的な選択肢がある、または判断に必要な情報が不足している時に発動する。
---

# Consultation

<!-- codex-port: managed; source=common/skills/consult/SKILL.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/skills/consult/SKILL.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

判断に必要な事実、制約、選択肢、trade-offを整理し、推奨方針と実装への引き継ぎを作る。

## 使用条件

- 複数の実質的な案がある
- requirement、risk、ownershipの判断が必要
- 既存architectureに合わせるか変更するかを決める
- 実装前にユーザー決定が必要

公式documentや既存codeを読めば自明な場合、単純な調査だけの場合は使わない。

## 手順

1. 目的、現状、制約、非目標を整理する
2. 一次ソースと実測を確認する
3. 意味のある案だけを列挙する。支配的な1案しかない場合は架空の代替を増やさない
4. cost、risk、maintainability、reversibility、existing assetsで比較する
5. 推奨と却下理由を示す
6. 人間判断が必要な点だけ明示して停止する

subagentは、独立した専門調査や並列調査に価値がある場合だけ使う。

## 出力

```markdown
## 問題
- 目的:
- 現状:
- 制約:
- 非目標:

## 選択肢
### 案A
- 概要:
- 利点:
- 欠点:
- 証拠:

## 推奨
- 採用:
- 理由:
- 却下理由:
- 未確認事項:

## 引き継ぎ
- 決定:
- Tasks:
- Files:
- Done when:
```

## 禁止事項

- 必ず2-3案を捏造する
- 何も調べず相談形式だけ整える
- phone/PC等の特定clientへ送信する前提を置く
- 回答待ちを理由に無関係な作業まで停止する
- 方針決定と実装を無断で混ぜる
