# Phase Gate Framework

<!-- codex-port: managed; source=claude/rules/phase-gate-framework.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/phase-gate-framework.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Global and project rules live under `${HOME}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

スキル / 長時間タスクのフェーズ遷移時に置く**ゲート** (gate) の標準規約。Opus 4.7 の self-checking 能力を構造化された check point として活かす。

opus-47-policy.md の Self-Review Gate (常時適用) が**点**のゲートだとすれば、本 framework は**スキル内フェーズ間に置く線**のゲート。両者は併存し、後者が前者を内包する。

## 🎯 Gate の役割

- フェーズ遷移時に**前提が満たされていることを検証**する
- 検証失敗時は前フェーズへ差し戻す (前進しない)
- 検証結果を `.codex/notes/{task-id}.md` に記録する (4.7 のファイルメモリ強化に対応)

## 🚪 Gate 種別 (3 種)

スキルは以下から必要なものを採用する。**全部置く必要はない**。

### 1. Plan Gate (計画 → 実装)

実装へ進む前に検証する。失敗したら計画フェーズへ戻す。

| # | チェック項目 |
| --- | --- |
| 1 | 入出力の型と契約を 1 文で言える |
| 2 | エッジケースを 3 つ以上挙げた |
| 3 | 既存パターン (skills / rules) との整合を確認した |
| 4 | テスト可能な単位に分割されている |
| 5 | 失敗時の rollback 手順がある |

(opus-47-policy.md の Self-Review Gate と同一項目。Plan Gate はその**フェーズ末への明示配置**版)

### 2. Verify Gate (実装 → 完了)

完了報告へ進む前に検証する。失敗したら実装フェーズへ戻す。

| # | チェック項目 |
| --- | --- |
| 1 | 該当スキル固有の成功基準を全て満たした |
| 2 | 全テストが pass している (未確認での pass 報告は禁止) |
| 3 | 既存テストを破壊していない |
| 4 | hook block が出ていない |
| 5 | スキル固有の品質基準 (security / performance / accessibility 等) を満たした |

### 3. Handoff Gate (skill 完了 → ユーザー報告 / 次タスク)

ユーザーへの完了報告前に検証する。失敗したら記録漏れを補完してから報告する。

| # | チェック項目 |
| --- | --- |
| 1 | `.codex/progress.md` を更新した (完了マーク + 次タスク) |
| 2 | `.codex/notes/{task-id}.md` の要点を progress.md の判断ログへ反映した |
| 3 | subagent 出力 (あれば) を notes へ集約した |
| 4 | 残課題 / 未確認事項を明示した |

## 📝 Gate の記述形式

スキル内では gate を以下の形式で明示する:

```markdown
### Plan Gate
進めて良いかを次の項目で自己検証する。No が 1 つでもあれば計画へ戻る:

- [ ] 入出力の型と契約を 1 文で言える
- [ ] エッジケースを 3 つ以上挙げた
- [ ] 既存パターンとの整合を確認した
- [ ] テスト可能な単位に分割されている
- [ ] 失敗時の rollback 手順がある
- [ ] (skill 固有項目を追記可)
```

## ➕ カスタム項目

各スキルは標準項目に**追加項目**を持てる (削除は不可)。例:

- `tdd`: RED が本当に失敗しているか / GREEN は最小実装か / REFACTOR で振る舞いが変わっていないか
- `code-review`: 3 観点 (security / performance / maintainability) を網羅したか
- `systematic-debugging`: 仮説の検証手段が具体的か / 再現条件が記録されているか

## 🤖 Subagent 連携

### dispatch 入力契約 (SUBAGENTS.md と同期)

subagent 呼び出し時、以下を入力契約に含める:

| 項目 | 内容 |
| --- | --- |
| 役割 | 何を判断・調査・出力するか (1 文) |
| スコープ | 担当外観点に踏み込まない明示制約 |
| 入力データ | 検証対象 (固定) |
| 出力フォーマット | 親が機械的に集約できる形式 |
| 環境制約 | dispatch 不能環境では skip し理由報告 |
| **thinking_budget** | **default / high / xhigh / max のいずれか (opus-47-policy 参照)** |

`thinking_budget` 未指定時の既定値は呼び出し元スキルの推奨レベル。

### subagent 出力の永続化

subagent 復帰後、出力を `.codex/notes/{task-id}.md` の以下構造へ追記する:

```markdown
## subagent: {name} ({YYYY-MM-DD HH:MM})
- 役割: ...
- thinking_budget: high

### 結論
採用 / 棄却 / 要確認

### 根拠
- ...

### 自己申告
- 詰まった箇所 / 裁量補完 / 再試行回数
```

これにより、後続セッションや別 skill から subagent 結果を参照可能になる (4.7 のファイルメモリ強化の活用)。

## 🚫 Gate を**置かない**ケース

- 軽量編集 (1 ファイル / 30 行未満 / typo) → gate は省略可
- skill を読まずに済む単純タスク → そもそも skill 適用外
- gate を**機械的にチェックリスト消化するだけ**で意味のある内省が伴わない場合 → 失敗。1 段上の thinking レベルで再実施



## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.
