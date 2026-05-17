# deep-review シナリオカタログ

empirical-prompt-tuning でチューニングする評価シナリオ。**iter 開始後は変更しない**。

- 対象 command: `claude/commands/deep-review.md`
- 概要: 直近の変更を 3 観点 (セキュリティ / パフォーマンス / 保守性) の並列 subagent で検査・統合
- 収束目標: **連続 3** イテレーション (高重要度コマンド)

## 隣接コマンド・スキルとの境界

| 隣接 | 対比 |
| --- | --- |
| 公式 `code-review` プラグイン | プラグイン版は単一 subagent。本コマンドは 3 観点並列 + synthesis が固有差別 |
| `refactoring` skill | refactoring は変更行為、deep-review は指摘行為 |
| `security-review` slash | security-review はセキュリティ単観点。deep-review の Subagent 1 がカバーする範囲のスーパーセット |

## Baseline シナリオ

### シナリオ A (median): 3 観点全部該当の PR

**入力差分**: 認可チェック追加 + 既存ループ非効率 + 命名変更 を含む TypeScript PR。

```diff
--- a/src/api/orders/list.ts
+++ b/src/api/orders/list.ts
@@ -1,18 +1,22 @@
-import { db } from '../../db';
+import { db } from '../../db';
+import { currentUser } from '../../auth';

 export async function listOrders(req: Request): Promise<Response> {
-  const userId = req.headers.get('x-user-id');
-  const orders = await db.query('SELECT * FROM orders WHERE user_id = ' + userId);
+  const user = currentUser(req);
+  if (!user) return new Response('Unauthorized', { status: 401 });
+
+  const orders = await db.query('SELECT * FROM orders WHERE user_id = $1', [user.id]);

   const result = [];
   for (const order of orders) {
-    const items = await db.query('SELECT * FROM order_items WHERE order_id = $1', [order.id]);
-    result.push({ ...order, items });
+    const itemList = await db.query('SELECT * FROM order_items WHERE order_id = $1', [order.id]);
+    result.push({ ...order, items: itemList });
   }

   return Response.json(result);
 }
```

**期待される指摘 (3 観点)**:
- Security: SQL インジェクション修正 (旧→新) は良いが、ユーザー入力検証は十分か (Subagent 1)
- Performance: N+1 問題 (orders ループ内で order_items を逐次クエリ) — JOIN で 1 クエリ化推奨 (Subagent 2)
- Maintainability: `items` → `itemList` リネームの意義が薄い (副作用) / 関数 30 行未満で OK / 型注釈の有無 (Subagent 3)

**要件チェックリスト**:
1. **[critical]** 3 つの subagent を 1 メッセージ内で並列 dispatch している
2. **[critical]** 全 Critical / Warning 指摘に `✅ 修正案:` が添えられている
3. **[critical]** 判定ヘッダー (`## 判定: [BLOCK|WARN|PASS]`) が先頭、判定基準表 (Critical 1+ → BLOCK 等) に準拠
4. N+1 問題が Warning 以上で指摘されている
5. `items` → `itemList` の不要リネームが Suggestion 以上で指摘されている (担当 = 保守性)
6. 「良い点」セクションが出力されていない
7. 推測指摘 (「もしかしたら」「可能性がある」) が無い

### シナリオ B (edge): DB スキーマ + 公開 API 変更 (方針検証発動跡確認)

**入力差分**: 新規テーブル + 新規公開 API エンドポイントを含む 150 行差分。

```diff
--- /dev/null
+++ b/migrations/20260517_add_user_preferences.sql
@@ -0,0 +1,12 @@
+CREATE TABLE user_preferences (
+  id SERIAL PRIMARY KEY,
+  user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
+  theme VARCHAR(32) NOT NULL DEFAULT 'light',
+  language VARCHAR(8) NOT NULL DEFAULT 'ja',
+  email_notifications BOOLEAN NOT NULL DEFAULT TRUE,
+  push_notifications BOOLEAN NOT NULL DEFAULT FALSE,
+  digest_frequency VARCHAR(16) NOT NULL DEFAULT 'weekly',
+  timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Tokyo',
+  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
+  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
+);

--- /dev/null
+++ b/src/api/preferences/get.ts
@@ -0,0 +1,30 @@
+export async function getPreferences(req: Request): Promise<Response> {
+  const user = currentUser(req);
+  if (!user) return new Response('Unauthorized', { status: 401 });
+  const prefs = await db.query('SELECT * FROM user_preferences WHERE user_id = $1', [user.id]);
+  return Response.json(prefs[0] || null);
+}
+
+export async function updatePreferences(req: Request): Promise<Response> {
+  const user = currentUser(req);
+  if (!user) return new Response('Unauthorized', { status: 401 });
+  const body = await req.json();
+  await db.query(
+    `INSERT INTO user_preferences (user_id, theme, language, email_notifications, push_notifications, digest_frequency, timezone)
+     VALUES ($1, $2, $3, $4, $5, $6, $7)
+     ON CONFLICT (user_id) DO UPDATE SET
+       theme = $2, language = $3, email_notifications = $4, push_notifications = $5, digest_frequency = $6, timezone = $7,
+       updated_at = NOW()`,
+    [user.id, body.theme, body.language, body.emailNotifications, body.pushNotifications, body.digestFrequency, body.timezone]
+  );
+  return new Response(null, { status: 204 });
+}
```

PR 本文・コミットメッセージ・`.claude/progress.md` の判断ログ・差分内コメントには premise-questioning / feature-pruning の発動跡は無い。

**要件チェックリスト**:
1. **[critical]** 3 並列 dispatch している
2. **[critical]** 方針検証発動跡が無いことを Critical として指摘している (deep-review.md「方針検証発動跡の確認」節準拠)
3. **[critical]** 判定 = BLOCK (Critical 1+)
4. DB スキーマ変更で `user_preferences` に `user_id` の UNIQUE 制約が無い (ON CONFLICT (user_id) は UNIQUE がないと動かない) — セキュリティ or 保守性で指摘
5. `updatePreferences` 内で `body` のバリデーションが無い — セキュリティで指摘
6. 公開 API 変更で feature-pruning 発動跡が無い (5 列以上の新設なら本来発動条件) — 保守性で指摘
7. 推測指摘がない

### シナリオ C (sparse): typo 1 文字修正

**入力差分**: 単一行の typo 修正。

```diff
--- a/src/utils/format.ts
+++ b/src/utils/format.ts
@@ -1,1 +1,1 @@
-export const formatedDate = (d: Date) => d.toISOString().slice(0, 10);
+export const formattedDate = (d: Date) => d.toISOString().slice(0, 10);
```

**要件チェックリスト**:
1. **[critical]** 3 並列 dispatch している (typo でも担当観点を最後まで走査するルール)
2. **[critical]** 判定 = PASS (Critical 0 / Warning ≤ 2)
3. **[critical]** 「指摘ゼロでの打ち切り」が起きていない (担当観点ごとに走査結果を 1 行でも出している)
4. 命名修正の意義 (`formated` は誤綴り) を 1 行で言及できている (保守性)
5. 「良い点」セクションを出していない
6. 出力テンプレ (`## 判定`) ヘッダーがある

## Hold-out シナリオ (収束判定時のみ)

### シナリオ D (hold-out): テスト追加のみ (担当観点偏り検出)

**入力差分**: 10 ケースのユニットテスト追加のみ (本体コード変更なし)。

```diff
--- /dev/null
+++ b/src/utils/format.test.ts
@@ -0,0 +1,40 @@
+import { describe, it, expect } from 'vitest';
+import { formattedDate, parseAmount, slugify } from './format';
+
+describe('formattedDate', () => {
+  it('returns ISO date (YYYY-MM-DD)', () => {
+    expect(formattedDate(new Date('2026-05-17T10:00:00Z'))).toBe('2026-05-17');
+  });
+  it('handles year boundary', () => {
+    expect(formattedDate(new Date('2025-12-31T23:59:59Z'))).toBe('2025-12-31');
+  });
+});
+
+describe('parseAmount', () => {
+  it('parses integer string', () => {
+    expect(parseAmount('1000')).toBe(1000);
+  });
+  it('parses with comma separator', () => {
+    expect(parseAmount('1,234,567')).toBe(1234567);
+  });
+  it('returns 0 for empty', () => {
+    expect(parseAmount('')).toBe(0);
+  });
+  it('throws on invalid', () => {
+    expect(() => parseAmount('abc')).toThrow();
+  });
+});
+
+describe('slugify', () => {
+  it('lowercases and dashes', () => {
+    expect(slugify('Hello World')).toBe('hello-world');
+  });
+  it('removes special chars', () => {
+    expect(slugify('Hello!@# World')).toBe('hello-world');
+  });
+  it('handles unicode', () => {
+    expect(slugify('こんにちは 世界')).toBe('こんにちは-世界');
+  });
+  it('returns empty for empty', () => {
+    expect(slugify('')).toBe('');
+  });
+});
```

**要件チェックリスト**:
1. **[critical]** 3 並列 dispatch している
2. **[critical]** 全観点 (セキュリティ / パフォーマンス / 保守性) からの指摘または「該当なし」が明示されている (担当外侵食なし)
3. **[critical]** 判定 = PASS (テスト追加のみで本体変更なし → Critical/Warning 想定外)
4. テスト品質指摘 (保守性): `parseAmount('1,234,567')` のテスト追加に対し、本体実装が無いことに気付けるか
5. 単一観点に偏っていない (例: 保守性のみで他観点に「該当なし」表記)
6. 推測指摘がない

## 判定規則

- 成功 ○ = [critical] 全 ○
- 精度 % = (○: 1.0 / 部分的: 0.5 / ×: 0) の合算 / 全項目数
