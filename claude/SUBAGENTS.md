# SUBAGENTS.md

サブエージェント (subagent) の**起動 mechanics** (dispatch 形式 / 並列起動 / 集約 / 制約) を集約する。**起動用途** (どんなときに subagent を立てるか) は `global_CLAUDE.md` 「🤖 サブエージェント」節を参照。両者は棲み分け関係にあり、各 skill / command は本ファイル + global_CLAUDE.md を参照することで重複記述を避ける。

## 並列起動の作法

- **独立タスクは同一メッセージ内に複数の Agent 呼び出しを並べる** (逐次起動は並列性を失う)
- 1 メッセージ内で最大 3 並列まで。それ以上は集約コストが上回る
- 観点が独立していること (例: セキュリティ / パフォーマンス / 保守性) を確認してから並列化する
- 同一観点を 2 並列に分けても効果は出ない (バイアスは観点間でしか散らない)

## dispatch 入力契約

各 subagent への入力に以下を明示する:

| 項目 | 内容 |
| --- | --- |
| 役割 | 何を判断・調査・出力するか (1 文で言語化できること) |
| スコープ | 担当外観点に踏み込まない明示制約 |
| 入力データ | 検証対象のコード / 仮説 / 機能リスト (固定: subagent が勝手に分割・集約しない) |
| 出力フォーマット | 親が機械的に集約できる形式 (3 軸スコア / リスト / マトリクス等) |
| 環境制約 | dispatch 不能環境では skip し理由報告 |
| thinking_budget | `default` (定型実装・既知パターン) / `high` (設計判断・複数案比較・バグ調査) / `xhigh` (アーキテクチャ変更・セキュリティ審査) / `max` (新規ドメイン設計・全体影響調査、乱用禁止)。迷ったときの方向は `opus-47-policy.md`「Thinking Budget Policy」に従う。未指定時は呼び出し元スキルの推奨レベル |

## dispatch 出力契約

subagent は以下を返す:

- 結論ラベル (採用 / 棄却 / 要確認)
- 結論根拠 (実コード / ログ / 計測値の引用。抽象表現禁止)
- 自己申告 (詰まった箇所・裁量補完・再試行回数)

## 集約は親 (発動主体) が行う

- subagent 個別レポートを**親が事後集約**する。subagent 側ではラウンド間集約・拡張モード発動判定は行わない
- **nested dispatch (subagent から subagent を呼ぶ) は Claude Code 標準 harness で許可されない**。1 段 dispatch で完結する設計にする
- 同じ subagent を再利用しない (前回の出力を学習している)。毎回新規 dispatch する
- subagent 出力は親側で `.claude/notes/{task-id}.md` へ追記する (構造は `phase-gate-framework.md`「subagent 出力の永続化」参照)。これにより複数 subagent 結果が単一ファイルに集約され、後続セッション / 他 skill から参照可能になる

## 再 dispatch 条件

以下に該当する場合は subagent を再 dispatch する:

- 結論根拠が抽象表現 (「重要そう」「便利そう」「慣習だから」) に留まる
- 採点根拠が判定文言からの推測に留まり、(a) 入力側の具体値 / (b) 期待値 / (c) 不一致根拠 のいずれかが欠落
- 3 並列で全件が単一観点に偏る (subagent 出力品質の問題)

## 環境制約

dispatch 不能環境 (既に subagent として動作している / Task tool 無効化等) では subagent 起動を要求する skill / command は**適用しない**。skip 時は `<skill>: skipped (理由: dispatch 不能環境)` を 1 行明示する。

## 種別の使い分け

種別 (`Explore` / `general-purpose` / `Plan` / `qa-nightmare` / `test-writer` 等) と用途の対応 / 起動しないケースは `global_CLAUDE.md`「🤖 サブエージェント」節を参照。本ファイルでは mechanics のみ扱う。

## skill / command 固有の起動契約

skill / command 固有の dispatch 内容 (手法名 / 評価軸 / 採点ルール) は各 skill / command 内に書く。本ファイルは共通の mechanics のみ扱う。

| skill / command | 固有契約の所在 |
| --- | --- |
| `premise-questioning` | 「subagent 起動契約」節 (第一原理 / Inversion / 5 Whys + 3 軸スコア) |
| `feature-pruning` | 「subagent 起動契約」節 (YAGNI Probe / Convention Audit / Existing Substitute + 機能 × 3 軸マトリクス) |
| `empirical-prompt-tuning` | 「subagent 起動契約」節 (プロンプト実行者として dispatch + 自己申告レポート) |
| `systematic-debugging` | Phase 3.5「並列仮説検証」(原因層別 3 並列深掘り) |
| `test-coverage-guard` | Step 2「観点別 subagent 並列化」(P1 / P2 / P3 観点別スキャン) |
| `architecture-design` | 「複数設計案の並列出し」(明示要求時のみ) |
| `commands/deep-review` | Step 4「3 並列 subagent dispatch」(`general-purpose` / security・performance・maintainability 担当割り) |
| `commands/feat` | Phase 1 影響範囲特定 (本文 inline、見出しなし。`/feat` 起動時の必要時のみ並列化) |
| `agents/qa-nightmare` | 単独 subagent (悪夢テストケース網羅) |
