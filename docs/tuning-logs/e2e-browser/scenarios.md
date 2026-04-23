# e2e-browser シナリオカタログ

empirical-prompt-tuning でチューニングするための評価シナリオ。**iter 開始後は変更しない**。

- 対象スキル: `claude/skills/e2e-browser/SKILL.md`
- description: 「ブラウザE2Eテスト生成・実行・レポート(Docker内Playwright+Bun+Knex.js)。UI操作+DB検証+全ステップスクショ。WSLg/noVNC/headless切替対応。プロジェクト非汚染。」
- 収束目標: **連続2** イテレーション（典型スキル）

## 隣接スキルとの境界（iter 0 整合確認の焦点）

| スキル | 対比 |
|---|---|
| qa-nightmare | qa-nightmare = **悪夢ケース生成**（11カテゴリ109パターンの網羅チェック）、e2e-browser = **実行基盤**（qa-nightmare で抽出したケースを Playwright+Bun で実行する） |
| tdd | tdd = ユニットテストの RED-GREEN-REFACTOR、e2e-browser = ブラウザ結合テスト（UI+DB）。tdd は関数単位、e2e-browser はフロー単位 |
| test-coverage-guard | test-coverage-guard = 既存テストの信頼性検証（偽陽性検出）、e2e-browser = 新規 E2E テスト生成。test-coverage-guard は tdd 後段、e2e-browser は独立基盤 |
| systematic-debugging | sd = バグの原因分析（Phase 1-4）、e2e-browser = テスト失敗の**再現・修正**（SKILL.md トリガー5「既存E2Eテスト失敗調査・修正」）。sd は原因仮説、e2e-browser は再現手段 |

## Baseline シナリオ

### シナリオA（中央値: ログイン機能のE2E、UI操作 + DB検証）

**状況**:
ユーザー「ユーザーログイン機能の E2E テストを作って。

- 対象URL: http://host.docker.internal:8080/login
- 操作: メールとパスワードを入力 → ログインボタン押下 → /dashboard にリダイレクト
- 期待UI: `[data-testid="welcome-message"]` に `Welcome, alice` が表示される
- DB検証: `users.last_login_at` が更新されていること、`sessions` テーブルに該当 user_id のレコードが 1 件存在すること
- DB: PostgreSQL、テストDB名は `app_e2e`、user=test/password=test
- 表示モード: headless
- 前提データ: id=1, email=alice@example.com, is_active=true のユーザーが1件」

**要件チェックリスト**:
1. [critical] **e2e-browser スキルを発動し、Phase 0-5 を順守**（Phase 0 環境チェック → Phase 1 コンテナ起動 → Phase 2 テスト生成 → Phase 3 実行 → Phase 4 レポート → Phase 5 クリーンアップ）
2. [critical] **生成物を `$E2E_WORK` 配下に配置し、プロジェクトディレクトリを汚染しない**（SKILL.md L36, L326）
3. `.env.e2e` に DB_CLIENT=pg, E2E_BASE_URL, E2E_DISPLAY=headless 等を記述する
4. Fixture JSON を **配列形式**（テーブル名キーではなく `[{table, rows, truncate}]`）で作成する（SKILL.md L140-158）
5. テストコード冒頭で `beginCapture` を呼ぶ（SKILL.md L219）
6. UI 操作（goto / fill / click）は `captureStep` でラップし、状態撮影は `captureState` を使う（SKILL.md L220-222）
7. `dbAssert.exists` / `dbAssert.columnEquals` を使って DB 検証を行う（SKILL.md L237-254）
8. `data-testid` を優先セレクタに使い、具体値の確認が必要な箇所は「アプリ実装を確認」と明示する（SKILL.md L223）
9. `afterAll` で `destroyDb()` を呼ぶ（SKILL.md L225）
10. `page.waitForTimeout()` を使わず、`waitForResponse` / `waitForSelector` を使う（SKILL.md L224, L320）

### シナリオB（edge: 既存E2Eテスト失敗調査・修正、トリガー5番目）

**状況**:
ユーザー「既存の E2E テスト `$E2E_WORK/tests/order/checkout.spec.ts` が CI で落ちてる。

エラー: `Timeout 30000ms exceeded while waiting for response` が `page.waitForResponse` で発生
スクリーンショットを見ると送信ボタン押下後に `/api/checkout` への POST が発行されず、ボタンが `disabled` のまま

直前のコミット差分: チェックアウトフォームに reCAPTCHA を追加した
DB検証: `orders` テーブルにレコードが作成されない

原因調査して修正して。テストは壊さずに通るようにして。」

**要件チェックリスト**:
1. [critical] **発動判定（トリガー5「既存E2Eテスト失敗調査・修正」）を明示し、systematic-debugging との境界を示す**（原因分析は sd、テスト修正は e2e-browser）
2. [critical] **`page.waitForTimeout()` を使わずに修正する**（SKILL.md L224, L320）
3. 失敗時のレポート（エラーメッセージ + 失敗前後スクショ + DB実値ダンプ）手順を示す（SKILL.md L295-303）
4. 修正案提示 → ユーザー承認 → Phase 3 再実行のフローを踏む（SKILL.md L303）
5. `captureStep` / `captureState` で証跡が残るよう維持する
6. reCAPTCHA 追加という仕様変更に対し、テストデータ（fixture）または待機条件の更新提案を含める
7. 「テスト自体を緩めて通す」（例: アサーション削除、`waitForTimeout` 追加）は禁止事項として指摘する

### シナリオC（edge: 外部キー親子関係のある複数テーブル fixture、cleanup順序）

**状況**:
ユーザー「注文機能の E2E テストを作って。

- 対象URL: http://host.docker.internal:8080/orders/new
- 操作: 商品選択 → 数量入力 → 注文確定
- 期待UI: `/orders/:id/complete` にリダイレクトし、注文番号が表示される
- DB検証:
  - `orders` に user_id=1 のレコードが1件増える（自動採番IDを取得）
  - `order_items` にその `order_id` 紐付きで 2 件挿入される
- DB: MySQL（app_e2e / root / rootpass）
- 前提データ: users(id=1), products(id=100, id=101) が存在
- 外部キー: `order_items.order_id → orders.id`, `orders.user_id → users.id`, `order_items.product_id → products.id`
- 表示モード: novnc でリアルタイム確認したい」

**要件チェックリスト**:
1. [critical] **Fixture の列挙順を「外部キー親 → 子」にする**（users → products → orders → order_items、SKILL.md L162）
2. [critical] **`cleanup(['子', '親'])` を MySQL で子 → 親の順で列挙する**（SKILL.md L230）
3. 自動採番された `orders.id` を取得するために `getDb()` を直接使い、`dbAssert` で不可能な検証を補う（SKILL.md L258-268）
4. docker-compose.e2e.yml は MySQL テンプレートを使用し、novnc の port 6080 は公開済みであることを示す（SKILL.md L107）
5. novnc 使用時に「`http://localhost:6080/vnc.html` をブラウザで開いてください」の案内を出す（SKILL.md L123-126）
6. `dbAssert.count('order_items', { order_id: X }, 2)` のように採番 ID を挟んだ検証を行う
7. datetime / uuid 型を使う場合は ISO8601 文字列で記述する（SKILL.md L165）
8. `workers > 1` を設定しないこと（SKILL.md L324）を明示する

## Hold-out シナリオ（収束判定時のみ使用）

### シナリオD（hold-out: ユニットテスト領域、誤発動回避）

**状況**:
ユーザー「`formatPrice(amount: number, currency: string): string` という通貨フォーマット関数を作りたい。

- 要件: `formatPrice(1000, 'JPY')` → `'¥1,000'`, `formatPrice(1000.5, 'USD')` → `'$1,000.50'`
- 想定外入力: 負の数、NaN、未知の currency コード
- DB も UI も関係なし、純粋な文字列処理

テストを書いてほしい」

**要件チェックリスト**:
1. [critical] **e2e-browser を発動しない**（UI 操作も DB 検証もない、純粋なユニットテスト領域）
2. [critical] **tdd スキルへ委譲、または RED-GREEN-REFACTOR の手順を提示する**（関数単位のテストは tdd が主幹）
3. 発動しない判断根拠（トリガー 1-5 いずれも非該当、前提条件「テスト対象アプリが起動済み」が不要）を明示する
4. テストケース設計では qa-nightmare の「想定外入力（負の数、NaN、未知 currency）」列挙を案内する
5. 「UI を介さないテストに e2e-browser は過剰」という境界判断を示す

## 運用メモ

- シナリオ A は「Phase 0-5 を順に適用」の理想ケース。captureStep/captureState と dbAssert の正しい使用が中核
- シナリオ B は「既存テスト失敗調査」トリガー5を突く edge。systematic-debugging 境界と禁止事項（waitForTimeout）の組み合わせ
- シナリオ C は「外部キー + 採番 ID + novnc」の複合 edge。fixture 列挙順 / cleanup 順 / getDb 直叩きの併用評価
- シナリオ D は hold-out として、**発動すべきでない場面での誤発動回避**（ユニットテストに e2e-browser を当てる誤用）を試す
