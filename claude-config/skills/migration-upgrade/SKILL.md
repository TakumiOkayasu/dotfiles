---
name: migration-upgrade
description: フレームワークのアップグレードや技術移行時に使用。
---

# Migration and Upgrade

## トリガー

- フレームワーク・ライブラリ更新時
- 技術スタック移行時
- 破壊的変更対応時
- ゼロダウンタイム移行時

## 鉄則

**大きな変更は小さなステップに。常にロールバック可能に。**

## 準備

```bash
# 現状確認
npm outdated

# 確認すべきドキュメント
□ CHANGELOG
□ Migration Guide
□ Breaking Changes
```

## 段階的移行

### ストラングラーパターン

```typescript
// 新旧並行稼働
if (featureFlags.useNewService) {
  return newService.process();
}
return legacyService.process();
```

### カナリアリリース

```
90% → 旧バージョン
10% → 新バージョン(問題なければ徐々に増加)
```

## 安全な手順

```bash
1. ブランチ作成
2. 依存更新
3. コード変更
4. テスト実行
5. ステージング確認
6. 本番デプロイ
```

## DB移行(ゼロダウンタイム)

```sql
-- 1. NULL許可で追加
ALTER TABLE users ADD COLUMN new_col VARCHAR(255);
-- 2. データ移行
UPDATE users SET new_col = old_col;
-- 3. アプリ更新(両方対応)
-- 4. 旧カラム削除
ALTER TABLE users DROP COLUMN old_col;
```

## ロールバック

- Feature Flagで即座に切り戻し
- Blue-Greenデプロイ
- DBマイグレーションはDown対応必須

## 失敗時

```
依存競合 → npm ls で確認、resolutionsで解決
型エラー多発 → @ts-expect-errorで一時抑制、段階修正
テスト失敗 → 仕様変更か確認
```
