# Claude Code 使い方ガイド v3.0

**更新日**: 2026-03-01
**構造**: Flat (6スキル)

---

## 📦 インストール

```bash
cd ~
unzip claude.zip
mv claude .claude
```

---

## 🎯 クイックスタート

### 1. プロジェクトセットアップ

```bash
cd ~/prog/your-project

# .claudeignore作成
cat > .claudeignore << 'EOF'
node_modules/
.git/
build/
dist/
*.log
__pycache__/
EOF

# CLAUDE.md作成
cat > CLAUDE.md << 'EOF'
---
project: your-project
stack: Your Tech Stack
---

## Skills
`~/.claude/CLAUDE.md` 参照
EOF
```

### 2. 基本使用

```bash
# Claude Code起動
claude code

# Commands実行
/commit
/code-review
/implement "機能実装"
```

---

## 📋 Skills (Flat構造, 6件)

| スキル | 用途 | 参照タイミング |
|--------|------|---------------|
| hallucination-prevention | API/パッケージ存在確認チェック | コード生成・情報提供時 |
| systematic-debugging | 4フェーズ根本原因分析 | バグ・テスト失敗時 |
| test-driven-development | RED-GREEN-REFACTOR強制 | 機能実装・バグ修正時 |
| hierarchical-architecture | ピラミッド依存・レイヤー設計 | 設計・レビュー時 |
| consultation | 構造化された相談テンプレート | 判断が必要な時 |
| failure-logging | 失敗DB記録・参照 | エラー・失敗時 |

**使い方**: `view ~/.claude/skills/<skill-name>/SKILL.md`

---

## 🎯 Commands (3件)

| Command | 用途 |
|---------|------|
| `/commit` | Conventional Commits形式でコミットメッセージ生成 |
| `/code-review` | 構造化レビュー (Critical/Warning/Suggestion/Good) |
| `/implement` | TDD 5フェーズ実装 (理解→RED→GREEN→REFACTOR→報告) |

---

## 🔧 便利機能

### 1. .claudeignore (必須)

**トークン削減: 80-95%**

```
# .claudeignore
node_modules/
.git/
build/
dist/
*.log
__pycache__/
.pytest_cache/
coverage/
```

### 2. Inline Commands

```cpp
// @claude: Use CRTP for zero-overhead
// @claude-optimize: Inline all methods
// @claude-test: Add comprehensive tests
// @claude-refactor: リファクタリング
```

---

## 💡 ベストプラクティス

### トークン削減

1. **必ず.claudeignore作成** (80-95%削減)
2. **Output最適化適用** (60%削減)

### 品質向上

1. **Test-First Mode**
2. **Skills参照**
3. **Inline Commands活用**

---

## 🐛 トラブルシューティング

### Q1. Skillsが見つからない

```bash
ls ~/.claude/skills/
```

6つのディレクトリが表示されるか確認。

### Q2. トークンが減らない

```bash
cat .claudeignore
```

なければ作成。

---

**詳細**: `README.md`, `CLAUDE.md`
