# Claude Code 統一パッケージ

Claude Code の skills, commands, hooks, templates, bin を統合したパッケージ

## 📁 構成

```
claude/
├── skills/        # 44個のスキル (既存39 + 新規5)
├── commands/      # 8個のコマンド (既存7 + 新規1)
├── hooks/         # 7個のhooks
├── templates/     # 言語テンプレート
└── bin/           # ユーティリティスクリプト
```

## 🆕 新規追加

### スキル (5個)

1. **problem-solving** - 壁打破の手法、思考パターン
2. **communication-guidelines** - 判断提示の原則
3. **daily-report** - 日報フォーマット
4. **quality-automation** - 自動レビュー
5. **forbidden-actions** - 禁止事項の詳細

### コマンド (1個)

1. **self-review** - 手動レビュー実行

## 📦 インストール

### 方法1: 直接配置

```bash
# ホームディレクトリに配置
cd ~
unzip claude-unified.zip
mv claude-unified .claude

# またはdotfile-workリポジトリに配置
cd ~/dotfile-work
unzip claude-unified.zip
mv claude-unified claude
```

### 方法2: シンボリックリンク

```bash
# .claudeディレクトリにシンボリックリンク
cd ~
ln -s ~/dotfile-work/claude .claude
```

## 🚀 使用方法

### スキル参照

```bash
# スキル一覧
ls ~/.claude/skills/

# スキルを読む
view ~/.claude/skills/problem-solving/SKILL.md
view ~/.claude/skills/test-driven-development/SKILL.md
```

### コマンド実行

```bash
# PATHに追加 (~/.bashrc or ~/.zshrc)
export PATH="$HOME/.claude/commands:$PATH"

# コマンド実行
git-new-feature my-feature
self-review
self-review --help
```

### hooks 有効化

```bash
# Claude Code起動時に自動的に読み込まれます
# または手動で実行
bash ~/.claude/hooks/session-start-reminder.sh
```

## 📖 ドキュメント

各スキルの詳細は SKILL.md を参照してください。

## 🔧 カスタマイズ

プロジェクト固有の設定は `CLAUDE.md` (ローカル) に記述してください。

## 📝 更新履歴

### 2025-01-17

- 新規スキル5個追加
- 新規コマンド1個追加
- フォーマット統一
- 品質チェック実施

## 📄 ライセンス

[ライセンス情報]

## 🤝 貢献

バグ報告や機能提案は Issue または Pull Request でお願いします。
