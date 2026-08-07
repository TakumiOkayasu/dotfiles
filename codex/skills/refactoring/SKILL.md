---
# codex_port_source: common/skills/refactoring/SKILL.md
name: refactoring
description: 振る舞いを変えずにコード構造を改善する際に使用。「リファクタ」「整理して」「きれいにして」「重複を消す」「関数を分割」で発動。
---

# Refactoring

<!-- codex-port: managed; source=common/skills/refactoring/SKILL.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/skills/refactoring/SKILL.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

## トリガー条件

以下のいずれかに該当するとき発動する:

- ユーザーが「リファクタリング」「リファクタ」「構造改善」「整理」と指示したとき
- コードスメルの解消を依頼されたとき（長いメソッド、重複コード、マジックナンバー等）
- PR/レビュー指摘の「設計改善」対応を依頼されたとき
- 機能追加前の「下準備」として構造整理を依頼されたとき

## 前提条件

| 条件 | 内容 |
| ------ | ------ |
| ✅ 必須 | テストが存在し、全てパスしていること |
| ✅ 必須 | 変更対象コードの動作を理解していること |
| ❌ 実施禁止 | デッドライン直前 |
| ❌ 実施禁止 | テストがない状態 |
| ❌ 実施禁止 | 動作を理解していない状態 |

## 方針検証スキル連携 (premise-questioning)

リファクタが以下のいずれかに該当する場合、フェーズ1 の前に **`premise-questioning` skill を起動**し、✅ 採用判定が出るまでフェーズ2 へ進まない:

- 100 行以上の変更見込み
- レイヤー構造 / アーキテクチャの再編 (モジュール境界・依存方向の変更)
- 外部依存 (ライブラリ / フレームワーク) の差し替え
- 公開 API I/F の変更を伴う (= 振る舞いを変えない範囲を超える可能性あり → 委譲先要検討)

該当しない局所リファクタ (1 関数の抽出 / マジックナンバーの定数化等) はスキップ可。スキップ時は `premise-questioning: skipped (理由: 局所リファクタ)` を 1 行明示する。

`feature-pruning` は本 skill の対象外 (機能削減は振る舞い変更に該当 → 「委譲先」表参照)。

## 鉄則

**テストがある状態で始める。振る舞いは変えない。**

## 手順

```
フェーズ1: 安全確認
  1. テストを全て実行し、全PASSを確認
  2. 変更スコープを宣言（どのファイル/関数を対象とするか）

フェーズ2: スメル特定
  3. 対象コードのコードスメルを列挙する
  4. 優先度順に並べる（影響範囲小・リスク低 → 先に着手）

フェーズ3: 小さく変更
  5. 1つのスメルに絞って変更する
  6. 無関係なコードには触れない
  7. テストを実行し、全PASSを確認

フェーズ4: 繰り返し
  8. フェーズ3を繰り返す（1変更 = 1テスト実行）

フェーズ5: 完了確認
  9. 全テストPASSを確認
  10. 変更前後でインターフェース（入出力・シグネチャ）が同一であることを確認
```

1 コミット = 1 つのスメル変更に分割する。無関係なコード・スコープ外への変更を混ぜない。

## コードスメル

### 長いメソッド → 抽出

```typescript
// ❌
function processOrder() { /* 100行 */ }

// ✅
function processOrder() {
  validate();
  calculate();
  save();
}
```

### 条件分岐 → ポリモーフィズム

```typescript
// ❌
if (type === 'a') { ... } else if (type === 'b') { ... }

// ✅
interface Handler { handle(): void }
class HandlerA implements Handler {}
class HandlerB implements Handler {}
```

### マジックナンバー → 定数

```typescript
// ❌
if (speed > 9.8)

// ✅
const GRAVITY = 9.8;
if (speed > GRAVITY)
```

**境界**: 値を据え置いたままの定数化は構造改善（本スキル対象）。値変更・引数化・切替機能化は仕様変更（→ 委譲先表参照）。

## アンチパターン

| 禁止 | 理由 |
| ------ | ------ |
| 振る舞いの変更 | リファクタリングの定義違反 |
| テストなしで進める | デグレ検出不能 |
| 複数スメルを同時に変更 | 失敗時の原因特定が困難 |
| 無関係なコードへの変更 | スコープ外は別PRで対応 |
| 既存エラーハンドリング・エッジケースの削除 | 暗黙の仕様が消失する |
| 過度な圧縮・巧妙化 | 可読性損失（明示的なコード > 短いコード） |
| 1回しか呼ばれない3行処理の関数化 | 抽出コストがメリットを上回る |
| ロジックの意味が変わる早期return | 振る舞い変更に該当 |

## 委譲先（範囲外作業）

依頼内に以下が混在する場合、本スキルでは扱わず該当スキルに委譲する。委譲時は「本スキルの対象外」を明示してから委譲先を提案する。

| 範囲外作業 | 委譲先スキル |
| --- | --- |
| テスト新規作成・特性テスト追加（前提条件未充足時） | tdd |
| バグ修正・原因分析（振る舞い変更を伴う） | systematic-debugging → tdd |
| 新規 interface 設計・新規実装 | interface-first-design |
| 既存テストの信頼性検証 | test-coverage-guard |

## Maintain Balance（過剰な簡略化の防止）

- 「動いているが汚い」と「壊れる可能性がある変更」なら、前者を残す
- ネストを減らす早期returnは可。ただしロジックの意味が変わる変形は禁止

## 出力形式

リファクタリング完了後に以下を報告する:

```
## リファクタリング結果

### 変更内容
- [スメル名]: [変更前の構造] → [変更後の構造]

### テスト結果
- 変更前: [PASS数]
- 変更後: [PASS数]

### 振る舞い保証
- インターフェース変更: なし / あり（要確認 [要確認]）
```
