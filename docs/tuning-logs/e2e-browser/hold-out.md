# hold-out — e2e-browser（シナリオD: 誤発動回避）

## 対象
ユニットテスト領域（`formatPrice` 純粋関数）への誤発動回避シナリオ。

## 結果

| 指標 | 値 |
|---|---|
| 成功/失敗 | ○ |
| 精度 | 5/5 = **100%** |
| tool_uses | 2 |
| duration | 50.1s |
| retries | 0 |

## 要件達成

| # | 判定 | 実地観察 |
|---|:---:|---|
| 1 e2e-browser 不発動 | ○ | トリガー1-5 全 × を表で個別判定、前提「テスト対象アプリ起動」不成立で離脱 |
| 2 tdd 委譲 + RED-GREEN-REFACTOR | ○ | 主=tdd、副=qa-nightmare を誘導先に明示、RED例+GREEN指針（`Intl.NumberFormat`）+ REFACTOR 予告 |
| 3 発動判断根拠明示 | ○ | トリガー5項目の個別判定表で構造化、**新設の「関連スキル・境界」節「純粋関数のユニットテスト → tdd」を直接引用** |
| 4 qa-nightmare 想定外入力案内 | ○ | 6カテゴリ（負数/NaN/境界値/浮動小数/未知currency/通貨別小数桁）を列挙 |
| 5 境界判断明示 | ○ | I/O有無 / ブラウザ必要性 / DB検証 / スクショ証跡 の4観点テーブルで「e2e-browser は過剰」を明文化 |

## overfit 判定

- **baseline 平均 (iter 4): 98.3% → hold-out: 100% = +1.7pt**
- -15pt 基準に遠く及ばず、**overfit なし**
- 境界節追加（iter 3）の hold-out でも直接引用が発生 → 境界明文化が**誤発動阻止コストを下げる**（refactoring / iface-first / consultation の hold-out と同パターン）

## 観察ポイント

- **早期離脱**: duration 50.1s（iter 4 平均 49.3s）で Phase 0-5 フェーズ手順を完走せず、非対象判定で終了
- **境界節の直接引用**: 「関連スキル・境界表」の `tdd` 行を文字通り引用 = iter 3 の修正がそのまま hold-out で機能
- **裁量補完の精度**: `Intl.NumberFormat` を implementation-policy「車輪の再発明禁止」類推で選定、coding-conventions のテスト命名も遵守 = auto-load 禁止下でも rules 精神は発揮

## 残存不明瞭点

- D-1: 「qa-nightmare 想定外入力列挙の提示」vs「qa-nightmare 発動推奨」の粒度（subagent は前者で妥当）
- D-2: 「tdd 委譲または RED-GREEN-REFACTOR 提示」の or 解釈（subagent は両方提示）
- D-3: 「他スキル auto-load 禁止」と「tdd 委譲」の表面的矛盾（subagent は「tdd SKILL.md 本体を読まず入口提示」で正解運用）

すべて周辺運用詳細。中核（トリガー非該当判定 + 境界節引用 + 誘導先提示）は安定。

## 収束判定

- **e2e-browser スキル収束完了** ✅
- 連続 2/2 達成（iter 3-4）+ hold-out パス
- 典型スキル目標（連続2 + hold-out パス）達成
