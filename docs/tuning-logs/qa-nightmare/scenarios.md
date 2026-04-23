# qa-nightmare シナリオカタログ

empirical-prompt-tuning でチューニングするための評価シナリオ。**iter 開始後は変更しない**。

- 対象スキル: `claude/skills/qa-nightmare/SKILL.md` + `claude/skills/qa-nightmare/checklists/*.md`（11ファイル）
- description: 「QAベテランが嫌がる悪夢テストケースを生成し、e2e-browserで自動実行する。11カテゴリ109パターンの網羅的チェックリストから対象機能に適用可能なケースを抽出・ランク付け。」
- 収束目標: **連続2** イテレーション（典型スキル）

## 隣接スキルとの境界（iter 0 整合確認の焦点）

| スキル | 対比 |
|---|---|
| e2e-browser | e2e-browser = **実行基盤**（Docker内 Playwright）、qa-nightmare = **悪夢ケース生成**（11カテゴリから抽出・ランク付け）。qa-nightmare Phase 5 から e2e-browser 形式で連携 |
| tdd | tdd = ユニットテスト RED-GREEN-REFACTOR（関数単位）、qa-nightmare = edge ケース網羅（機能単位）。qa-nightmare L25 で「ユニットテストのみの依頼 → TDDスキル」と明示済 |
| test-coverage-guard | test-coverage-guard = 既存テストの偽陽性検出、qa-nightmare = 新規悪夢ケース生成。時系列が別（test-coverage-guard は GREEN後、qa-nightmare は設計段階） |
| systematic-debugging | sd = バグ再現時の4フェーズ根本分析、qa-nightmare = **障害の予防的列挙**。sd は発生後、qa-nightmare は発生前 |
| consultation | consultation = 技術選定/設計相談、qa-nightmare = テスト網羅。consultation は判断、qa-nightmare は列挙 |

## Baseline シナリオ

### シナリオA（中央値: ユーザー登録画面の悪夢テスト生成、スキーマ情報ほぼ提供済）

**状況**:
ユーザー「ユーザー登録画面の悪夢テストを生成して。

- URL: http://host.docker.internal:8080/signup
- 操作: email / password / password_confirm / display_name / 利用規約同意チェック → 「登録」ボタン
- 期待: 確認メール送信 → `/signup/complete` にリダイレクト
- DB: PostgreSQL、テストDB名 `app_e2e`
  - `users` テーブル: id (serial), email (unique, not null), password_hash (not null), display_name (nullable), is_active (bool, default true), email_verified_at (nullable), created_at
  - `email_verifications` テーブル: id, user_id (FK users.id), token (unique), expires_at, used_at (nullable)
  - `users` と `email_verifications` は 1:N
- 権限モデル: 未ログイン状態での操作のみ、ロール区別なし
- 状態遷移: users.email_verified_at=NULL（未認証）→ NOT NULL（認証済）。認証は別画面 `/verify?token=xxx`
- ビジネスルール: 同一emailでの重複登録不可、password は bcrypt ハッシュ保存、display_name は任意
- 既存コードから読み取れるもの: email validation は RFC5322、password は最低8文字+英数混在

ランク S+A+B まで実施候補として挙げて」

**要件チェックリスト**:
1. [critical] **qa-nightmare スキルを発動し、Phase 1-3 を順守**（Phase 1 機能分析 → Phase 2 チェックリスト適用 → Phase 3 ランク付け）
2. [critical] **連番IDに `NM-` プレフィックスを使う**（SKILL.md L46, L173「`TC-` は timing-chaos カテゴリIDと衝突」）
3. [critical] **S ランクは必ず実施対象として挙げ、ユーザー判断なしに除外しない**（SKILL.md L45）
4. Phase 1 で把握情報（画面構成/CRUD/入力フィールド/状態遷移/権限モデル/外部連携/ビジネスルール）を箇条書きで整理する（SKILL.md L94-102）
5. 11カテゴリすべてに目を通し、スキップしたカテゴリは理由付きで明示する（SKILL.md L193-197 の「スキップ記載ルール」、全パターンスキップは「XX-01〜XX-NN」とまとめて1行）
6. 嫌度評価で「発見困難度 × 被害度 = 積 → ランク」を 1 行で示す（SKILL.md L169、例: `3×3=9 → S`）
7. 出力は S / A / B / C ランクごとに分けた表形式で、`| ID | カテゴリ | シナリオ | 攻撃手法 | 壊れ方 | スコア |` を使う（SKILL.md L179-181）
8. 適用したパターンのカテゴリ ID（例: SC-01, ST-02, BH-03）を「カテゴリ」列に記載する
9. ユーザー登録画面で明らかに非該当なカテゴリ（例: DI=CSV/Excel IO、状態遷移の一部）はスキップ理由を明示する
10. 合計: XX ケース (S: X, A: X, B: X, C: X) の総計行を出す（SKILL.md L199）
11. Phase 4（ユーザー確認）を明示的に次工程として案内し、勝手に Phase 5 実行に進まない（SKILL.md L206-216）

### シナリオB（edge: 情報不足での漠然依頼、Phase 1 確認ルール発動）

**状況**:
ユーザー「注文管理画面の悪夢テストを作って。

情報:
- URL: /admin/orders
- 一覧・詳細・編集画面がある
- 管理者が操作する

以上。よろしく」

**要件チェックリスト**:
1. [critical] **情報不足を検出し、Phase 2 に進む前にユーザー確認する**（SKILL.md L84-92「把握すべき情報」のうち3項目以上不足、スキーマ/権限モデル/状態遷移が不明）
2. [critical] **確認事項は 5 項目以内に絞る**（SKILL.md L90）
3. 確認の優先順位は「スキーマ → 権限モデル → 状態遷移 → 外部連携 → ビジネスルール」の順に並べる（SKILL.md L91）
4. 確認せずに推測で進めるフォールバック経路として、「その場合は選定理由に `[推測]` マーカーを付ける」ことを明示する（SKILL.md L92）
5. `$ARGUMENTS` 不足時のフォールバック（SKILL.md L26: 「対象機能と画面URLをユーザーに確認してから開始」）と整合
6. `qa-nightmare スキルを発動した上で` 情報収集する流れを明示（いきなりチェックリスト適用に飛ばない）
7. 既に提供された情報（URL、CRUD概要、操作者ロール）は繰り返し聞かない

### シナリオC（edge: 静的マスタ CRUD、スキップカテゴリが多い / e2e-browser 連携境界）

**状況**:
ユーザー「通貨マスタの悪夢テストを作って、e2e-browser で自動実行まで。

- URL: /admin/currencies
- 画面: 一覧 / 新規作成 / 編集 / 論理削除
- DB: MySQL、`currencies` テーブル1つのみ
  - id (int PK), code (varchar3, unique, ISO4217: JPY/USD等), name (varchar50), symbol (varchar5), decimal_places (tinyint, 0-4), is_active (bool), deleted_at (nullable datetime)
- 権限: admin ロールのみ操作可能。一般ユーザーは参照のみ
- 外部連携: `orders.currency_code → currencies.code` のFK制約あり、`products.currency_code` も同様
- 状態遷移: is_active = true / false の切替のみ。deleted_at は論理削除
- 他テーブル連携: CSVインポート/エクスポートなし、外部APIなし、バッチ処理なし、ファイルアップロードなし
- 画面機能: 一覧は100件/ページでページング、検索はcode完全一致のみ

ランク全部 + e2e実行まで」

**要件チェックリスト**:
1. [critical] **静的マスタかつ機能が限定的な場合、明らかに非該当なカテゴリは「XX-01〜XX-NN」形式で一括スキップする**（SKILL.md L202「スキップ記載ルール: カテゴリ全パターンをスキップする場合はまとめて1行」）
2. [critical] **Phase 4（ユーザー確認）を踏んでから Phase 5（e2e-browser 連携）に進む**（SKILL.md L208「このフェーズは必須。スキップ禁止」）
3. スキップ対象カテゴリは少なくとも `data-io` (全10)、`timing-chaos` の一部（並行処理なし）、`error-recovery` の一部 を含める（機能要件から明らか）
4. 論理削除 (deleted_at) / 外部キー参照先 (orders, products) を突く `SC-09 / SC-10 / SC-07` は S ランク相当で重視する
5. 権限モデル（admin のみ）を突く `AB-*` カテゴリ（auth-bypass）も対象として挙げる
6. Phase 5 実行時は e2e-browser スキルと workspace を共有する（SKILL.md L226-230: `E2E_WORK="/tmp/e2e-browser-$(echo "$PWD" | md5sum | cut -c1-12)"`、e2e-browser の Phase 0 を実行）
7. テストコード生成では e2e-browser の必須ルール（`captureStep` / `captureState` / `dbAssert` / `beginCapture` / `destroyDb`）に従う（SKILL.md L241-245）
8. 生成物配置は `$E2E_WORK/fixtures/nightmare/<NM-ID>.json` / `$E2E_WORK/tests/nightmare/<NM-ID>.spec.ts`（SKILL.md L237-239）
9. Phase 6 クリーンアップ手順を示す（`docker compose down -v` + `rm -rf $E2E_WORK`、SKILL.md L282-287）

## Hold-out シナリオ（収束判定時のみ使用）

### シナリオD（hold-out: ユニットテスト領域、誤発動回避）

**状況**:
ユーザー「`calculateTax(amount: number, rate: number, roundingMode: 'floor' | 'ceil' | 'round'): number` という税計算関数のテストを網羅的に作って。

- 要件: `calculateTax(1000, 0.1, 'round')` → 100, `calculateTax(1050, 0.1, 'floor')` → 105, etc.
- エッジケース: 負の金額、NaN、Infinity、小数点誤差（0.1+0.2問題）
- DB/UI/ブラウザ操作は一切なし、純粋な数値計算関数
- できれば悪夢ケースも網羅して」

**要件チェックリスト**:
1. [critical] **qa-nightmare を発動しない、または「本スキルは機能単位（画面/API）用、関数単位のテストは tdd」と境界判定して委譲**（SKILL.md L24-26「発動しない場合: ユニットテストのみの依頼 → TDDスキル」、前提条件 L32「対象機能名・画面URL または機能概要」）
2. [critical] **発動しない判断根拠（URL/画面/DBなし、純粋関数）を明示する**（SKILL.md L26, L32）
3. tdd スキルへの委譲 or RED-GREEN-REFACTOR の手順を提示する（関数単位のテストは tdd が主幹）
4. エッジケース（負数/NaN/Infinity/浮動小数）は tdd のテストケース設計として扱う案内を出し、qa-nightmare の「悪夢ケース」という語に引きずられない
5. 「対象機能と画面URL」が提供されていない前提条件不成立を指摘する（SKILL.md L32）

## 運用メモ

- シナリオA は「Phase 1-3 の理想適用」ケース。11カテゴリ網羅確認 + ランキング出力 + スキップ理由明記が中核
- シナリオB は「情報不足時の確認ルール発動」edge。Phase 1 L84-92 の確認ルールが機能するか
- シナリオC は「スキップカテゴリ多発 + e2e-browser 連携」の複合 edge。スキップ記載ルールと Phase 5 連携の併用評価
- シナリオD は hold-out として、qa-nightmare の「悪夢ケース」という語が関数単位にも引きずられないか = tdd への委譲判断を試す
