# Claude Code 使い方ガイド v3.0

**更新日**: 2026-03-01
**構造**: Flat

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
/feat "機能実装"
```

---

## 📏 Rules (常時適用, 2件)

| ルール | 用途 |
| -------- | ------ |
| hallucination-prevention | AI出力検証・API/パッケージ存在確認 |
| hierarchical-architecture | ピラミッド依存・レイヤー設計制約 |

Rules はセッション開始時に自動で読み込まれる。配置先: `~/.claude/rules/`

## 📋 Skills (オンデマンド)

### 自作スキル

| スキル | 用途 | 参照タイミング |
| -------- | ------ | --------------- |
| systematic-debugging | 4フェーズ根本原因分析 | バグ・テスト失敗時 |
| test-driven-development | RED-GREEN-REFACTOR強制 | 機能実装・バグ修正時 |
| consultation | 構造化された相談テンプレート | 判断が必要な時 |
| failure-logging | 失敗DB記録・参照 | エラー・失敗時 |

### Vendor スキル (vercel-labs/agent-skills)

| スキル | 用途 |
| -------- | ------ |
| composition-patterns | React コンポジションパターン |
| react-best-practices | React/Next.js パフォーマンス最適化 |
| web-design-guidelines | Web UI デザインガイドライン |

`install.sh` で自動 clone、SessionStart hook で1日1回自動更新。

**使い方**: `view ~/.claude/skills/<skill-name>/SKILL.md`

---

## 🎯 Commands

| Command | 用途 |
| --------- | ------ |
| `/commit` | Conventional Commits形式でコミットメッセージ生成 |
| `/code-review` | 構造化レビュー (Critical/Warning/Suggestion) 修正コード付き |
| `/feat` | 機能実装ガイド (要件整理→RED→GREEN→REFACTOR→報告) |
| `/fix` | バグ修正ガイド (再現→根本原因→失敗テスト→修正→リグレッション確認) |

---

## 🔧 便利機能

### 1. .claudeignore (必須)

#### トークン削減: 80-95%

```text
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
