---
name: dependency-management
description: Use when managing packages or handling vulnerabilities.
---

# Dependency Management

## 鉄則

**依存は負債。必要最小限に。**

## 追加前チェック

```
□ 本当に必要?(自前実装で済まないか)
□ メンテされている?(最終更新)
□ ライセンス確認(MIT, Apache等)
□ 依存の依存は多すぎないか
```

## バージョン指定

```json
{
  "express": "^4.18.0",    // マイナー更新OK(推奨)
  "critical": "~1.2.3",    // パッチのみ
  "security": "1.2.3"      // 完全固定
}
```

## 脆弱性対応

```bash
npm audit
npm audit fix

# 定期的に
npm outdated
```

## ロックファイル

必ずコミット: `package-lock.json`, `yarn.lock`, `poetry.lock`

## 更新手順

```bash
npm outdated                  # 確認
# CHANGELOGを読む
npm update <package>          # 更新
npm test                      # テスト
git commit                    # コミット
```

## ライセンス確認

```bash
npx license-checker --summary
```

| 注意 | 理由 |
|------|------|
| GPL/AGPL | コピーレフト |
| 独自ライセンス | 個別確認必須 |
