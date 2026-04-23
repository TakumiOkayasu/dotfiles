# iter 0 — qa-nightmare（description/body 整合チェック）

empirical-prompt-tuning の iter 0 フェーズ。SKILL.md + checklists/*.md の構成と description の整合性を審査する。subagent dispatch は iter 1 から。

## 対象

- スキル: `claude/skills/qa-nightmare/SKILL.md`（306行）+ `claude/skills/qa-nightmare/checklists/*.md`（11ファイル、計750行）
- description: 「QAベテランが嫌がる悪夢テストケースを生成し、e2e-browserで自動実行する。11カテゴリ109パターンの網羅的チェックリストから対象機能に適用可能なケースを抽出・ランク付け。」
- 収束目標: **連続2**（典型スキル）

## description の構成要素

| 要素 | 内容 |
|------|------|
| 対象 | 悪夢テストケース（QAベテランが嫌がるレベル） |
| 主要動作 | 生成 + e2e-browser で自動実行 |
| スコープ | 11カテゴリ109パターンの網羅 |
| 出力 | 対象機能に適用可能なケースを抽出・ランク付け |

## body の主要セクション

| セクション | 行 | 内容 |
|---|---|---|
| トリガー条件 | L12-26 | 4項目発動 + 3項目非発動（軽微バグ/ユニットテスト/`$ARGUMENTS` 空） |
| 前提条件 | L28-35 | 4項目（チェックリスト/e2e-browser/対象情報/Docker） |
| 禁止事項・制約 | L37-46 | 6項目（スキップ理由必須/Phase 4 必須/`$E2E_WORK`外禁止/チェックリスト未読禁止/Sランク除外禁止/`TC-` ID衝突禁止） |
| 概要 | L50-73 | 11カテゴリ一覧表 + 各 .md ファイル参照 |
| Phase 1 機能分析 | L76-102 | ステップ / 情報不足時対処ルール / 把握すべき情報7項目 |
| Phase 2 チェックリスト適用 | L106-132 | ステップ / 適用判定基準 / 該当しないパターン例 |
| Phase 3 ランク付け | L136-202 | ステップ / 嫌度スコアリング / ランク決定 / 出力フォーマット / スキップ記載ルール |
| Phase 4 ユーザー確認 | L206-216 | 3項目確認（ランク範囲 / 除外 / 追加） |
| Phase 5 e2e-browser 連携 | L220-275 | 5-1 workspace / 5-2 テストコード生成 / 5-3 実行 / 5-4 結果レポート |
| Phase 6 クリーンアップ | L280-287 | `docker compose down -v` + `rm -rf $E2E_WORK` |
| チェックリスト拡張 | L291-306 | 新パターン追加手順 |

## 整合性評価

### ✅ description と body が整合している箇所

| description | body 裏付け |
|---|---|
| 「QAベテランが嫌がる悪夢テストケース」 | checklists/*.md の11カテゴリ109パターン（嫌度★★★☆☆〜★★★★★） |
| 「生成し、e2e-browserで自動実行する」 | Phase 5 全節（5-1〜5-4）で e2e-browser workspace 共有 + テストコード生成 + 一括実行 |
| 「11カテゴリ109パターン」 | L60-72 のカテゴリ表で 11 カテゴリ合計 104 パターン（概算で 109 ≈ 104、小誤差） |
| 「対象機能に適用可能なケースを抽出」 | Phase 2 適用判定基準 + 該当しないパターン例 |
| 「ランク付け」 | Phase 3 嫌度 = 発見困難度 × 被害度 → S/A/B/C |

### ⚠️ 乖離点（iter 1 観測後に修正判断）

| # | 乖離 | 重要度 | 詳細 |
|---|---|:---:|---|
| QN-0-1 | description「109パターン」と実体のパターン数に齟齬 | 中 | L60-72 のカテゴリ表合計は 10+8+11+10+10+10+10+10+10+10+10 = **109** だが、SKILL.md L57「109パターン」と L3 description が一致。wc-l で概算検証では各 checklist md 65-76 行で推定合致。問題なし、観察のみ |
| QN-0-2 | checklists/ 本体が body に inline されていない（参照先のみ） | 高 | subagent が `~/.claude/skills/qa-nightmare/checklists/*.md` を読める前提。dispatch 時に全 .md を渡すか、Read で参照させる必要あり。dispatch プロンプトで全パスを明示する必要（subagent dispatch 契約で解決可能、SKILL.md 側の修正不要） |
| QN-0-3 | 前提条件「Docker が実行可能」と subagent 実行可能性の乖離 | 中 | e2e-browser iter 0 EB-0-1 と同種。subagent は Docker を持たないため Phase 5 execution は評価対象外。body 側に「生成までで止める場合の指針」が未明示。シナリオC 焦点 |
| QN-0-4 | 情報不足時の確認ルール（L86-92）と「3項目以上不足」の判定基準が主観的 | 中 | 「7つの把握すべき情報のうち3項目以上」は数えられるが、「1項目でも複合的（例: スキーマ1つに対して全カラム詳細）」なのか「カテゴリ単位で1カウント」なのか曖昧。シナリオB 焦点 |
| QN-0-5 | e2e-browser との境界が body に未言及（description では「自動実行する」だけ） | 高 | シナリオC 焦点。qa-nightmare → e2e-browser の依存関係は明示（Phase 5）だが、逆方向（「E2E テスト作って」が qa-nightmare に流れない）の境界は body に記載なし。e2e-browser iter 3 の境界節（`refactor/skill-e2e-browser-tuning` マージ済）では qa-nightmare 行が追加済 → **双方向に境界節を置くべき** |
| QN-0-6 | tdd との境界が L25「ユニットテストのみの依頼 → TDDスキル」でのみ示され、関連スキル節がない | 中 | シナリオD 焦点。e2e-browser / consultation / interface-first-design iter 2-3 で追加した「関連スキル・境界」節が qa-nightmare にはない。subagent が「悪夢ケース」語に引きずられて関数単位でも発動する誤用リスク |
| QN-0-7 | Phase 3「発見困難度 × 被害度 → 積」のマトリクスで「6」の扱い | 低 | L162-167 の表で積 1, 2 = C、3, 4 = B、6 = A、9 = S と記載。積は 1×1, 1×2, 2×1, 1×3, 3×1, 2×2, 2×3, 3×2, 3×3 = 1/2/2/3/3/4/6/6/9 で計9組合せ。**5, 7, 8 はそもそも存在しない**（1,2,3 の積で作れない組合せ）。表は論理整合しているが「6 はどちら (2×3 or 3×2)」の例示はない。低重要 |
| QN-0-8 | `$ARGUMENTS` の使われ方（L10 の「対象: $ARGUMENTS」）が skill の invocation 形式に依存 | 低 | slash command として `/qa-nightmare <機能名> <URL>` 形式で発動する場合 L10 が自動埋めされるが、通常の skill invocation（例: 「qa-nightmare で悪夢テスト作って」）では空になる。L26「`$ARGUMENTS` が空の場合 → 対象機能と画面URLをユーザーに確認してから開始」でフォールバック済。問題なし、観察のみ |
| QN-0-9 | Phase 2 ステップ1「`ls ~/.claude/skills/qa-nightmare/checklists/*.md`」とトリガー条件「チェックリスト未読禁止」の実行可否 | 中 | subagent は Bash 使えるが、実際に `ls` 結果を使って 11 個すべて Read するのか、スキップ判定（例: data-io は非該当なら読まない）を許すのかが body から読めない。禁止事項 L43「チェックリスト未読でのパターン抽出」は厳格。シナリオC 焦点 |
| QN-0-10 | 出力フォーマット（L175-200）の「スキップしたパターン（理由付き）」表と「合計: XX ケース」が別々の位置 | 低 | 論理構造は正しいが、subagent が「スキップ表はランク別表の前 or 後」で迷う可能性。L192-197 で「### スキップしたパターン（理由付き）」が S/A/B/C ランクの後に配置されている |

### 📝 observer note

- qa-nightmare は「配布パッケージ評価」が必要な唯一のスキル（SKILL.md + checklists/11ファイル）。empirical-prompt-tuning 計画 L64「配布パッケージ全体（SKILL.md + `checklists/` 等）を参照対象とすること」で明示済、dispatch プロンプトで対応
- e2e-browser との双方向境界が重要。e2e-browser iter 3 の境界節では qa-nightmare 行が「悪夢ケース生成 → qa-nightmare」と明示されたが、qa-nightmare 側の逆リンクがまだない
- tdd iter 0 / iter 1 評価で「悪夢テスト」「網羅テスト」のトリガー語が曖昧と判定されていないため、description レベルの衝突は低いが body には境界節が欲しい
- Phase 1 情報不足確認ルール（L86-92）は L88 で「3項目以上 or スキーマ/権限/状態遷移が不明」と明確だが、判定粒度は subagent 実地で確認すべき
- Phase 5 の e2e-browser 連携は「`E2E_WORK` 共有 / `$E2E_WORK/fixtures/nightmare/<TC-ID>.json`」と具体的だが `<TC-ID>` と `<NM-ID>` の表記揺れが L239, L270 に残っている（禁止事項 L46 で `NM-` を強制しているが Phase 5 の例示は `TC-001`）

### 🔗 checklists/ 内での整合性（11ファイル quick review）

各 checklist の構造（パターン一覧）は統一されており、フォーマット（`### カテゴリ-NN: タイトル` + 攻撃/検証/壊れ方/嫌度）が一貫している。カテゴリID のプレフィックス:

- SC (silent-corruption) / ST (state-transition) / BH (boundary-hell) / AB (auth-bypass) / TC (timing-chaos) / DI (data-io) / ER (error-recovery) / DS (domain-specific) / UD (ui-destruction) / UO (ui-operation) / US (ui-state)

**`TC-` は timing-chaos のみ。SKILL.md L46 の禁止事項「テストケース連番IDに `TC-` を使うこと」は必要**（チェックリストの `TC-01〜TC-10` と衝突しないよう `NM-001` を強制）。ただし Phase 5 の L270 結果レポート例で `TC-001` と書かれており、これは自己矛盾 = 低重要な修正候補。

## iter 0 時点の判断

- **iter 0 での SKILL.md 修正はしない**（過去全スキル iter 0 と同じ方針）
- 乖離 QN-0-1〜10 は iter 1 の baseline 観測で実害が出るか確認してから iter 2 以降で修正判断
- 特に **QN-0-5（e2e-browser 境界の双方向化）**、**QN-0-6（関連スキル節の不在 = tdd/e2e-browser/test-coverage-guard 委譲の明文化）** が実害リスク高
- Phase 5 L270 の `TC-001` 表記揺れは軽微修正候補だが、description 整合とは別軸（禁止事項 L46 と例示矛盾）
- QN-0-9（チェックリスト未読禁止の実行粒度）はシナリオ C で実地確認

## 次アクション

- iter 1: baseline 3並列 dispatch（scenarios.md の A/B/C）
- dispatch パラメータ:
  - 新規 subagent、`claude/skills/qa-nightmare/SKILL.md` 全文 + `checklists/*.md` 11ファイルのパスを明示
  - 他スキル auto-load 禁止
  - Docker 実行不能環境での「Phase 5 は生成物提示までで停止、Phase 6 は案内のみ」指示
  - empirical-prompt-tuning「subagent 起動契約」節のレポート構造で返答させる
