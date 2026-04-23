# interface-first-design iter 0: 静的整合チェック

**実施日**: 2026-04-23
**対象**: `claude/skills/interface-first-design/SKILL.md` (276 行)
**フェーズ**: dispatch 前の静的整合チェック（description ↔ body + 直前スキル `refactoring` との重なり語）

---

## 1. description ↔ body 整合

**description (frontmatter L3)**:
> 機能追加・クラス設計・interface設計・依存関係整理・責務分割時に使用。疑似コードから interface→クラス→TDD→実装の順で設計する。TDDスキルの前段。

**body の該当要素**:

| description 要素 | body 該当箇所 | 整合 |
|---|---|:---:|
| 機能追加 | トリガー「新規クラス・モジュール設計を開始」L15 | ○ |
| クラス設計 | 同上 / Step 3 上位層での組み立て L113 | ○ |
| interface設計 | Step 2 interface への変換 L82 | ○ |
| 依存関係整理 | トリガー「依存関係の整理・リファクタリング」L17 | ○ |
| 責務分割 | トリガー「既存クラスの責務が肥大化」L16 | ○ |
| 疑似コードから interface→クラス→TDD→実装 | Step 1-4 の順序 L30-135 | ○ |
| TDDスキルの前段 | トリガー L18 + Step 4 TDDへ移行 L133 | ○ |

### 乖離・曖昧点

| ID | 箇所 | 内容 | 深刻度 |
|---|---|---|:---:|
| IFD-0-1 | description「依存関係整理」 vs refactoring description「コード構造を改善」 | 依存整理はコード構造改善と重なる。iface-first は**新規設計 / 責務分割を伴う構造変更**、refactoring は**振る舞い保証下の構造改善**と棲み分けが必要だが、iface-first の body には refactoring との境界明示がない | 🟡 中 |
| IFD-0-2 | トリガー L17「依存関係の整理・リファクタリング」 | 「リファクタリング」の語が refactoring スキルと直接衝突。ユーザーが「既存コードの依存を整理してほしい」と言ったとき、本スキル発動か refactoring スキル委譲かの判定が body からは読み取れない | 🟡 中 |
| IFD-0-3 | 禁止事項・制約 表（L141-149） | refactoring 側には「委譲先」表があり本スキルへ明示誘導（L117）、だが本スキル側には refactoring への逆方向委譲記述がない（片方向リンク） | 🟡 中 |
| IFD-0-4 | 前提条件 L22「既存実装がある場合でも、必ず疑似コードから書き直す」 | 「書き直す」が refactoring との差異を示唆するが、**振る舞いを変える・変えない**の軸が明示されていない。iface-first は構造変更を伴う（振る舞い変更あり得る）ことが body の他箇所からは明示されていない | 🟡 中 |
| IFD-0-5 | Step 4 L133-135「TDDスキルを起動」 | 「起動」の具体オペ（スキル名読み替え / 呼出表現）が未規定。TDDスキル名は `TDD` (大文字) なのか `test-driven-development` なのか不明確 | 🟢 低 |
| IFD-0-6 | 原則 L227-233 | hierarchical-architecture への参照 L147-148 と L232「徹底すれば hierarchical-architecture は自然に満たされる」が冗長だが矛盾ではない | 🟢 低 |
| IFD-0-7 | 出力形式 L237-259 | 「疑似コード」「Interface一覧」「クラス一覧」「上位層の組み立て」の 4 パート固定。しかしシナリオによっては疑似コードが長大化しそうで、長さ目安がない | 🟢 低 |
| IFD-0-8 | 設計完了チェックリスト L263-276 | 10 項目あるが、利用側が「全てクリアしたか」を表形式で埋めることを明示せず、「全てクリアしたら TDD へ」L135 という文言だけ。提示フォーマットが subagent に委ねられる | 🟢 低 |

---

## 2. 直前スキル refactoring との description 重なり

`docs/tuning-logs/trigger-overlap.md` 該当行確認:

| 重なり語 | 登場スキル | 本スキル description | refactoring description |
|---|---|---|---|
| 構造 | refactoring / consultation | **登場せず**（body には登場） | 「コード構造を改善する際に使用」で明示 |
| 設計 | consultation / interface-first-design | 「クラス設計・interface 設計」 | body に登場（L109 委譲先表）|
| 機能 | interface-first-design / tdd | 「機能追加」 | 登場せず |
| 責務 | interface-first-design | 「責務分割」 | body に登場（L117 「新規 interface 設計・新規実装」で iface-first へ委譲）|

### 境界の現状（片方向リンク）

- `refactoring/SKILL.md` L109-118「委譲先」表
  - `新規 interface 設計・新規実装 → interface-first-design`（L117）
  - `値変更・引数化・切替機能化は仕様変更（→ 委譲先表参照）`（L94）
- `interface-first-design/SKILL.md`
  - **refactoring への逆方向委譲記述なし**
  - 「振る舞い変更を伴わない構造改善はこのスキルでは扱わない」という明示なし

**判定**: iter 1 baseline で「既存クラスの責務分割」系シナリオ（シナリオB）が **iface-first 側で正しく処理されるか** / **refactoring 側に誤誘導されないか** を観察ポイントとする。

---

## 3. iter 1 観測ポイント

1. [critical] **IFD-0-1 ~ IFD-0-4**（refactoring との境界曖昧）がシナリオB（責務肥大クラス分割）で subagent 挙動に影響するか
2. シナリオA（中央値・新規設計）でも refactoring 誤委譲が起きないか
3. シナリオC（既存ORM を interface 化）で Anti-pattern 4 を名指しで引用するか
4. 出力形式 4 パート（L237-259）が自然に踏襲されるか（IFD-0-7）
5. 設計完了チェックリスト 10 項目の提示フォーマット（IFD-0-8）

---

## 4. 事前予想（iter 1 で実害化する懸念）

| ID | 実害化懸念 | 信頼度 |
|---|---|:---:|
| IFD-0-1 / IFD-0-2 / IFD-0-3 / IFD-0-4 | シナリオ B で refactoring への誤委譲 or 「本スキル対象外」の誤判定 | 🟡 中（シナリオB は「設計から見直したい」と明示しているので実害は限定的だが、subagent の判断によっては揺れる可能性） |
| IFD-0-5 | TDD スキル起動オペの揺れ（呼出表現の不統一） | 🟢 低 |
| IFD-0-7 / IFD-0-8 | 出力長の膨張 / チェックリスト提示フォーマット不統一 | 🟢 低 |

**iter 2 修正テーマの第1候補**: IFD-0-1 ~ IFD-0-4 を一括解消する「**refactoring との境界 + 逆方向委譲**」の明示。refactoring 側と同様に `## 委譲先（範囲外作業）` 節を追加し、`振る舞い保持の構造改善 → refactoring` を明記する案が最有力。ただし iter 1 baseline で実害が観察されない場合は第 2 候補（IFD-0-5 TDD スキル名規定）に切替。

---

## 5. 次アクション

iter 1: シナリオ A / B / C の 3 並列 baseline dispatch。各 subagent 起動プロンプトに以下を明記:

- 対象スキル `interface-first-design` 以外の skill を auto-load しないこと
- SKILL.md 全体を参照対象とすること
- empirical-prompt-tuning「subagent 起動契約」節のレポート構造で返答すること（成功 / 精度 / steps / duration / 不明瞭点 / 裁量補完 / 隣接スキル混同の兆候）
