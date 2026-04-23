# test-coverage-guard シナリオカタログ

empirical-prompt-tuning でチューニングするための評価シナリオ。**iter 開始後は変更しない**。

- 対象スキル: `claude/skills/test-coverage-guard/SKILL.md`
- description: 「既存テストの信頼性を検証し、偽陽性を検出・排除するガードレール。テストがGREENになった後に発動する。」
- 収束目標: **連続2** イテレーション（典型スキル）

## 隣接スキルとの境界（iter 0 整合確認の焦点）

| スキル | 対比 |
|---|---|
| tdd | tdd = **テスト作成**、test-coverage-guard = **既存テスト検証**。不足発見時は TDD に委譲 |
| systematic-debugging | sd = バグの**原因分析**、test-coverage-guard = テストの**信頼性分析** |
| refactoring | refactoring = 本体コード整理、test-coverage-guard = テストコード品質 |

## Baseline シナリオ

### シナリオA（中央値: PR レビューで偽陽性検出）

**状況**:
`UserService.updateEmail` の PR がレビュー依頼されている。テストは以下:

```typescript
test('should update email', () => {
  const service = new UserService();
  const mockRepo = jest.fn().mockResolvedValue({ id: 1, email: 'new@example.com' });
  service.repo = mockRepo;
  service.updateEmail(1, 'new@example.com');
  expect(mockRepo).toHaveBeenCalled();
});
```

ユーザー「このテストレビューして」と依頼。

**要件チェックリスト**:
1. [critical] **テスト GREEN 後の検証であり、テスト新規作成は行わない**（TDD に委譲）
2. [critical] **偽陽性リスクを明示的に検出**（アサーション不足: 戻り値未検証、await 欠落、toHaveBeenCalled のみ）
3. Step 2 P1 パターン1（アサーション不足）を適用する
4. ミューテーション思考実験を適用する（例: `updateEmail` を no-op にしても PASS か）
5. 修正方針を提示する（戻り値・状態変化・副作用の検証追加）
6. レポート出力フォーマット（🔴/🟡/🟢）に沿って指摘する

### シナリオB（edge: モック過多テストの削除判断）

**状況**:
ユーザー「`OrderService` のテストが Mock 5つ使ってて保守つらい。削除していい?」

```typescript
// 参考: OrderService テストで Mock 対象
// - UserRepository (自プロジェクト)
// - OrderRepository (自プロジェクト)
// - PaymentGateway (外部 API)
// - NotificationService (自プロジェクト)
// - Logger (自プロジェクト)
```

**要件チェックリスト**:
1. [critical] **削除判断基準（L211-214）を明示的に参照**（3条件のいずれか + 代替テスト存在 or 追加予定）
2. [critical] **「即削除すべきテスト」（L218-223）には該当しない**（実際の振る舞い未検証なら偽陽性の温床判定は可能）
3. Step 4 の「自プロジェクトのDB/他クラスは**実物**」原則を指摘
4. Mock 5つのうち、外部 API 以外は実物/Fake に置換可能と提示
5. 削除ではなくリファクタリング推奨を明示
6. テストダブル種別（Stub/Mock/Fake/Spy）の使い分け表を援用する

### シナリオC（edge: スコープ広すぎの全件レビュー依頼）

**状況**:
ユーザー「プロジェクト全体のテスト 300 件レビューして。偽陽性ないか確認したい」

**要件チェックリスト**:
1. [critical] **Step 1 の「対象100件超の場合、リスクベースで絞り込みを提案」（L59）を発動**
2. [critical] **300件を一度にレビューせず、絞り込み方針を先にユーザー合意**
3. リスクベースの優先順位（カバレッジ低・バグ多・クリティカル機能）を提示
4. PR差分 / モジュール単位 / リスクベース の選択肢をユーザーに提示
5. 先行レビュー対象の提案（例: 決済・認証周り）を出す
6. 残りのテストのレビュー方針（例: 段階実施）を明示

## Hold-out シナリオ（収束判定時のみ使用）

### シナリオD（テスト新規作成依頼 = 発動すべきでない）

**状況**:
ユーザー「`calculateDiscount` のテストを書いてくれ。境界値の異常系も網羅して」

**要件チェックリスト**:
1. [critical] **本スキルを発動せず、`test-driven-development` スキルに委譲**（SKILL.md L22「テスト新規作成 → test-driven-development」）
2. [critical] **既存テストの検証ではなくテスト作成依頼であることを認識**
3. 責務境界（「本スキル = 検証専用、作成は TDD」）を明示してユーザーに説明
4. TDD スキルで扱うべき観点（RED → GREEN、網羅性設計）を TDD 側に委ねる旨を明示
5. test-coverage-guard は「GREEN 後の信頼性検証」であることを明示

## 運用メモ

- シナリオ A は「最頻出 PR レビュー」の観点で中央値
- シナリオ B はテスト削除判断の誤解（ダブル過多 → 即削除）を誘発する edge
- シナリオ C は Step 1 スコープ特定の「100件超ガード」発動試験
- シナリオ D は hold-out として、**発動すべきでない場面での誤発動回避**（TDD 境界）を試す
