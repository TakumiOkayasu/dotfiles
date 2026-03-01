# settings.json ガイド

## 📍 配置場所

```bash
~/.claude/settings.json        # グローバル設定
./CLAUDE.md                    # プロジェクト設定 (優先)
```

**優先順位**: プロジェクトCLAUDE.md > グローバルsettings.json

---

## 🚀 クイックスタート

### 最小構成 (推奨)

```json
{
  "output": {
    "maxTokens": 2000,
    "noPreamble": true
  },
  "context": {
    "mode": "incremental"
  },
  "security": {
    "blockGitCommit": true
  }
}
```

**効果**: トークン▼60%, ロード▼90%

---

## 📋 主要設定項目

### 1. Output最適化 (最優先)

```json
"output": {
  "maxTokens": 2000,           // 目標トークン数
  "format": "table-preferred", // テーブル優先
  "noPreamble": true,          // 前置き禁止
  "noPostamble": true,         // 締め禁止
  "useSymbols": true           // 記号活用 (✅❌⚠️)
}
```

**効果**: Output▼60%

---

### 2. Context Loading

```json
"context": {
  "mode": "incremental",       // 段階的読み込み
  "initial": [                 // 初期ファイル
    "CLAUDE.md",
    "README.md"
  ],
  "autoExpandMax": 3,          // 自動展開最大数
  "exclude": [                 // 除外パターン
    "node_modules/**",
    ".git/**"
  ]
}
```

**効果**: ロード▼90%

---

### 3. Skills設定

```json
"skills": {
  "hierarchy": "flat",         // フラット構造 (6スキル)
  "list": [                    // 全スキル
    "hallucination-prevention",
    "systematic-debugging",
    "test-driven-development",
    "hierarchical-architecture",
    "consultation",
    "failure-logging"
  ]
}
```

**効果**: Skills▼55-77%

---

### 4. Security

```json
"security": {
  "blockGitCommit": true,      // commit禁止
  "blockGitPush": true,        // push禁止
  "protectMainBranch": true,   // main保護
  "detectSecrets": true        // 機密情報検出
}
```

**効果**: 事故防止

---

### 5. Import Management

```json
"imports": {
  "autoImport": true,          // 自動import
  "sortImports": true,         // ソート
  "removeUnused": true,        // 未使用削除
  "style": "absolute"          // 絶対パス
}
```

**効果**: コード整理自動化

---

### 6. Commands

```json
"commands": {
  "enabled": true,
  "aliases": {                 // エイリアス
    "/r": "/research",
    "/b": "/bounce",
    "/i": "/implement"
  }
}
```

**効果**: タイピング削減

---

### 7. Development

```json
"development": {
  "testFirst": false,          // Test-First Mode
  "diffPreview": true,         // 差分プレビュー
  "autoSave": false,           // 自動保存
  "backupOnEdit": false        // 編集時バックアップ
}
```

---

### 8. Symbol Navigation

```json
"symbols": {
  "enabled": true,             // 有効化
  "autoIndex": true,           // 自動インデックス
  "cacheTTL": 3600            // キャッシュ有効期限
}
```

**効果**: リファクタリング▼70%

---

## 🎯 プロジェクト別推奨設定

### Embedded (C++/Arduino)

```json
{
  "output": {
    "maxTokens": 2000,
    "noPreamble": true
  },
  "context": {
    "mode": "incremental",
    "exclude": [".pio/**", "*.o", "*.bin"]
  },
  "development": {
    "testFirst": false
  }
}
```

---

### Web Backend (Node.js/Python)

```json
{
  "output": {
    "maxTokens": 2000,
    "noPreamble": true
  },
  "context": {
    "mode": "incremental",
    "exclude": ["node_modules/**", "venv/**"]
  },
  "imports": {
    "autoImport": true,
    "sortImports": true
  },
  "security": {
    "detectSecrets": true
  }
}
```

---

### Web Frontend (React/Vue)

```json
{
  "output": {
    "maxTokens": 2000,
    "noPreamble": true
  },
  "context": {
    "mode": "incremental",
    "exclude": ["node_modules/**", "dist/**", ".next/**"]
  },
  "imports": {
    "autoImport": true,
    "sortImports": true,
    "removeUnused": true
  }
}
```

---

## 💡 ベストプラクティス

### 必須設定 (全プロジェクト)

```json
{
  "output": {"maxTokens": 2000, "noPreamble": true},
  "context": {"mode": "incremental"},
  "security": {"blockGitCommit": true}
}
```

---

### 推奨設定 (開発効率化)

```json
{
  "imports": {"autoImport": true, "sortImports": true},
  "symbols": {"enabled": true},
  "commands": {"enabled": true}
}
```

---

### オプション設定 (高度)

```json
{
  "session": {"persistence": true},
  "performance": {"parallel": true},
  "analytics": {"enabled": false}
}
```

---

## 🔧 設定確認

```bash
# 設定ファイル確認
cat ~/.claude/settings.json

# 有効な設定確認
claude code --show-config

# 設定テスト
claude code --test-config
```

---

## 🐛 トラブルシューティング

### Q1. 設定が反映されない

**A**: 優先順位確認

```
1. プロジェクトCLAUDE.md
2. グローバルsettings.json
3. デフォルト設定
```

### Q2. JSONエラー

**A**: 構文チェック

```bash
# JSONバリデーション
jq . ~/.claude/settings.json

# または
python -m json.tool ~/.claude/settings.json
```

### Q3. どの設定が有効か分からない

**A**: 設定出力

```bash
claude code --show-config
```

---

## 📊 設定別効果

| 設定 | 効果 | 推奨度 |
|------|------|--------|
| output最適化 | ▼60% | ⭐⭐⭐⭐⭐ |
| Incremental Loading | ▼90% | ⭐⭐⭐⭐⭐ |
| Security | 事故防止 | ⭐⭐⭐⭐⭐ |
| Import Management | 自動化 | ⭐⭐⭐⭐ |
| Symbol Navigation | ▼70% | ⭐⭐⭐⭐ |
| Commands | 効率化 | ⭐⭐⭐ |

---

## 🎓 使用例

### グローバル設定

```bash
# ~/.claude/settings.json に配置
cp templates/settings.minimal.json ~/.claude/settings.json
```

### プロジェクト設定

```bash
# プロジェクトルートのCLAUDE.md に追加
cat >> CLAUDE.md << 'EOF'

## Settings

- Context mode: incremental
- Max tokens: 2000
- Test-first: true
EOF
```

---

**テンプレート**:
- `settings.json` - 完全版
- `settings.minimal.json` - 最小版
