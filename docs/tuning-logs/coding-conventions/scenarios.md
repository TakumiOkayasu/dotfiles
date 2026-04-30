# coding-conventions シナリオカタログ

## 隣接 rule / skill との境界

| 隣接 | 境界 |
|---|---|
| `hierarchical-architecture` (L110-118 サフィックス命名) | coding-conventions は「曖昧接頭辞の禁止」、hierarchical は「レイヤー役割サフィックス」。L213 で coding-conventions が hierarchical を明示参照済 |
| `implementation-policy` (L28 print 禁止 / ロギングライブラリ経由) | coding-conventions L266 が print 禁止を肯定しつつ「詳細は implementation-policy」で委譲。ログ設計の SSOT は implementation-policy |
| `hallucination-prevention` (L24-25 型・引数の実在確認) | HP=実在確認 (外部 API)、CC=型注釈の設計原則 (any 禁止 / unknown 活用)。干渉なし |
| `oop-composition-over-inheritance` (合成 > 継承) | CC L215-221 SOLID は原則宣言、OOP は適用ガイド。役割分担あり |
| `skills/tdd/SKILL.md` | CC L279-298 は「テスト規約の抜粋 (AAA / 命名)」、TDD スキルは「サイクル運用」。CC L288 で委譲済 |

## baseline シナリオ (3 本、中央値 1 + edge 2)

### A (中央値): 複合違反のあるユーティリティ関数レビュー

**状況**: TypeScript/Node で書かれた以下の関数のコードレビュー依頼。修正提案 + 理由を示してほしい。

```typescript
function parseData(data: any): any {
    // データをパースする
    if (data !== null) {
        if (data.length > 0) {
            if (data.length < 1000) {
                const items = [];
                for (let i = 0; i < data.length; i++) {
                    const item = data[i];
                    if (item.type === 'A') {
                        items.push(item);
                    }
                }
                return items;
            }
        }
    }
    return null;
}
```

**要件チェックリスト**:
1. [critical] `any` 禁止を指摘し、`unknown` + 型ガード or 具体型提案 (L128-141)
2. [critical] 深いネスト (制御構造 4 階層) を指摘し、早期リターンで平坦化を提案 (L30-31, 35-49)
3. [critical] マジックナンバー (1000) を指摘し、定数化を提案 (L84-95)
4. [critical] WHAT コメント「データをパースする」を指摘し、削除 or WHY に書換 (L171, 178-186)
5. [critical] 戻り値 null と空配列の扱いを指摘し、空配列返却を提案 (L106, 108-121)
6. 変数 `item` が最小ループ内なのでそのまま許容 (L210 例外節) — 過剰指摘しないこと
7. 関数名 `parseData` の `data` 語が曖昧気味だが、Parse 目的語があるので判定は柔軟に (L203 execute* 例外の類推)
8. 優先順位: critical 違反 (1-5) を先に、スタイル的改善 (6-7) は後 or 省略 (CC-0-1 観察点)
9. 修正コード例を提示する場合、rule 準拠 (`const`, unknown, ガード節, WHY コメント) で書く

### B (edge): React コンポーネント + ビジネスロジック混在での命名例外判定

**状況**: React アプリのユーティリティモジュール (非コンポーネント層)。以下の関数命名のレビュー依頼。

```typescript
// src/handlers/orderHandlers.ts (非 React 層)
export function handleOrder(order: Order): ProcessedOrder { /* ... */ }
export function processPayment(payment: Payment): Receipt { /* ... */ }
export function manageInventory(items: Item[]): InventoryState { /* ... */ }

// src/components/OrderForm.tsx (React 層)
function OrderForm() {
    const handleSubmit = (e: FormEvent) => { /* ... */ };
    const handleClick = () => { /* ... */ };
    // ...
}
```

**要件チェックリスト**:
1. [critical] 非 React 層の `handleOrder` / `processPayment` / `manageInventory` を曖昧命名として指摘 (L195-206)
2. [critical] React 層の `handleSubmit` / `handleClick` はフレームワーク規約として**許容** (L208-209 例外)
3. [critical] 業務層の具体名提案 (例: `validateOrder` / `chargePayment` / `reserveInventory` 等、相当する動詞を選ぶ)
4. 非 React 層 vs React 層の区別基準を明確化 (ディレクトリ / ファイル名 / 関数の役割で判定)
5. `manageInventory` は `*Manager` サフィックスとは別 (L204) — 責務が不明な一般動詞として指摘
6. 過剰修正禁止: React 層の `handle*` に勝手に手を入れない

### C (edge): async + error + log の複合違反

**状況**: 以下の Node.js サーバコードのレビュー依頼。ログ出力・エラー伝播・非同期処理に関する改善を示してほしい。

```javascript
async function syncUsers(source, target) {
    return source.fetchAll().then(users => {
        return target.bulkInsert(users).then(result => {
            console.log(`Synced user ${users[0].email} with token ${users[0].authToken}`);
            return result;
        }).catch(e => {});
    });
}
```

**要件チェックリスト**:
1. [critical] Promise chain (`.then`) を async/await に書換提案 (L147, 152-164)
2. [critical] 空 catch (握り潰し) を指摘し、ログ記録+再 throw or 呼出側伝播を提案 (L149, 239, 253)
3. [critical] `console.log` 直接使用を指摘し、ロガー経由に置換提案 (L266, implementation-policy 参照を示せば加点)
4. [critical] 機密情報 (`email` / `authToken`) のログ混入を指摘し、除外提案 (L265, 270-276)
5. [critical] 構造化ログ化を提案 (`extra={...}` / キー・バリュー形式) (L263, 273-276)
6. `source.fetchAll()` と `target.bulkInsert()` に並列化余地があるかは文脈不明 — 過剰に `Promise.all` を提案しない (依存関係が明示されている)
7. try/catch 配置: 関数内か呼出側かの判断を示す (CC-0-5 観察点)
8. 修正コード例は rule 準拠 (async/await / logger / キー・バリュー)

## hold-out シナリオ (D、誤発動回避)

### D: 既に rule 準拠の小関数への過剰修正回避

**状況**: 以下の TypeScript 関数は既に rule 準拠。「レビューして気になる点を挙げて」と依頼。

```typescript
const MAX_RETRY_COUNT = 3;

async function fetchUserProfile(userId: string): Promise<UserProfile | null> {
    if (!userId) return null;

    for (let attempt = 0; attempt < MAX_RETRY_COUNT; attempt++) {
        try {
            return await apiClient.getUser(userId);
        } catch (error) {
            logger.warn('fetchUserProfile retry', { userId, attempt, error: String(error) });
        }
    }
    return null;
}
```

**要件チェックリスト**:
1. [critical] 早期リターン / 定数化 / 型注釈 / 構造化ログ / async/await / catch で処理実施 — **既準拠として認識**し過剰修正提案を出さない
2. [critical] 「null 返却 vs 例外 throw」は設計選択として保留するか、両選択肢を提示して判断を任せる (L253-256 エラーコード vs 例外統一は別文脈)
3. 指摘すべきがあれば **境界的な論点のみ** (例: 最終リトライ失敗時の null か throw か、logger.warn vs logger.error の粒度) を簡潔に
4. `rule 準拠の大半の項目を満たしている` と明示する (rule を lint として誤用しない)
5. 修正必要なしと判定した場合、**その判定理由を明示** (「X / Y / Z すべて rule 準拠のため」)

## 共通の dispatch プロンプト要件

- 対象 rule 本文 (`claude/rules/coding-conventions.md`) を Read で読ませる
- 他 rule / skill の auto-load は避けるよう明示 (ただし rules は常時ロードなので「対象 rule を優先参照」と指定)
- empirical-prompt-tuning「subagent 起動契約」節のレポート構造で返答
- `[critical]` 項目が全 ○ のときのみ成功
