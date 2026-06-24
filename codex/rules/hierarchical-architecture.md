# Architecture Invariants

<!-- codex-port: managed; source=claude/rules/hierarchical-architecture.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/hierarchical-architecture.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Global and project rules live under `${HOME}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

アーキテクチャ上、常に守る不変条件。設計の手順・判断は `arch` スキルを参照する。

## 依存方向

- 依存は上位→下位の一方向のみ。下位→上位の依存をしない
- 横参照 (同一レイヤー間の直接参照) をしない
- 段階飛ばしのアクセスをしない (中間レイヤーを必ず経由する)
- 上位は指示のみ。下位の内部操作を代行しない

## 合成と継承

- 継承より合成を優先する。能力・振る舞いの差分はコンストラクタ注入で合成する
- 継承深度は 2 段まで
- 具象クラスではなくインターフェースに依存する (DI)

## インターフェース

- インターフェースは単一責任。薄く保つ (必要最小限のメソッドのみ)
- 入力と出力は論理的責務で分離する

## 命名

レイヤー役割をサフィックスで表す。

| 役割 | サフィックス |
| --- | --- |
| 管理 (下位のライフサイクルを持つ) | `*Context`, `*Manager` |
| 提供 (同種能力を束ねる) | `*Provider`, `*Registry` |
| 操作 (特定リソースに直接アクセス) | `*Accessor`, `*Client` |

`*Service` / `*Repository` / `*Handler` 等は、責務が管理/提供/操作のいずれかに一致すれば許容する。

## 入力の境界

アプリケーションコードは `Intent` (意図レベルのデータ) のみに依存し、`Raw Input` (引数・パス文字列等の生データ) を直接扱わない。


## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.
