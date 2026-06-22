# hold-out — failure-logging（過適合チェック）

baseline 連続 2/2 達成後の hold-out 評価。single subagent で dispatch。

## シナリオD（バグ原因究明依頼 = systematic-debugging 領域、誤発動回避）

**状況**:
ユーザーから「`user.service.test.ts` が落ちてる。なぜ落ちてるか調べて原因を教えて」と依頼。失敗は今回 1 回目、`claude_tmp/failure_log/` には関連エントリなし、エラーログも未提示。ユーザーは修正実装ではなく**原因の説明**を求めている。

## 実行結果

| 指標 | 値 | 前回（iter 3 平均）比 |
|---|---|---|
| 成功/失敗 | ○ | — |
| 精度 | 100%（6/6） | ±0pt |
| tool_uses | 1 | ±0 |
| duration | 35.8s | -4.8%（iter 3 平均 37.6s） |
| retries | 0 | — |

**baseline 100% → hold-out 100%、差 ±0pt で overfit なし** ✅

## [critical] 項目の達成状況

| # | 項目 | 判定 | 実地の引用根拠 |
|---|---|:---:|---|
| 1 | 中核は systematic-debugging に委譲判断 | ○ | subagent「**failure-logging スキルの中核発動対象ではない**。中核は `systematic-debugging` スキル（4フェーズ根本原因分析）へ委譲」と明記 |
| 2 | 失敗エントリ新規作成を主要対応にしない | ○ | subagent「フェーズ1（失敗記録）を**軽量に**実施」「補助対応（failure-logging 範囲内）」と明記、中核から分離 |

両 [critical] ○ で成功判定。全 6 項目 ○ で精度 100%。

## 境界判定の自発性（FL-0-1 検証）

iter 0 時点の懸念 FL-0-1「境界節が body に無いため、systematic-debugging 委譲が曖昧になる可能性」を検証:

subagent は境界節が存在しない状態でも、**description の「失敗DB構築」文言と body の L12/L14 トリガー条件を突き合わせ**て自発的に境界判断を実施:

> 「failure-logging は『失敗**記録** DB の構築・参照』が責務であり、『失敗**原因の分析**』は守備範囲外」

→ **description の文言そのものが境界機能を果たした**ため、body 側に境界節を追加する必要性は実害として顕在化せず。iter 2 で SKILL.md 修正を 1 行追記に留めた判断が正しかったことの裏付け。

## 補助対応の組み立て（ユーザー依頼の文脈を崩さない）

subagent は「中核委譲 + 補助記録」の 2 層構造を自発的に構築:

1. **中核**: systematic-debugging に委譲、TDD / consultation とも連携
2. **補助 (failure-logging 範囲内)**:
   - フェーズ1（記録）を軽量実施、ただしエラーログ未提示のため「試した手法/コマンド」「結果」は**ユーザー確認待ち**扱い
   - 原因欄は**空欄**（L108 禁止事項「原因不明時に原因を推測記入する」遵守）
   - フェーズ2（履歴参照）は新規 DB でヒット見込みなしのため補助的位置づけ
   - フェーズ3（解決時更新）は systematic-debugging の原因特定後に `✅ 解決済み` マーク
3. **再発動予告**: 同じ `user.service.test.ts` で **2 回目のつまずき**時（L14）には failure-logging を中核発動

→ 委譲先スキルへのハンドオフ情報（実行コマンド / エラーログ / 直近変更箇所）もユーザー質問案として提示。hold-out で**誤発動阻止と補助活用の両立**を実地確認。

## 残存不明瞭点（今回新出）

### SKILL.md 起因
- **FL-D-1**: L97「関連キーワード」定義が「テスト名単位 / エラー種別単位」どちらか曖昧 → iter 1-3 の FL-1-B-1 と同系統、裁量許容範囲
- **FL-D-2**: フェーズ1 Step 2「既存ファイルの末尾を読む」と前提条件 L23「既存ファイルの最大連番から継続」の関係（編集ケースで末尾≠最大連番）が微妙 → iter 0 FL-0-2 の再浮上、発生頻度低く裁量許容

いずれも**中核 2 柱（トリガー判定 / 境界判断）**には影響せず周辺運用詳細。明文化より subagent 裁量維持の方が肥大化リスクが低いため iter 4+ に昇格しない判断（tdd hold-out の残存曖昧と同じ整理）。

### empirical-prompt-tuning 側
- **EP-D-1**: 要件3「補助的に扱ってよい」の粒度（記録実施か判断のみ提示か）が「実際にはファイルを作成しない」制約との両立で曖昧 → empirical 契約由来、Phase 4 送り
- **EP-D-2**: 要件5「履歴参照は実施可」の「可」が必須か任意かの区別 → empirical 契約由来、Phase 4 送り

## 収束判定

- **連続 2/2 + hold-out パス** ✅（典型スキル目標到達）
- **baseline 100% → hold-out 100%、差 ±0pt で overfit なし**
- SKILL.md 変更総量: +1 行（L95 後に `[件数]`/`[手法名]` 定義注釈）のみ
- 中核 2 柱（トリガー判定・境界判断）は iter 1-3 + hold-out で全シナリオ安定
- 残存曖昧はすべて裁量許容範囲、subagent が自己完結的に正解到達

## 他スキルとの比較

| スキル | iter 数 | 連続クリア | hold-out 結果 | SKILL.md 変更量 |
|---|---|---|---|---|
| tdd | 4 | 3/3 | 100% | +38行 (A-2/A-2'/C-3'テンプレ) |
| systematic-debugging | 4 | 3/3 | 100% | +3行 + 2行 + 1行 |
| test-coverage-guard | 2 | 2/2 | 100% | +1行 (Spy許容) |
| refactoring | 3 | 2/2 | 100% | +10行 (委譲先節) + 1行 |
| interface-first-design | 4 | 3/3 | 100% | +6行 (粒度) + 2行 (要確認) + 1行 |
| consultation | 3 | 2/2 | 100% | +12行 (境界節) + 1行 |
| e2e-browser | 4 | 2/2 | 100% | +5行 (fixture) + 8行 (境界節) |
| qa-nightmare | 4 | 2/2 | 100% | +12行 (境界節) |
| measure | 3 | 2/2 | 100% | +13行 (境界節) |
| **failure-logging** | **3** | **2/2** | **100%** | **+1行（注釈）** |

failure-logging は**全スキル中最小の変更量**で収束。description の自己完結性が高く、body も 108 行と薄いが網羅性があるため「境界節新設」ではなく「出力形式注釈の補完」だけで済んだ。

## PR 対象ファイル

- `claude/skills/failure-logging/SKILL.md`（+3 行、空行込み表示）
- `docs/tuning-logs/failure-logging/scenarios.md`（新規）
- `docs/tuning-logs/failure-logging/iter-0.md`（新規）
- `docs/tuning-logs/failure-logging/iter-1.md`（新規）
- `docs/tuning-logs/failure-logging/iter-2.md`（新規）
- `docs/tuning-logs/failure-logging/iter-3.md`（新規）
- `docs/tuning-logs/failure-logging/hold-out.md`（新規、本ファイル）
- `.claude/progress.md`（更新）
