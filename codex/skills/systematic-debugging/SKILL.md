---
# codex_port_source: common/skills/systematic-debugging/SKILL.md
name: systematic-debugging
description: バグやテスト失敗に遭遇した際に使用。修正前の4フェーズ根本原因分析を強制。「エラーが出る」「動かない」「落ちる」「なぜ失敗するか」で発動。
effort: xhigh
---

# Systematic Debugging

<!-- codex-port: managed; source=common/skills/systematic-debugging/SKILL.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/skills/systematic-debugging/SKILL.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Global and project rules live under `${HOME}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

## トリガー条件

以下のいずれかに該当する場合、このスキルを**必ず**発動する:

- バグ・テスト失敗・エラーに遭遇したとき
- 「なぜか動かない」「期待通りに動かない」と報告されたとき
- 修正を試みたが直らないとき（1回以上失敗）
- 原因不明の挙動を調査するとき

**発動タイミング**: 修正コードを書く**前**に必ず実行する。

---

## 前提条件

- 対象のコード・ログ・エラーメッセージにアクセスできること
- テスト実行環境が利用可能であること
- 再現手順が存在すること（存在しない場合はPhase 1で作成）

---

## 鉄則

**推測での修正禁止。根本原因を特定してから修正。**

---

## 4フェーズ (スキップ禁止)

### Phase 1: 再現

100%再現可能にする。再現できなければ修正提案禁止。

```
- [ ] 症状を正確に記録
- [ ] 最小再現ケースを作成
- [ ] 環境情報を収集
- [ ] 再現手順を文書化
```

### Phase 2: 境界トレース

どの層で問題が発生しているか特定。

```
- [ ] フロントエンド / バックエンド / DB / 外部サービス
- [ ] どの時点でデータが壊れるか?
```

### Phase 3: 根本原因特定

「なぜ?」を繰り返す。**最低2回、症状の原因層（データ・責務・契約のいずれか）に到達するまで（3-5回目安）**。

```
症状 → なぜ? → なぜ? → なぜ? → 根本原因
```

### Phase 3.5: 並列仮説検証 (subagent dispatch)

Phase 3 で根本原因の仮説が**複数**立った場合、または以下のいずれかに該当する場合は **3 並列 subagent で独立に深掘りする**。dispatch 形式・並列起動の作法・種別選択は `${HOME}/.codex/SUBAGENTS.md` を参照:

- 仮説 A/B/C で**原因層 (データ / 責務 / 契約) が異なる**
- 1 仮説で深掘りしたが結論に確信が持てない (修正 1 回以上失敗)
- 影響範囲が 3 層以上 (例: API + Service + DB) または 3 ファイル以上にまたがり、層をまたぐ可能性がある

**本 skill 固有の dispatch 内容**: 各 subagent に「仮説 X と再現コード / ログ」を渡し、「なぜ?を 5 回独立に深掘りせよ。他仮説を参照するな」を指示する。subagent 種別はコード探索中心なら `Explore`、横断的なら `general-purpose`。

**集約方法**: 3 仮説のうち実コード / ログと整合する仮説のみ採用。複数残った場合は再現実験 (失敗テスト + 仮説別の最小修正) で篩にかける。**全部不整合なら Phase 1 (再現) からやり直す** (前提が崩れている)。

**起動しないケース**: 仮説が 1 つに絞れた / 局所的なバグ (null チェック追加・typo レベル) / 既知パターンで類例がある場合。`premise-questioning` と本 Phase 3.5 は責務が異なる (`premise-questioning` = **修正方針の妥当性**を問う / Phase 3.5 = **原因仮説の検証**) ため、本 Phase 3.5 起動と `premise-questioning` 起動は独立に判定する (各々の発動条件で個別判定)。

### Phase 4: TDDで修正

1. バグを再現するテストを書く (RED)
2. 最小限の修正 (GREEN)
3. リグレッションがないことを確認
4. 同種バグの他箇所への横展開を検討する (該当ありなら別タスクへ)

---

## 失敗パターン

修正が繰り返し失敗した場合、以下の段階で対応する:

- **2回失敗**: Phase 1（再現）からやり直す。最小再現ケースと境界トレースを再検証。前回の根本原因仮説が誤っていた前提で再分析
- **3回以上失敗**: アーキテクチャを疑う。ユーザーと相談（責務境界・層分離・データフローの構造的問題の可能性）

**いずれの段階でも、試した内容と失敗理由は `failure-logging` スキルで記録する**（同じ失敗を繰り返さないため）。

---

## デバッグ記録テンプレート

完了時に以下を `.codex/notes/{task-id}.md` へ保存し、根本原因と修正方針を `progress.md` の判断ログへ要約する。

```
## バグ: [一行サマリ]
### 再現手順: 1. ... 2. ...
### 環境: OS / バージョン
### エラーメッセージ: (原文)
### 試したこと: [内容] → [結果]
### 根本原因:
### 修正方針:
```

---

## アンチパターン

- 推測だけで修正する
- 再現せずに修正する
- 根本原因を特定せずに対症療法
- 試した内容を記録しない
- 同じ失敗を繰り返す
- Phase 1〜4をスキップして修正コードを書く
- エラーメッセージを原文確認せずに対応する

---

## 一次ソース確認

- コード確認: 実ファイルを読む（推測禁止）
- API/関数: 公式ドキュメントまたは定義元を確認
- エラー: ログ原文を必ず引用する

---

## 関連

- `premise-questioning` - 根本原因特定後、修正方針が筋が良いかを 3 ラウンド独立検証。順序: systematic-debugging で原因特定 → premise-questioning で修正方針検証 → 修正実装
