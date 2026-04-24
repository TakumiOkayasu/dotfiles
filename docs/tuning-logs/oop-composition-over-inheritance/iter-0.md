# iter 0: oop-composition-over-inheritance 自己完結性・重複チェック

## 目的

対象 rule 本文 (`claude/rules/oop-composition-over-inheritance.md`, 73 行) を精読し、隣接 rule / skill との重複・境界の曖昧さ・自己完結性の欠落を抽出する。baseline dispatch 前に「修正候補」を仮説として整理しておき、iter 1 の観察結果と照合する。

## 調査対象

- 対象: `claude/rules/oop-composition-over-inheritance.md` (全 73 行)
- 隣接 rule:
  - `claude/rules/hierarchical-architecture.md` (128 行): レイヤー依存方向・DI・命名
  - `claude/rules/coding-conventions.md` (280 行+): L215-221 SOLID 5 原則、L225 DRY/KISS/YAGNI
- 隣接 skill:
  - `claude/skills/interface-first-design/SKILL.md`: 疑似コード → interface → クラス → TDD
  - `claude/skills/refactoring/SKILL.md`: 振る舞いを変えない構造改善

## 抽出した候補 (OOP-0-1 〜 OOP-0-8)

| ID | 種別 | 対応範囲 | 概要 |
|----|------|----------|------|
| OOP-0-1 | 重複 | 対 coding-conventions L215-221 (SOLID) | 「依存性逆転」「単一責任」「開放閉鎖」が OOP rule の「インターフェースに依存」「責務の不明確さ」「既存コードの変更が必要」と重なる。どちらが優先かの指針なし |
| OOP-0-2 | 重複 | 対 hierarchical-architecture L69-90 (合成・拡張節) | HA に「合成 > 継承。深い継承禁止。コンストラクタ注入で合成」「DI: インターフェースに依存」が既にある。OOP rule の「実装のポイント」(L42-52) とほぼ同文 |
| OOP-0-3 | 自己完結性 | L17-28 「悪い設計の兆候」 | SOLID の開放閉鎖・単一責任違反を言い換えているが、どの SOLID 項に対応するかの明示がない。読者が原則との対応を追えない |
| OOP-0-4 | 冗長 | L54-68 「適用範囲」+「具体例の参照」 | 両節とも環境別 (組み込み/Web/Backend) の列挙だが、参照先 (「各環境での具体的な実装例は以下を参照」) が明示されていない |
| **OOP-0-5** | **欠落 (最有力)** | 全体 | **「合成 > 継承」を強調するが、継承が適切な場面 (is-a 関係・フレームワーク制約・テンプレートメソッド等) の許容条件が未記述**。保守的すぎる subagent が「継承禁止」と誤発動する危険 |
| OOP-0-6 | 曖昧 | L73 「深い継承禁止」 | 「深い」の定義なし (1 段継承は OK か、2 段 NG か) |
| OOP-0-7 | 定量目安欠落 | L38 「インターフェースは薄く保つ(必要最小限のメソッドのみ)」 | メソッド数の目安なし。判断ツールとして弱い |
| OOP-0-8 | 判定基準曖昧 | L72 (HA 側) / OOP rule は言及なし | 「パラメータ化 vs サブクラス化」の境界はここでは触れていないが、scenarios B (ストラテジ増殖) で subagent が迷う可能性あり |

## 最有力候補の選定 (iter 2 での修正想定)

**OOP-0-5 (継承許容条件の欠落) を最優先候補とする**。理由:

- ユーザー視点での誤発動影響が最大: subagent が「継承一切禁止」と断じると、実用的な設計 (抽象基底クラスでのテンプレートメソッド / フレームワーク要求の継承 / 値オブジェクト階層) を全否定してしまう
- rule 本文に 1-2 行追記するだけで対応可能 (直前 implementation-policy L28 と同じ形式の追記)
- scenarios.md の `C (edge): フレームワーク制約下での継承許容判定` で観察可能

### 想定追記位置と内容 (仮)

L73 付近 (「合成 > 継承」表記の直後か、実装のポイント節末尾) に次を追加:

> **継承が適切な場面**: is-a 関係が明確 (`Dog extends Animal`) / フレームワーク制約 (React `Component`, Android `Activity` 等) / テンプレートメソッドで意図的に手順を固定したい場合は継承を採用してよい。ただし継承深度は **2 段まで**を目安とし、それ以上は合成を検討する。

(iter 1 baseline で C シナリオの subagent 判断を観察してから最終形を決定)

## 次点候補

- **OOP-0-2 (HA 重複)**: scenarios.md の「隣接 rule / skill との境界」表で明示すれば subagent は誤発動しない見込み。本文修正は保留
- **OOP-0-6 (深い継承の定量)**: OOP-0-5 と同時に「2 段まで」等で対応可能。OOP-0-5 にまとめる

## iter 1 前の態度

- iter 1 baseline では**修正なしのまま現行 rule 本文で 3 並列評価**し、OOP-0-5 の発現有無を観察する
- 全 pass なら修正を先送り、fail / 不明瞭点が発生したら iter 2 で OOP-0-5 対応

## 次アクション

1. scenarios.md を作成 (A 中央値 / B edge ストラテジ増殖 / C edge 継承許容境界 / D hold-out 単純 DTO)
2. iter 1 baseline: 3 並列 subagent dispatch
3. 観察結果を iter-1.md に記録し、OOP-0-5 の顕在化有無を判定
