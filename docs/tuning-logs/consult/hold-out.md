# hold-out — consultation（シナリオD: 漠然質問、systematic-debugging 領域との混同）

## 目的

連続2/2達成（iter 2 + iter 3）後の過適合検出。baseline シナリオ A/B/C に存在しない hold-out シナリオD で発動抑止の正しさを検証する。

- 対象スキル: `claude/skills/consult/SKILL.md`（iter 3 時点、L118）
- baseline 直近平均: **100%**（iter 3 の A/B/C）
- 過適合判定閾値: 直近平均から **-15pt 以上落ちたら過適合**（empirical-prompt-tuning L133）

## シナリオD

ユーザー「API が 500 エラー返してる。どうすればいい?」

（補足情報なし。試したこと・エラーログ・再現手順・仮説すべて未提示）

現在のブランチ: `feat/user-api`、タスク: 「ユーザー API 実装」

## 要件チェックリスト

1. [critical] **consultation を発動しない**（「エラー未確認」「何も試さず」「漠然とした質問」すべて該当）
2. [critical] **systematic-debugging への誘導または情報収集ヒアリング**
3. 発動しない判断根拠（トリガー未該当 + 前提条件未充足 + 禁止事項該当）を明示
4. ユーザーが次に提示すべき情報（エラーログ原文、再現手順、試したこと、仮説）を列挙
5. 情報収集 → sd → 仮説確立 → consultation の順序提示

## 実行結果

| 項目 | 値 |
|---|---|
| 成功/失敗 | ○ |
| 精度 | **100%** (5/5) |
| tool_uses | 1 |
| duration | 28.9s（iter 3 平均 42.2s 比 -31.6%、早期離脱） |
| retries | 0 |
| 不明瞭点 | **新出なし** |

**[critical] 全 ○**。発動抑止 + 委譲 + 情報提示要求で subagent は初回応答で完了。

## 過適合判定

| 項目 | 値 | 判定 |
|---|---|:---:|
| baseline 直近平均（iter 3） | 100% | — |
| hold-out 精度 | 100% | **差 ±0pt** |
| 過適合閾値（-15pt） | 85% 以上維持が必要 | ✅ **過適合なし** |

## 実地観察

- **トリガー/前提条件/発動しない条件/禁止事項の4観点テーブル化**: SKILL.md の4つの判断系統（トリガー L12-18 / 前提条件 L24-30 / 発動しない場合 L20 / 禁止事項 L126-134）を独立列挙で整理、漏れなく該当判定
- **関連スキル・境界表を直接引用して `systematic-debugging` へ委譲**: iter 2 で追加した委譲先節が hold-out でも機能（refactoring hold-out / iface-first hold-out と同じく、境界明文化が非発動判定に直結）
- **情報提示要求の4項目**（エラーログ原文・再現手順・試したこと・仮説）: 禁止事項と前提条件をそのまま裏返して提示、実装者視点の具体性
- **4ステップの推奨順序**: 「情報収集 → sd → 仮説確立 → consultation」を番号付きで明示、consultation 復帰のゲート条件まで提示
- **duration -31.6%**: 早期離脱（Phase 1-4 に進まず発動抑止で完了）、test-coverage-guard hold-out -38% / refactoring hold-out -20% / iface-first hold-out -44% と同じパターン

## 裁量補完

- 応答テーブル形式（可読性のため）
- 要件4項目の列挙順序（タスク要件の指示順をそのまま採用）

いずれも構造的補完で、SKILL.md の不足を示さない。

## 収束判定

- **連続2/2（iter 2 + iter 3）+ hold-out パス + 過適合なし** ✅
- **consultation スキル収束完了**（典型スキル目標達成）
- 残存曖昧: C-1-A-1（Phase 3「スマホ・PCクライアント」の意味）は iter 3 A で再浮上したが**環境制約の自己説明**で構造的曖昧ではない → 周辺運用詳細として残置許容

## PR 対象

- `claude/skills/consult/SKILL.md`（+14行: 関連スキル・境界節 + 前提条件①拡張）
- `docs/tuning-logs/consultation/` 配下（scenarios.md / iter-0.md / iter-1.md / iter-2.md / iter-3.md / hold-out.md）

## 次スキル

- **e2e-browser**（典型スキル、連続2、scenarios.md 未作成、Phase 2 着手時に都度作成の原則通り）
- 境界: qa-nightmare は e2e-browser を依存先としている。e2e-browser description / body で qa-nightmare との役割分担を要確認
