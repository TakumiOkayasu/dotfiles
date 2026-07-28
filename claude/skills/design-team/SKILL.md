---
name: design-team
description: ちょっと大きめのタスクの設計段階で、Architect (構築役) と Devil's advocate (反対役) を独立 subagent として並行起動し、自分の指示では抜けた視点/選択肢/死角を炙り出してから設計を確定する skill。Architect は設計+代替案を、Devil's advocate は同じ仕様を独立に読んで死角/見落とし/リスク/見送った選択肢を出す (互いの出力を見せずアンカリングを防ぐ)。本体が両者を突合して統合設計を作り、2nd round で Devil's advocate に統合案を再レビューさせる。「設計チーム」「Architect と反対役」「死角を洗い出して設計」「devil's advocate」「見落とし視点をカバー」で起動。方針自体の go/no-go は premise-questioning、単一視点の設計手順は arch を使う。
---

# Design Team (Architect + Devil's advocate)

着手前の設計は、書いた本人には筋が良く見える。自分の指示の枠内で考えるほど、抜けた視点/見送った選択肢/前提の死角は見えなくなる。本 skill は構築役の **Architect** と反対役の **Devil's advocate** を独立 subagent として並行起動し、自分一人では出なかった角度を機械的に確保してから設計を確定する。

両者には同じタスク仕様を同時に渡し、互いの出力を見せない。Architect は最良設計と代替案を出し、Devil's advocate は同じ仕様を独立に読んで死角を出す。アンカリング (Architect 案に引きずられた反対) を防ぐためで、これが本 skill の核。

## 位置づけ (隣接 skill との非重複)

| skill | 守備範囲 | 本 skill との違い |
| --- | --- | --- |
| `premise-questioning` | 方針そのものの go/no-go (戦略) | 本 skill は「やる」前提で**設計の中身**を広げる |
| `arch` | 単一視点の設計手順 (レイヤー/責務) | 本 skill は**複数視点を並行**で当てて死角を潰す |
| `feature-pruning` | 個別機能/UI/API の要否 (機能粒度) | 本 skill は設計案/選択肢の**視点網羅** |
| `consult` | ユーザーへの構造化相談 | 本 skill は subagent 間で先に煮詰める |

go/no-go が未確定なら先に `premise-questioning`。本 skill は方針確定後の設計段階に入る。

## いつ使うか

- 複数ファイル/複数レイヤーにまたがる機能追加・改修の設計時
- アーキテクチャ変更/外部依存追加/データ移行など、見落としの代償が大きい設計
- 自分の最初の設計案が「これしかない」と一本に見えていて、他案を検討できていないとき
- 「ちょっと大きめのタスク」で着手前に視点を広げたいとき

使わない場面:

- 1 ファイル/30 行未満の局所変更 (起動オーバーヘッドが上回る)
- 方針自体が未確定 (→ `premise-questioning`)
- 仕様が固まり実装するだけ (→ `orchestrate` / `tdd`)

## トリガー語

- 明示: 「design-team」「設計チーム」「Architect と反対役」「devil's advocate」「死角を洗い出して」
- 自然発話: 「見落とし視点をカバーしたい」「他の選択肢も出して」「自分の案を叩いてほしい」「大きめなので慎重に設計」

## 2 つの役割

| 役割 | 立ち位置 | 出すもの |
| --- | --- | --- |
| Architect | 構築役。最良の設計を提案する | 推奨設計 + 代替案 (最低 5 案) + 各案の前提/トレードオフ |
| Devil's advocate | 反対役。仕様を独立に読み穴を探す | 死角/見落とした視点/見送られた選択肢/前提が崩れた場合のリスク |

Devil's advocate は Architect の出力を**受け取らない**。同じタスク仕様だけを見て、独立に「この仕様で設計するなら何を見落としがちか」を出す。

## ワークフロー

### Round 1: 並行・独立 dispatch (同時起動)

Architect と Devil's advocate を**同一メッセージ内**で並行起動する (逐次は並列性を失う)。独立タスクなので互いの出力は渡さない。並列起動の作法は `$HOME/.claude/SUBAGENTS.md` を参照。

dispatch 入力契約 (phase-gate-framework に準拠):

| 項目 | Architect | Devil's advocate |
| --- | --- | --- |
| 役割 | タスク仕様から推奨設計 + 代替案を出す | 同じ仕様から死角/見落とし視点/見送った選択肢/リスクを出す |
| スコープ | 設計の中身のみ。go/no-go には踏み込まない | 穴の指摘のみ。代案の完成までは求めない |
| 入力データ | タスク仕様 (固定・両者同一) | タスク仕様 (固定・両者同一、Architect 出力は渡さない) |
| 出力フォーマット | 推奨案 + 代替案 (各: 前提/トレードオフ/影響範囲) | 死角リスト (各: 種別/根拠/崩れた場合の帰結/重大度 S/A/B/C) |
| 環境制約 | dispatch 不能時は skip し理由報告 | 同左 |
| thinking_budget | high | high |

推奨 subagent: Architect → `design-consultant` または `impl-planner`、Devil's advocate → `general-purpose` (反対役プロンプトを与える) または `premise-questioning` 観点。

### 本体による統合 (突合)

両者の出力を本体が突合する。Architect の各案を Devil's advocate の死角リストと照合し、潰せた懸念/未対応の懸念を仕分ける。

突合表の例:

| Devil の死角 | 重大度 | Architect 推奨案で対応済みか | 対応 |
| --- | --- | --- | --- |
| (死角の要約) | S/A/B/C | 済 / 未 / 部分 | 設計にどう反映したか |

S/A の死角で未対応のものが残る間は、設計を確定しない。

### Round 2: Devil's advocate による統合案レビュー

統合設計を Devil's advocate に**再度** dispatch し、Round 1 で具体設計を直接叩けなかった分を補う。新たな S/A の死角が出れば本体の統合へ差し戻す。出なければ確定へ進む。

## 出力フォーマット

```markdown
## design-team 結果

### 統合設計 (確定案)
- 採用した骨格: ...
- 採った選択肢と却下した選択肢 (理由付き): ...

### Architect 提案サマリ
- 推奨案 / 代替案と各トレードオフ

### Devil's advocate が出した死角 (重大度順)
- [S] ... → 対応: ...
- [A] ... → 対応: ...
- [B/C] ... → 対応 or 許容判断

### 残課題 / 許容したリスク
- ...
```

## Gate

### Plan Gate (設計確定 → 実装着手)

No が 1 つでもあれば設計へ戻る:

- [ ] 入出力の型と契約を 1 文で言える
- [ ] エッジケースを 3 つ以上挙げた
- [ ] 既存パターン (skills / rules) との整合を確認した
- [ ] テスト可能な単位に分割されている
- [ ] 失敗時の rollback 手順がある
- [ ] (skill 固有) Architect の代替案を最低 2 案検討した
- [ ] (skill 固有) Devil's advocate の S/A 死角がすべて対応済み or 許容理由を明記した
- [ ] (skill 固有) Round 2 の再レビューを通した

## アンチパターン

- Architect の出力を Devil's advocate に渡してから反対させる → アンカリングで前提を疑う力が落ちる。Round 1 は必ず独立
- Devil's advocate を 1 回しか回さず具体設計を叩かせない → Round 2 を省くと統合案の穴が残る
- 死角を出させただけで設計に反映しない → 突合表で対応を明示するまでが本 skill
- 小さいタスクで起動する → 起動コストが上回る。局所変更は本体で直接設計する
- subagent を逐次起動する → 並列性を失う。Round 1 は同一メッセージで並行

## 関連

- `$HOME/.claude/SUBAGENTS.md`: 並列起動の上限/観点独立条件/dispatch 契約
- `premise-questioning`: 方針自体の go/no-go (本 skill の前段)
- `arch`: 確定した設計のレイヤー/責務への落とし込み
- `orchestrate`: 確定設計の task 分解 → subagent 実装 → 2 段階レビュー
