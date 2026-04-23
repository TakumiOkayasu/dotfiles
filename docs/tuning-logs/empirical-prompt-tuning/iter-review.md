# empirical-prompt-tuning 構造審査レポート

**モード**: 構造審査モード (SKILL.md L124 準拠)
**実施日**: 2026-04-23
**ブランチ**: `refactor/skill-empirical-prompt-tuning-review`
**対象**: `claude/skills/empirical-prompt-tuning/SKILL.md` (191 行)

## 背景

Phase 2 (個別チューニング) で他 10 スキルがすべて収束完了 (tdd / systematic-debugging / test-coverage-guard / refactoring / interface-first-design / consultation / e2e-browser / qa-nightmare / performance-optimization / failure-logging) したため、Phase 4 として empirical-prompt-tuning 自身の構造審査を実施する。循環参照回避のため empirical 評価は行わず、記述整合性のみを静的チェック。

## 審査方法

`general-purpose` subagent に対し、SKILL.md L124 の「構造審査モード: 実行ではなくテキスト整合性チェック」を明示して 1 回 dispatch。10 項目の審査観点を指定し、行番号付き根拠での矛盾列挙を要求。

## 実害ありの矛盾 (6 テーマ)

| # | テーマ | 該当行 | 修正方針 |
|---|---|---|---|
| T1 | 構造審査モードの評価軸退化が未定義 | L124 | 退化形 (定量軸スキップ、テーマ一覧返答) を明記 |
| T2 | subagent 起動契約テンプレに構造審査モード差し替え指示なし | L87-113 | テンプレ末尾に読み替え注記を追加 |
| T3 | L36「判定規則は本節で一元定義」に反し、L47 / L128-133 で収束条件が重複 | L47 | L47 を「一元定義節への委譲」に簡素化、連続 3 条件を L128 側に移設 |
| T4 | iter 0 と構造審査モードの関係が未定義 | L22-27 / L124 | T1 の追記内で両者の違いを明示 |
| T5 | baseline シナリオ 2-3 本と hold-out 1 本の総量明示なし | L30 / L133 | L30 に hold-out 別立ての注記追加 |
| T6 | 「ステップ数」「tool_uses」「steps」の表記ゆれ | L39 / L55 / L148 | L148 の表ヘッダ `steps` → `ステップ数` に統一 |

## 残置許容 (4 項目)

| 項目 | 該当行 | 残置理由 |
|---|---|---|
| Red flags 表の連続 2 重複 | L167-178 | 反面教師としての独立価値あり |
| よくある失敗 vs Red flags 軽微重複 | L180-185 | 失敗視点として独立保持可 |
| 関連節の外部参照妥当性 | L187-191 | 本タスク範囲外 (dispatch 不可) |
| 修正の波及パターン | L73-81 | 評価軸の詳細化として独立価値 |

## 修正適用結果 (SKILL.md 差分)

| テーマ | 修正箇所 | 差分 |
|---|---|---|
| T3 | L47 簡素化 + L128 に連続 3 条件移設 | ±0 行 (置換のみ) |
| T5 | L30 に hold-out 別立て注記 | +1 行 (既存行に追記) |
| T6 | L148 表ヘッダ統一 | ±0 行 (置換のみ) |
| T1+T4 | L124 節末尾に退化形 + iter 0 差分追記 | +3 行 |
| T2 | L113 起動契約テンプレ直後に読み替え注記 | +2 行 |
| **合計** | | **+6 行** |

## 収束判定

構造審査モードは empirical-prompt-tuning SKILL.md L124 により**連続クリア判定の対象外**。本タスクは単一 PR で完結し、iter 反復は行わない。修正後の再審査も循環参照を避けるため行わない。将来、別セッション empirical (真 empirical) を実施する場合は plan Phase 4 の「別セッション empirical (オプション)」フローに従う。

## 構造審査モード自己適用判定

**○** — subagent dispatch は審査依頼のみ (シナリオ実行なし)、Read ベースの記述整合チェックに限定、L124 の「補助 (連続クリア判定には使えない)」精神に準拠。

## 他 10 スキルログとの既知曖昧点クロスチェック

本タスクの構造審査では範囲外と判定 (既知曖昧点の突合は dispatch 相当のコストがかかり、構造審査モードを逸脱するため)。修正後に将来横断ログ走査で浮上した場合は Phase 3 (横断リファクタ) で扱う。

## 次アクション

- [x] SKILL.md に T1-T6 修正を適用
- [x] PROGRESS.md 更新 (empirical-prompt-tuning 構造審査完了)
- [ ] ユーザーに commit/push/PR 依頼
- [ ] Phase 5: `./install.sh -n` 配布検証 (別ブランチ)
