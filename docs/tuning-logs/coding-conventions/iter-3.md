# coding-conventions iter 3: L208-209 React 例外境界明記 → 3 並列再評価

**実施日**: 2026-04-24
**rule 変更**: L208-209 命名例外節に 1 行追記 (React 例外のイベント受信限定の判定)

## 修正内容

**修正前 (L208-209)**:
```
**例外**:
- フレームワーク規約 (例: React の `handleClick` イベントハンドラ慣例) は従う。ビジネスロジック側では具体名を用いる。
```

**修正後 (L208-209)**:
```
**例外**:
- フレームワーク規約 (例: React の `handleClick` イベントハンドラ慣例) は従う。ビジネスロジック側では具体名を用いる。**判定**: フレームワーク規約適用は「イベント (DOM/フォーム/コンポーネント props 経由) を直接受信する関数」に限る。受信内から呼ぶ業務関数は具体名 (例: `handleDeleteUser` は `deleteUser` を内部で呼ぶ形に分離)。
```

## 実行結果 (シナリオ別)

| シナリオ | 成功/失敗 | 精度 | tool_uses | duration | retries |
|---|:---:|:---:|:---:|---:|:---:|
| A (複合違反) | ○ | 9/9 (critical 5/5) | 1 | 28.6s | 0 |
| B (React 命名例外) | ○ | 6/6 (critical 3/3) | 1 | 26.9s | 0 |
| C (async+error+log) | ○ | 8/8 (critical 5/5) | 1 | 33.3s | 0 |
| **平均** | **○** | **100% critical** | **1** | **29.6s** | **0** |

全 [critical] 達成、tool_uses 全 1、duration iter 2 比 +2% (誤差範囲)。

## **連続 3/3 達成** ✅

| iter | 精度 | critical | duration 平均 |
|---|:---:|:---:|---:|
| iter 1 (baseline) | 100% | ○/○/○ | 34.0s |
| iter 2 (L149 追記) | 100% | ○/○/○ | 29.0s |
| iter 3 (L209 追記) | 100% | ○/○/○ | 29.6s |

重要 rule 目標 (連続 3) クリア。

## CC-1-B-1 解消確認 (iter 3 テーマ)

シナリオ B subagent が**新文言を直接引用**:

> 非 React vs React の区別基準を L209 から引用: 「**イベント (DOM/フォーム/コンポーネント props 経由) を直接受信する関数**」を引用

さらに運用ガイダンスとして:

> `handleSubmit`/`handleClick` 内で業務処理を直接書いている場合は、内部で `deleteUser` 等の具体名関数を呼ぶ形に分離 (L209 の `handleDeleteUser` → `deleteUser` パターン)

iter 1/iter 2 では「DOM イベント受信関数に限定と解釈した」「コンポーネント内ローカル関数全般か断言されていない」と**裁量補完**だったが、iter 3 では新文言を根拠に**確定判断**に転換。CC-1-B-1 が構造的に解消。

## 不明瞭点 (今回新出 / 再出)

### CC-3-A-1: L106 未取得 vs 空結果 (CC-2-A-1 再出、hold-out 対象外)

subagent A: 「`MAX_ITEMS` 超過時のビジネス要件 (空返しか例外かログか) は不明のため仕様コメントで保留」

3 iter 連続で浮上するが、critical 違反ではなく「実仕様が不明な場合の裁量」範囲。rule 本文の修正は次サイクルで検討候補 (本 rule では hold-out に進む)。

### CC-3-B-1: `src/handlers/` ディレクトリ名自体 (軽微、新出)

subagent B: 「`src/handlers/` というディレクトリ名自体が汎用接頭辞に相当する可能性 (例: `src/orders/`, `src/payments/` 等ドメイン別が望ましい)」

命名規則の応用範囲。ディレクトリ名まで適用するかの判断は裁量、critical 非該当。

### CC-3-C-1: `logger` のインポート元 (軽微、新出)

subagent C: 「プロジェクト標準ロガーのインポート元不明」→ `[要確認]` 等で明示せず「既存前提」で進めた。

## 裁量補完 (今回新出)

- subagent A: 関数名 `parseData` → `filterTypeAItems` 改名 (責務一致、rule 違反指摘ではなく「動作に沿った具体化」と自己評価)
- subagent B: ディレクトリ名論点の付随提示 (スコープ外として指摘せず記録)
- subagent C: `users[0]?.id` optional chain 防御 (L105 準拠)

## 分析

### 3 iter を通した rule 進化

| iter | 修正 | 解消された裁量補完 |
|---|---|---|
| iter 2 | L149 try/catch 判定基準 | シナリオ C「低レイヤ同期処理と推定」→「文脈付与で捕捉」と構造化 |
| iter 3 | L209 React 例外境界 | シナリオ B「DOM イベント受信と解釈」→「イベント受信限定」と明記引用 |

裁量コスト削減の累積効果で duration が iter 1 比 -13%。tool_uses は全 iter で 1 のまま (自己完結性が最初から高い)。

### 残存不明瞭点

- CC-3-A-1 (L106 null 許容): 3 iter 連続浮上、critical 非該当で判断保留可能
- CC-3-B-1 (ディレクトリ名): 命名規則応用、スコープ境界
- CC-3-C-1 (logger import): プロジェクト文脈依存

いずれも critical 達成に影響せず。本 rule では連続 3 達成済のため **hold-out D へ進む**。

## 次アクション

- [x] iter-3.md 作成
- [ ] hold-out D: 既に rule 準拠の小関数への過剰修正回避
- [ ] hold-out.md に結果記録
- [ ] 完了報告 → PROGRESS.md 更新 → ユーザー commit/PR 依頼
