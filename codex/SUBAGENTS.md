# SUBAGENTS.md

Codex で subagent を使うときの mechanics を集約する。起動用途は `AGENTS.md`
の「subagent 活用」を参照し、このファイルでは dispatch 形式、制約、集約方法だけを扱う。

## 一次ソース確認

subagent 前提は Codex 側で変わり得るため、必要に応じて作業前に確認する。

| 確認 | コマンド / 参照先 |
| --- | --- |
| multi-agent 機能の有効状態 | `codex features list` |
| 実行時設定・feature flag | `codex doctor --all` |
| subagent tool contract | `tool_search` で multi-agent tool を確認 |
| prompt に入る指示 | `codex debug prompt-input ping` |

`child_agents_md` などの child-agent 定義自動読込は、有効であると仮定しない。
このファイルは `~/.codex/SUBAGENTS.md` にリンクされる運用文書であり、agent 定義の
自動登録ファイルではない。

## 起動判断

- subagent は候補にするが、Codex の tool contract が最優先。
- `spawn_agent` が「ユーザーの明示要求時のみ」と定義されている環境では、明示要求なしに起動しない。
- `AGENTS.md` の「必ず使う場面」またはコマンド / skill が subagent 必須と定める場合は、dispatch できなければ親セッション内で代替しない。`subagent dispatch unavailable` と報告し、そのタスクを BLOCK 扱いにする。
- 任意利用の場面で dispatch できない場合は、親セッション内で同じ観点分解を行い、必要なら `subagent skipped: <理由>` と報告する。
- 直近の判断をブロックする調査は親セッションで行う。
- 同じ問いを親と subagent で重複調査しない。

## 並列起動

- 独立タスクだけを並列化する。
- 1 回の並列 dispatch は原則 3 件まで。
- 観点を分ける: security / performance / maintainability、docs / tests / implementation など。
- 同一観点を複数 agent に投げない。

## dispatch 入力契約

worker / explorer には以下を明示する。

| 項目 | 内容 |
| --- | --- |
| 役割 | 何を判断・調査・実装するか |
| スコープ | 担当外に踏み込まない制約 |
| 入力データ | 対象ファイル、仮説、機能リスト、期待する確認結果 |
| 編集範囲 | worker の担当ファイル。他者の変更を戻さないこと |
| 出力形式 | 親が集約できる結論、根拠、変更ファイル、検証結果 |

## dispatch 出力契約

subagent の結果は次の形で集約できること。

- 結論ラベル: 採用 / 棄却 / 要確認
- 根拠: 実ファイル、ログ、コマンド出力、差分
- 変更したファイル: worker の場合のみ
- 自己申告: 詰まった箇所、裁量補完、未確認事項

## 親セッションの責務

- subagent の結果をそのまま採用せず、親が差分とテストで検証する。
- subagent 側でラウンド間集約や最終判断をさせない。
- worker が編集した場合、親が競合・不要差分・未検証箇所を確認して統合する。
- 必要な test / lint / build は親セッションが最終的に実行する。

## 再 dispatch 条件

- 根拠が抽象的で、実ファイル・ログ・コマンド出力に結びついていない。
- スコープ外の判断が混ざっている。
- 複数 agent の観点が重複している。
- worker が他者の変更を戻している。
