---
name: security-checklist
description: ファイル編集・コミット準備時に使用。シークレット漏洩防止チェックを実施。
---

# Security Checklist

## トリガー

- ファイル作成・編集時
- コミット準備時
- `.env`や認証関連コードに触れる時
- APIキー、トークン、パスワードを扱う時

## 🚨 鉄則

**シークレットはハードコード禁止。環境変数で管理。コミット前に必ずチェック。**

## コミット前チェックリスト

```
□ APIキー、パスワード、トークンがハードコードされていない
□ .envファイルが.gitignoreに含まれている
□ デバッグ用のconsole.log/print文が残っていない
□ 機密情報を含むファイルを誤って編集していない
□ テスト用の認証情報が本番用と分離されている
```

## 編集禁止ファイル(確認なしで触らない)

```
*.lock          (package-lock.json, yarn.lock, Cargo.lock等)
.env*           (.env, .env.local, .env.production等)
.git/*
*.pem, *.key, *.crt   (証明書・秘密鍵)
*_rsa, *_ed25519      (SSH鍵)
credentials.json, secrets.yaml
```

## シークレット検出パターン

⚠️ 以下のパターンを含むコードは警告:

```
api_key = "sk-..."
API_KEY = "..."
aws_access_key_id = "AKIA..."
DATABASE_URL = "postgres://user:password@..."
JWT_SECRET = "..."
token = "ghp_..."   # GitHub
token = "xoxb-..."  # Slack
```

## 安全な実装パターン

```python
# ❌ NG: ハードコード
api_key = "sk-1234567890"

# ✅ OK: 環境変数
import os
api_key = os.environ.get("API_KEY")
```

```gitignore
# .gitignore に追加
.env
.env.local
config/secrets.yml
```

## 違反発見時のアクション

1. 即座にユーザーに報告
2. 該当コードを修正案とともに提示
3. `.gitignore`の確認を促す
4. 必要に応じてgit履歴からの削除方法を案内
