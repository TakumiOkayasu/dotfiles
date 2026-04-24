# implementation-policy iter 2: L28 scope 明記 + 3 並列再評価

**実施日**: 2026-04-24
**rule 変更**: `claude/rules/implementation-policy.md` L28 (必須経由表 / ロギング行) に scope 明記

## 変更内容 (diff)

```diff
-| **ロギング** | ロギングライブラリ経由。`print` / `console.log` / `echo` の直接使用禁止 |
+| **ロギング** | 本番コードはロギングライブラリ経由 (`print` / `console.log` / `echo` の直接使用禁止)。個人ワンショット/使い捨てスクリプトは対象外 |
```

**狙い**: L55 禁止事項表の括弧書き「(本番コード)」と L28 必須経由表の scope を整合させ、iter 0 で特定した **IP-0-1** を解消。hold-out D (個人ワンショットスクリプト) での誤発動を構造的に予防。

## 実行結果 (シナリオ別)

| シナリオ | 成功/失敗 | 精度 | 自己申告 retries |
|---|:---:|:---:|:---:|
| A (HTTP retry + loguru) | ○ | 6/6 = 100% | 0 |
| B (月次集計 / 生 SQL 境界) | ○ | 5/5 = 100% | 0 |
| C (パスワードリセットトークン) | ○ | 5/5 = 100% | 0 |
| **合計** | **○** | **100%** | **0** |

*(subagent 全員 Read 1 回のみで自己完結、retries 0。)*

全 [critical] 達成。各 subagent の成果物 (iter 1 比):

- **A**: `ExternalAPIClient` クラス設計 (iter 1 は関数ベース)、`status_forcelist` に 408 追加、logging は全エラー系列で構造化
- **B**: Step 1-3 の判定プロセスを明示列挙 (ORM 困難性 → 許可シナリオ判定 → 読み取り専用確認)、CTE を 3 段 (`monthly_orders` / `user_totals` / `ranked_users`) + `percentage_of_total` 追加、PR 本文を疑似コードで例示
- **C**: `generate_reset_token()` / `save_reset_token()` / `verify_reset_token()` / `complete_password_reset()` の 4 関数分離、SQLAlchemy モデル定義例示 (Index 付与)

## 不明瞭点 (今回新出)

**A / C は「なし」と回答**、**B は 1 件**:

### IP-2-B-1: 使用例の ORM が Django (L70 `User.objects.create()`)、シナリオは SQLAlchemy

subagent B: 「rule L62-73 の使用例では `User.objects.create()` = Django ORM 想定。しかしシナリオで SQLAlchemy 採用を明言したため、Django / SQLAlchemy 混在ルールが rule に明記なし」

- **影響度**: 低。critical 項目に影響せず、B は 5/5 で ○
- **残置可否**: 残置で問題なし。「定評 ORM を使う」方針は Python エコシステム全般に適用でき、特定ライブラリを明示する必要性は薄い

## 裁量補完 (今回新出、iter 1 との差分観察)

- **A**: `status_forcelist` に 408 (Request Timeout) 追加 (iter 1 は 429/5xx のみ)、PATCH を `allowed_methods` に含めた (冪等性議論) — iter 1 と傾向は同じ (詳細パラメータの自裁量)
- **B**: CTE 3 段構造 + `percentage_of_total` カラム追加 (iter 1 は 2 段)、PR 本文を疑似コードで例示、`EXTRACT` / `DATE_TRUNC` の方言対応コメント — iter 1 より丁寧
- **C**: 4 関数分離設計 (iter 1 は 1 クラス内メソッド)、`expires_at` にインデックス付与、base64.urlsafe_b64encode 明示 (iter 1 は token_urlsafe で内部処理) — iter 1 と等価だが粒度が細かい

**iter 1 との一貫性**: 全 subagent が本番向けコード文脈で同じ判断 (既採用ライブラリ優先 / プリペアド / ORM / 外部化) を独立に再現。rule の自己完結性は高い。

## 分析

### 収束条件の達成

- iter 1: baseline 3/3 pass (修正なし)
- iter 2: baseline 3/3 pass (L28 修正後)
- **連続 2 回目達成 ✅** (典型 rule 目標)

### iter 2 修正の波及

修正した L28 の効果を subagent B が直接引用:
> 「**ロギング実装**: ポリシー第28行『本番コードはロギングライブラリ経由』に従い、`logger.info()` を CSV 出力時のログとして追加」

修正文言が subagent 読解に確実に届いていることを確認。本番コード文脈 (A/B/C) ではロギング必須が維持され、精度を落とさない。hold-out D での誤発動予防効果は次 iter で検証。

### tool_uses 相対観察

iter 1 と同様、全 subagent Read 1 回のみで自己完結。シナリオ間ばらつきなし。構造的欠陥なし。

## iter 3 方針

**baseline 収束確定。hold-out D 評価へ進む。**

- 追加修正は入れない (連続 2 回目で収束、追加 iter は過剰チューニングのリスク)
- hold-out D を 1 回 dispatch し、IP-0-1 修正の狙い (個人ワンショットスクリプト での過剰適用回避) を検証
- D pass なら最終収束、fail なら IP-0-1 再修正 or 別候補 (L29 バリデーション scope など) 検討

## 次アクション

- [x] iter-2.md 作成
- [x] baseline 連続 2 回 pass 達成
- [ ] iter 3 (hold-out D) 評価
- [ ] hold-out.md に結果記録
- [ ] PROGRESS.md 更新 + ユーザー commit 依頼
