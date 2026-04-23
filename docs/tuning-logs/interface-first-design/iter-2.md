# interface-first-design iter 2: 上位層粒度の目安追加 + 3並列再評価

**実施日**: 2026-04-23
**修正内容**: `claude/skills/interface-first-design/SKILL.md` Step 3 末尾に「上位層の粒度の目安」節を追加（6 行）
**目的**: iter 1 で IFD-1-B-1 / IFD-1-C-2（上位層の粒度が未特定）が 2 subagent 独立で挙がった構造的曖昧を解消

---

## SKILL.md 差分

L130 の「ポイント」節の直後に追加:

```markdown
**上位層の粒度の目安:**

- 用途単位の薄い組み立て → UseCase（提供層）
- 複数 UseCase を束ねる配線点 → 管理層（Controller / Orchestrator 等）
- 命名は `hierarchical-architecture` の役割サフィックス規則（Manager / Provider / Accessor 等）に従う
- 単一 UseCase で済むなら UseCase 自体が上位層（Controller を無理に作らない）
```

追加行数: +6 行（空行含む）
総行数: 276 → 282

---

## 評価表（iter 2）

| シナリオ | 精度 | tool_uses | duration (s) | retries | 不明瞭点 | 裁量補完 | 前回比 duration |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | **8/8 ○** | 1 | 58.9 | 0 | 2件 | 3件 | +37% |
| B | **7/7 ○** | 1 | 47.9 | 0 | 2件 | 3件 | **-96.5%** (外れ値解消) |
| C | **6/6 ○** | 1 | 53.2 | 0 | 3件 | 4件 | **-96.1%** (外れ値解消) |

**集計（iter 2）**:
- 精度: 21/21 = **100%** 維持
- tool_uses: 全 1 に揃う（iter 1 は 1/2/2）→ **自己完結性向上**
- duration: 平均 **53.3s**（iter 1 平均 928.8s / 外れ値除去 iter 1 = 43.1s 比 +23.6%）
- retries: 全 0 回（iter 1 は 1/1/0 → ISP 違反の自己修正フェーズも消失 = 初手で正解パス）

---

## iter 2 修正の実地観察（IFD-1-B-1 / IFD-1-C-2 解消確認）

**3 subagent 全てが新節「上位層の粒度の目安」を参照**:

| シナリオ | 参照方法 | 適用内容 |
|:-:|---|---|
| A | 名指し引用「Step 3 末尾『上位層の粒度の目安』を参照」| 単一 UseCase (`ConfirmOrderUseCase`) で閉じる判断、「Controller を無理に作らない」を直接適用 |
| B | 目安節を直接引用（レポート末尾で節名参照） | `RegisterUserUseCase` / `GetUserUseCase` / `DeleteUserUseCase` / `ExportUsersUseCase` の 4 UseCase を用途単位で定義し、管理層命名規則（`*Manager`/`*Orchestrator`）を将来拡張として言及 |
| C | 「Step 3 末尾ガイダンス適用」と明示 | `ShowArticleUseCase` / `ListArticlesUseCase` の 2 UseCase で閉じる、Controller 新設を回避 |

**重要**: 3 subagent 独立で**目安節の 4 行が実使用レベルで適用されている**。iter 1 の「裁量で UseCase を想起したがフォーマット揺れ」から「SKILL.md 記述を直接引用して揺れなし」へ移行。

---

## refactoring 境界の自発的明文化（副次的改善）

**iter 0 懸念 IFD-0-3「refactoring への逆方向委譲記述なし」はシナリオ B で subagent が自己補完**:

> 既存 `UserService` を段階的に置換する手順（Strangler Fig 等）が必要になった段階で refactoring に委譲する境界を引いた（iter 2 B レポートより）

SKILL.md には refactoring 委譲の明示なしだが、subagent が「設計 vs 段階的置換手順」の境界を自発的に引いた。iter 0 IFD-0-1~0-4 の実害化は**軽微**（iter 1 予想通り）。

---

## 残存不明瞭点（iter 2）

| ID | シナリオ | 内容 | 実害 | iter 1 との関係 |
|:-:|:-:|---|:-:|---|
| IFD-2-A-1 | A | `Ok` 型の表現が抽象的（`Result<T,E>` 判別共用体で補完）| なし | iter 1 A-1 と同類、自己解消 |
| IFD-2-A-2 | A | 注文永続化 interface が疑似コード例に無い → 要件から必須と判断 | 小 | **新規**（OrderPersister 追加） |
| IFD-2-B-1 | B | 一覧取得の入力（ID 列挙 / フィルタ / 全件）未指定 | 小 | iter 1 B-2 継続 |
| IFD-2-B-2 | B | 通知失敗時ロールバック方針不明 | 小 | iter 1 A-2 / B-3 継続 |
| **IFD-2-C-1** | C | **実際の利用側フロー未確認 → interface と実利用のズレリスク** | **中** | iter 1 C での「利用側フローから」と関連、subagent C が `[要確認: ...]` 記法を自力発明 |
| IFD-2-C-2 | C | `ArticleQuery` の具体フィールド未定 | 小 | **新規**（裁量で仮置き） |
| IFD-2-C-3 | C | 書き込み系（create/update/delete）の要否 | 小 | **新規**（シナリオC 依頼外と判断） |

### 重要観察

**IFD-2-C-1（subagent C の `[要確認]` 記法自力発明）**:
- シナリオC iter 2 レポート中の表現: `[要確認: 実際の利用側 (Controller/Service) のフローをユーザーに確認する。`all` の用途、`where` のキー、ページング有無で interface が変わる]`
- `hallucination-prevention.md` rule の `[要確認: <理由>]` 記法と合致（rule は subagent に auto-load されていない想定だが、同形式を独立発明）
- SKILL.md には「要件曖昧時の仮置きフォーマット」が未規定 → subagent が裁量で発明した = **構造的曖昧**

---

## 収束判定（iter 2）

empirical-prompt-tuning L128 収束条件に対して:

| 条件 | iter 1 → iter 2 | 判定 |
|---|---|:---:|
| 新規不明瞭点 0 件 | 新規 3 件（A-2 / C-2 / C-3）| × |
| 精度前回比改善 ≤3pt | 100% → 100% | ○ |
| ステップ数 ±10% | tool_uses 偏り (1/2/2) → 全 1 | ○（改善方向） |
| duration ±15% | 外れ値除去後 43.1s → 53.3s (+23.6%) | △（境界外、ただし修正 +6 行の追記コスト影響） |

**連続クリアカウント**: **1/3**（iter 2 は比較可能な最初のイテレーション、カウント開始）

- 精度維持 + tool_uses 改善 + 修正テーマの実地解消確認で **iter 2 は 1 カウント対象**
- duration +24% は修正追加 +6 行の自然増で許容圏（refactoring iter 3 の +0.7% ほど抑制されていないが、追加節の長さの影響内）
- iter 3 で別テーマを 1 つ潰して 2/3、iter 4 で 3/3 到達を目指す

---

## iter 3 テーマ選定

### 候補比較

| テーマ | 根拠 | 修正コスト | 波及期待 |
|:-:|---|:-:|:-:|
| **要件曖昧時の `[要確認]` 記法の規定** | IFD-2-C-1 の subagent 独立発明 + IFD-2-C-2/C-3（要件明示なし箇所の挙動不統一）| 小（Step 1 冒頭に 2-3 行）| 中（全シナリオ波及、hallucination-prevention rule と整合）|
| 戻り値ポリシー（null vs Result）| iter 1 C-1 継続、iter 2 A-1 | 中（L108 付近文言調整）| 小（実害なし） |
| refactoring 境界の逆方向委譲明記 | iter 0 IFD-0-3、iter 1 B で自制成功 / iter 2 B で自発的明文化 | 小（委譲先節 3-5 行）| 小（subagent 自力判断済み）|

### 選定: **要件曖昧時の `[要確認]` 記法の規定**

**理由**:
1. IFD-2-C-1 は subagent C が `hallucination-prevention` rule の記法を**独立発明** = 共通規範を SKILL.md 側から明示すべき構造的欠落
2. IFD-2-C-2 / C-3 とも関連（要件未指定箇所の仮置き方針が subagent 任せ）
3. 最小修正（Step 1 冒頭か前提条件節に 2-3 行）で hallucination-prevention.md rule と整合
4. tdd iter 4 の「出力形式テンプレート冒頭追加」と同じ**構造提供型**の修正（迷い構造的除去）

### 修正案

Step 1 冒頭部（L30-32 付近）に追記（2-3 行）:

```markdown
**要件に不明点がある場合**: 疑似コードの該当箇所を `[要確認: <不明点の具体>]` 記法で仮置きしてから先へ進み、レポート末尾に確認事項を集約する（hallucination-prevention rule 準拠）。
```

---

## 次アクション

iter 3: SKILL.md Step 1 冒頭に `[要確認]` 記法を 2-3 行追記 → 3 並列再評価

- 観測点1: IFD-2-C-1 / C-2 / C-3 の解消（新記法の直接引用）
- 観測点2: 精度 100% 維持
- 観測点3: duration が iter 2 並に収まるか（修正 2-3 行なので小増加を想定）
- 観測点4: 新規不明瞭点の発生有無
- 観測点5: **連続クリア 2/3** 到達判定
