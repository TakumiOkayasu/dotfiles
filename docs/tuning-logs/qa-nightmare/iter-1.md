# iter 1 — qa-nightmare（baseline）

empirical-prompt-tuning iter 1。3 シナリオを並列 dispatch し、**baseline 評価**を記録する。

- 対象: `claude/skills/qa-nightmare/SKILL.md`（306行）+ `checklists/*.md`（11ファイル、750行）
- 前回差分: なし（iter 0 の段階で SKILL.md は未改訂）
- 収束目標: 連続2（典型スキル）

## 変更点（前回差分）

なし（baseline）。

## 実行結果（シナリオ別）

| シナリオ | 成功/失敗 | 精度 | steps (tool_uses) | duration | retries |
|---|:---:|---:|---:|---:|---:|
| A（ユーザー登録画面 / PostgreSQL） | ○ | 100% (11/11) | 12 | 824.9s | 0 |
| B（注文管理 情報不足） | ○ | 100% (7/7) | 1 | 56.8s | 0 |
| C（通貨マスタ / MySQL / e2e連携） | ○ | 100% (9/9) | 23 | 333.7s | 0 |
| **平均** |  | **100%** | 12.0 | 405.1s | 0 |

全シナリオ `[critical]` 全 ○ で成功判定。

### tool_uses 偏り判定

- A:B:C = 12:1:23。最大 23 倍の偏り（B 基準）
- ただし B は「情報不足で確認のみ = 全 checklist 読む必要なし」で早期離脱（Phase 1 L88-92 の確認ルール発動）
- A/C は checklists 11 ファイルを順次 Read するため構造的に必要。**禁止事項 L43「チェックリスト未読でのパターン抽出」が Read 数を下支え**
- 判定: 構造的要請（feature ではなく spec）。ただし QN-0-9（スキップ判定は Read 前可否）が曖昧 → iter 2 修正候補の 1 つ

### 要件別詳細

**シナリオA (11項目)**: ○=11
- Phase 1 把握情報 7項目テーブル化、11カテゴリ全走査、NM-001..NM-048 の計48ケース出力、スキップ理由を個別+一括で併記、Phase 4 案内で Phase 5 実行せず

**シナリオB (7項目)**: ○=7
- 「把握すべき情報」7項目中、不足5項目を判定（スキーマ/権限/状態遷移すべて不明）、確認5項目を優先順位通り（スキーマ→権限→状態遷移→外部連携→ビジネスルール）に列挙、`[推測]` マーカー案内あり、既提供（URL/CRUD/操作者）は再質問せず

**シナリオC (9項目)**: ○=9
- 静的マスタで明らかに非該当な DI / BH-11 / ST-多数 / TC-多数 / ER-多数 を `XX-01〜XX-NN` 形式で一括スキップ、SC-09/SC-10/SC-07 を NM-001..003 の S ランクに配置、AB-01/02/05/06/07/09/10 採用、Phase 5 workspace 共有 + 必須 API（captureStep/captureState/dbAssert/beginCapture/destroyDb）を spec スケルトンに含め、Phase 6 クリーンアップ手順提示

## 不明瞭点（今回新出）

### ⭐ 最重要（iter 2 テーマ候補）

- **QN-1-A-1**: SKILL.md L45「嫌度ランク S のケースをユーザー判断なしに除外すること」（禁止事項）の解釈が subagent A で迷い発生。「必ず表に載せる」か「実施決定までする」か。subagent A は「表に S として列挙し Phase 4 で除外可否を確認」で正解運用したが、ルールの解釈曖昧。L208-216 Phase 4 の「1. 実行するランクの範囲」との整合が弱い
- **QN-1-C-1**: checklists/*.md の各パターンにある「嫌度: ★★★★★」記法と、SKILL.md Phase 3 L146-168 の「発見困難度 × 被害度 → 積ランク」の対応関係が明示されていない。subagent C が独立報告。subagent A は「★数は参考、最終スコアは攻撃再現性×実害で再採点」と裁量補完したが、この運用方針が body に書かれていない
- **QN-1-B-1**: L92「確認せずに推測で進めた場合は、生成したテストケースの『選定理由』欄に `[推測]` マーカーを付ける」の適用範囲が「テストケース生成時限定か、Phase 1 の前提情報記述にも及ぶか」不明瞭。subagent B は原文準拠で「テストケース限定」と解釈

### 中（隣接スキル境界）

- **QN-1-AC-1**: e2e-browser との境界（双方向）が body に未明示。e2e-browser 側は iter 3 で「関連スキル・境界」節に qa-nightmare 行追加済（PR#270 merged）だが、qa-nightmare 側に逆リンクがない
- **QN-1-AC-2**: tdd / test-coverage-guard / systematic-debugging との境界節が qa-nightmare 側にない。refactoring / consultation / interface-first-design / e2e-browser iter 2-3 で追加した「関連スキル・境界」節パターンが未適用
- **QN-1-C-2**: Phase 5 L270 の結果レポート例で `TC-001` と書かれているが、禁止事項 L46「テストケース連番IDに `TC-` を使うこと」と自己矛盾。`NM-001` に修正すべき（subagent は実害なく `NM-` で生成したが、body 整合性の瑕疵）

### 軽微

- **QN-1-A-2**: L169「1行で示す」が「各ケース1行」か「全体集計で1行」か微妙。subagent A/C は「各ケース行末に `3×3=9` 形式」で正解運用
- **QN-1-C-3**: checklist の「嫌度★」記法の ★数（1-5）と積ランク（1-9）の換算表がない。subagent C は「積方式を採用」とだけ述べて混乱なし
- **QN-1-A-3**: L88「3項目以上 OR スキーマ/権限/状態遷移のいずれかが不明」の OR 条件は記載済だが、「3項目未満だがスキーマだけ不明」の境界ケース例示なし。シナリオBは両条件満たすため迷いなし
- **QN-1-A-4**: Phase 5 で「全48件の Fixture/spec を提示するか代表1-2件でとどめるか」の粒度が body に未規定。subagent A は「代表1件（NM-005）のみ提示」で実害なく対応

## 裁量補完（今回新出）

- **シナリオA**: ★数と積ランクの対応（独立に積方式を採用）、スキップ理由の粒度判定（カテゴリ全スキップ vs 個別パターンスキップの境界）、Phase 5 spec.ts の代表数（1件のみ）、`_lib/e2e` 相対パス仮置き
- **シナリオB**: 確認メッセージ冒頭の「qa-nightmare スキルを発動しました」宣言（要件6 を満たすため補完、原文に記述なし）、角括弧タグ `[スキーマ]` 等の UI 補助、「今すぐ動かしたい、細部は任せる」のフォールバック文言（L92 の実運用翻訳）
- **シナリオC**: 非admin ロール名（viewer/editor 仮置き）、SQLi テスト（ORM 前提でも DB 層保険として残す判断）、物理削除 UI 非提供でも DB 整合性として含める判断、10万件を A→B 降格

## empirical-prompt-tuning 側の曖昧点

- **シナリオA**: 「baseline 評価」の比較対象（tuned 版との差分）が同 dispatch 内にない（→ baseline 単独測定を意図と推測）、スキップ記載粒度（「カテゴリ全スキップ 1行 vs 個別 1行ずつ」）
- **シナリオB**: 「精度 % 計算に critical 重み付けあり/なし」の扱い（critical 全○なら成功別判定のため実害なし）、checklists Read 要否（Phase 1 段階では未読で可と判断）、副作用ツール（ScheduleWakeup / TodoWrite）を避ける方針
- **シナリオC**: 「spec.ts 20行以内」制約下で必須 API 5つ全部網羅する可読性トレードオフ、B/C テーブル簡略度、checklist 未読スキップ判定の境界、嫌度★と積ランクの対応ルール

## iter 2 テーマ選定

### 候補評価

| 候補 | 実害度 | 修正量 | 波及期待 |
|---|:---:|:---:|:---:|
| **隣接スキル境界節新設（e2e-browser/tdd/test-coverage-guard/systematic-debugging の委譲表）** | 中（hold-out D リスク直撃） | 中（10-15行） | **高**（hold-out 誤発動阻止 + QN-1-AC-1/2 同時解消） |
| L270 の `TC-001` → `NM-001` 修正（表記揺れ） | 低（subagent 実害なし、body 整合のみ） | 小（1行） | 低 |
| 嫌度★と積ランクの対応表追加 | 低（実害なく全 subagent が積方式で揃った） | 小（3-5行） | 中 |
| L45 Sランク除外禁止の解釈節 | 低（subagent A が正解運用） | 小（1-2行） | 低 |
| L92 `[推測]` マーカー適用範囲 | 低（subagent B が正解運用） | 小（1行） | 低 |

### 選定: **隣接スキル境界節新設**（e2e-browser / tdd / test-coverage-guard / systematic-debugging / consultation 委譲表）

**理由**:
- **波及最大**: hold-out D（誤発動回避）の**直接予防**。「悪夢ケース生成」を関数単位にも適用してしまう誤発動リスクを構造的に排除
- refactoring iter 2 / consultation iter 2 / e2e-browser iter 3 の**成功パターンを踏襲**（「委譲先節新設」は複数スキルで hold-out 精度を押し上げる実績あり）
- e2e-browser 側は既に qa-nightmare 行を含む境界節を持っている → 双方向リンクで相互参照が完成
- SKILL.md L24-26 の「発動しない場合」記述を構造化した「関連スキル・境界」表として昇格すれば、軽微修正 QN-1-A-1 / QN-1-C-1 も間接的にカバー（Sランク解釈は Phase 4 確認と委譲の接続を明文化）

**修正案（iter 2 差分）**:

SKILL.md 「前提条件」節（L28-35）直後に以下を追加:

```markdown
## 関連スキル・境界

| 状況 | 委譲先スキル | 本スキルとの境界 |
|------|------------|----------------|
| 関数単位・純粋関数のユニットテスト（DB/UI なし） | tdd | tdd=RED-GREEN-REFACTOR、本 skill は機能単位（画面/API）のみ対象 |
| 既存テストの信頼性検証（偽陽性検出） | test-coverage-guard | test-coverage-guard=GREEN後の検証、本 skill=悪夢ケース**生成** |
| 生成後の実行基盤（Docker 内 Playwright + DB） | e2e-browser | Phase 5 で e2e-browser を利用。逆方向（既存 E2E 失敗調査）は e2e-browser のみ |
| バグ発生後の原因分析（4フェーズ根本分析） | systematic-debugging | sd=発生後の診断、本 skill=発生**前**の予防的列挙 |
| 技術選定・設計相談 | consultation | consultation=判断、本 skill=列挙 |

**本スキルが担当する範囲**:
- 対象: 画面 / API など機能単位で「QA ベテランが嫌がる edge ケース」を網羅
- 前提: 対象機能名 + 画面 URL or API パス（前提条件の「対象情報」）
- 境界: 上記非該当（純粋関数 / 既存テスト検証 / テスト失敗再現 等）は発動しない
```

12 行追加（ヘッダ + 5 行表 + 4 行担当範囲）。ファイル末尾や Phase 5 に混ぜず、前提条件直後の「発動境界の可視化」位置に置く（refactoring / iface-first / consultation / e2e-browser と同じ位置）。

## 次アクション

- iter 2: 上記 12 行追加 → 3 並列再評価（新規 subagent、シナリオ A/B/C 同一）
- 期待: 精度維持（100%）、tool_uses 偏り改善なし（構造的要請）、duration ±5%、新規不明瞭点 0、シナリオ B/C で境界節の引用 or 参照が発生

## 収束判定

- 連続 0/2（iter 1 = baseline、カウント開始 iter 2 から）
- 停止条件まで最短 2 iter
