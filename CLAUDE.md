# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

個人用dotfilesリポジトリ。Shell/Git/Vim設定とClaude Code設定（skills, hooks, commands, rules, templates）を管理し、`install.sh` でシンボリックリンクを配置する。

## Commands

```bash
# インストール
./install.sh              # 対話モード
./install.sh -f           # 全ファイル強制インストール
./install.sh -n           # ドライラン
./install.sh -u           # アンインストール

# テスト (Docker)
docker compose -f tests/compose.yml run --rm hooks-test    # hook テスト
docker compose -f tests/compose.yml run --rm bin-test      # bin/ テスト
docker compose -f tests/compose.yml run --rm install-test  # install.sh テスト

# CLI (bin/ → ~/bin/)
git-new-feature <name>    # ブランチ作成 (-f fix/ -d docs/ -r refactor/ -c chore/)
git-cleanup-branch        # マージ済みブランチ削除
gh-setup-repo             # GitHub リポジトリ設定

# Slash Commands (claude/commands/)
/project-init [lang]      # プロジェクト初期化 (14言語対応)
/feat [description]       # 機能実装ガイド (TDD)
/fix [description]        # バグ修正ガイド
```

## Architecture

```text
dotfile-work/
├── install.sh           # メインインストーラー (POSIX sh)
├── config/              # ドットファイル本体
│   ├── shell/           # bash/zsh/fish + common.sh, aliases.sh
│   ├── git/             # .gitconfig.{common,work,private}, .gitignore.*
│   └── vim/             # .vimrc
├── claude/              # Claude Code設定 → ~/.claude/ にリンク
│   ├── global_CLAUDE.md # → ~/.claude/CLAUDE.md (リネームしてリンク)
│   ├── settings.json    # hooks/skills/lang設定
│   ├── commands/        # スラッシュコマンド
│   ├── hooks/           # 自動処理 (セキュリティ, セッション管理)
│   ├── rules/           # 常時適用ルール (hallucination-prevention, hierarchical-architecture)
│   ├── skills/          # オンデマンド手順 (TDD, debugging, consultation, failure-logging)
│   └── templates/       # /project-init 用テンプレート (lang/, rules/)
├── bin/                 # CLI ツール → ~/bin/
├── tests/               # Docker テスト
└── docs/                # ドキュメント
```

## Install Flow

1. `git ls-files` で `config/` と `claude/` のファイルを列挙
2. `config/` → `$HOME` に、`claude/` → `~/.claude/` にシンボリックリンク作成
3. `global_CLAUDE.md` は `CLAUDE.md` にリネームしてリンク
4. プラットフォーム自動検出: macOS → `.gitconfig.private` / Linux・WSL → `.gitconfig.work`

## Development Notes

- シェルスクリプトは原則 POSIX sh。bash依存スクリプトは `#!/bin/sh` + bash再実行パターン
- ドキュメントに具体的な数値（件数・行数）を書かない（ドリフト防止）

## [自動] セッション継続プロトコル

以下はClaude自身が自律的に実行する。

### PROGRESS.md 自動更新

ファイル: `.claude/progress.md`

更新タイミング:

1. **タスク着手時** → 「現在のタスク」更新
2. **設計判断時** → 「判断ログ」に理由(Why)追記
3. **Planモード結論時** → 実装前に書き出し
4. **タスク完了時** → 完了マーク + 次のタスク

### コンテキスト警告対応

- **⚠️ 70%**: PROGRESS.md が最新か確認
- **🚨 85%**: 即座に更新（現状・判断理由・次のステップ）

### セッション開始時

`.claude/progress.md` の内容を確認し、未完了タスクがあればそこから再開。

### PROGRESS.md フォーマット

```markdown
# PROGRESS

## 現在のタスク
- [ ] タスク名 - 目的: xxx

## 判断ログ
- YYYY-MM-DD: 判断内容。理由: ...

## 完了
- [x] 完了したタスク
```
