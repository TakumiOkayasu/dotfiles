# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

dotfile-work is a personal dotfiles repository with an emphasis on Claude Code configuration. It manages:

- Shell configs (bash/zsh/fish)
- Git configs (work/private variants)
- Vim config
- Claude Code settings (global CLAUDE.md, skills, hooks, commands)

## Commands

### Installation

```bash
./install.sh              # Interactive mode
./install.sh -f           # Install all (auto-detect platform)
./install.sh -n           # Dry run (preview)
./install.sh -u           # Uninstall (remove symlinks)
```

> **Windows (PowerShell / Git Bash)**: `install.sh` は POSIX sh スクリプトです。PowerShell からは `wsl bash ./install.sh -f` で実行してください。Git Bash からは直接 `./install.sh` で実行可能です。

### CLI Tools (bin/)

```bash
git-new-feature <name>    # Create feature branch (feat/fix/docs/refactor/chore)
git-cleanup-branch        # Delete merged branches (local and remote)
gh-setup-repo             # Setup GitHub repo (branch protection, auto-delete)
jpinput                   # Windows IME経由の日本語入力ヘルパー (-t: type, -c: clip)
skills-update.sh          # Auto-update vendor skills (Docker-isolated, security scan)
statusline-command.sh     # Claude Code statusline (3-line: session/5h/7d usage)
```

### Slash Commands

```sh
/project-init [lang]      # Initialize Claude Code in a project (auto-detect or specify, 14 languages, aliases supported)
```

## Architecture

```text
dotfile-work/
├── install.sh                 # Main installer (POSIX sh)
├── config/
│   ├── shell/                 # Shell configs
│   │   ├── bash/              # bashrc, bash_profile
│   │   ├── zsh/               # zshrc, zprofile
│   │   ├── fish/config.fish   # Fish config
│   │   ├── common.sh          # Shared env/PATH
│   │   ├── aliases.sh         # Shared aliases
│   │   ├── aliases.local      # Local alias overrides
│   │   └── local/             # Platform-specific (macos, linux, wsl, windows)
│   ├── git/
│   │   ├── .gitconfig.common  # Shared settings (included by work/private)
│   │   ├── .gitconfig.work    # Linux/work environment
│   │   ├── .gitconfig.private # macOS/personal environment
│   │   ├── .gitignore.common  # Common gitignore patterns
│   │   ├── .gitignore.work    # Work-specific patterns (ignores .claude/)
│   │   ├── .gitignore.private # Private-specific patterns
│   │   ├── .git-completion.bash  # Git completion script
│   │   └── .git-prompt.sh       # Git prompt script
│   ├── windows/
│   │   └── config.xlaunch     # VcXsrv起動設定
│   ├── gtk-4.0/
│   │   └── settings.ini       # GTK4カーソルテーマ・サイズ
│   └── vim/.vimrc
├── claude/                    # Claude Code config (~/.claude)
│   ├── global_CLAUDE.md       # Global instructions (Japanese)
│   ├── settings.json          # Claude settings (hooks, skills, lang:ja)
│   ├── .claudeignore          # Global ignore patterns
│   ├── bin/                   # CLI tools (~/.claude/bin/)
│   │   ├── claude-config-info.sh      # Config info utility
│   │   ├── skills-update.sh           # Vendor skills auto-updater (Docker+scan)
│   │   └── statusline-command.sh      # Statusline (session/usage display)
│   ├── commands/              # Slash commands
│   │   ├── commit.md          # /commit - commit message generation
│   │   ├── code-review.md     # /code-review - code review
│   │   ├── implement.md       # /implement - TDD implementation guide
│   │   └── project-init.md    # /project-init - project template initializer
│   ├── hooks/                 # Auto-reminders
│   │   ├── session-start-reminder.sh           # Session start reminder
│   │   ├── session-resume.sh                   # Session resume from progress
│   │   ├── destructive-command-block.sh         # Block destructive operations
│   │   ├── main-branch-code-warning.sh         # Warn edits on main
│   │   ├── gh-repo-auto-setup.sh               # Auto repo setup (delete-branch-on-merge + Rulesets)
│   │   ├── commit-checkpoint.sh                # Auto checkpoint on commit
│   │   ├── context-monitor.sh                  # Context usage monitoring
│   │   ├── pre-compact-backup.sh               # Backup before compaction
│   │   ├── docker-build-check.sh               # Docker build validation
│   │   ├── language-version-check.sh           # Language version check
│   │   ├── local-command-block.sh              # Block local command execution
│   │   ├── admin-command-block.sh              # Block sudo/admin commands
│   │   ├── env-file-protect.sh                 # Block .env file read/edit
│   │   ├── secret-leak-check.sh               # Block hardcoded secrets in commands
│   │   └── project-environment-check.sh       # Docker/Git status (called by session-start)
│   ├── rules/                 # Always-loaded constraints
│   │   ├── hallucination-prevention.md  # AI output verification
│   │   └── hierarchical-architecture.md # Pyramid dependency design
│   ├── skills/                # On-demand procedure guides
│   │   ├── systematic-debugging/
│   │   ├── test-driven-development/
│   │   ├── consultation/
│   │   └── failure-logging/
│   └── templates/             # /project-init templates (~/.claude/templates/)
│       ├── lang/              # Language-specific CLAUDE.md
│       └── rules/             # Rule templates (common + per-lang)
└── docs/
    ├── USAGE.md                       # Usage guide
    ├── SETTINGS_GUIDE.md              # settings.json guide
    ├── CLAUDE-MD-WRITING-GUIDE.md     # CLAUDE.md writing guide
    ├── SETUP-CLAUDE.md                # Claude Code setup guide
    ├── VCXSRV_GHOSTTY_SETUP.md        # VcXsrv + Ghostty setup guide (WSL2)
    └── bug-report-gitignore-jenkins-2026-01-12.md  # Bug report
```

## Key Concepts

### Rules (Always Loaded)

| Rule | Purpose |
| ------ | --------- |
| hallucination-prevention | AI output verification, API/package existence check |
| hierarchical-architecture | Pyramid dependency, layer design constraints |

### Skills (On-Demand)

| Skill | Purpose |
| ------- | --------- |
| systematic-debugging | 4-phase root cause analysis |
| test-driven-development | RED-GREEN-REFACTOR enforcement |
| consultation | Structured consultation template |
| failure-logging | Failure DB recording |

### Install Flow

1. `install.sh` reads files from `config/` and `claude/` via `git ls-files`
2. Creates symlinks to `$HOME` (config) and `~/.claude` (claude)
3. `global_CLAUDE.md` is renamed to `CLAUDE.md` when linked to `~/.claude/`
4. Existing files are backed up with `.bak` extension

### Platform Detection

- macOS: Uses `.gitconfig.private`
- Linux/WSL: Uses `.gitconfig.work`
- Detected via `detect_platform()` in `install.sh`

## Shell Config Rules

| 設定種別 | 配置先 | 理由 |
| ---------- | -------- | ------ |
| PATH・環境変数 (共通) | `config/shell/common.sh` | bash/zsh/fish共通で使うため |
| エイリアス (共通) | `config/shell/aliases.sh` | 同上 |
| シェル固有設定 | `config/shell/<shell>/` | そのシェルでしか使わない設定 |
| ローカル設定 (Git管理外) | `~/.local.sh` or `~/.bash_profile.local` | 環境固有の設定 |

## Development Notes

- Shell scripts use POSIX sh where possible; bash-dependent scripts use `#!/bin/sh` + bash re-exec pattern
- Japanese documentation throughout (user preference)
- Token optimization is a primary concern
- Hooks block Claude from running `git commit` or `git push` directly
- ドキュメントに具体的な数値 (件数・行数) を書かない。ドリフトしてハルシネーションの原因になるため

## Design Decisions

### `.claude/rules/` は本リポジトリでは不採用 (2026-03-05)

Zenn記事「Claude Code設定構成ガイド」で推奨される `.claude/rules/` を評価した結果、本リポジトリでは不採用とした。

| 理由 | 詳細 |
| ------ | ------ |
| dotfileリポジトリの特殊性 | `.claude/rules/` はプロジェクト固有ルール向け。グローバル設定配布には不適合 |
| 既に分離済み | skills + hooks + commands で CLAUDE.md 肥大化問題は解決済み |
| グローバル配布不可 | `.claude/rules/` はプロジェクトローカル。`~/.claude/` へのシンボリックリンク配布に使えない |

### グローバル skills → rules 移行 (2026-03-05)

制約/規約の性質が強い2スキルを `~/.claude/rules/` に移行する。

| スキル | 判定 | 理由 |
| -------- | ------ | ------ |
| hallucination-prevention | **rules移行** | 全出力に適用すべき行動制約 |
| hierarchical-architecture | **rules移行** | 設計・命名の制約集。常時適用すべき |
| systematic-debugging | skill維持 | 4フェーズ手順書。オンデマンドで十分 |
| test-driven-development | skill維持 | 手順書+制約の混合。手順部分が主 |
| consultation | skill維持 | 相談テンプレート。オンデマンド |
| failure-logging | skill維持 | 記録フォーマット。オンデマンド |

`~/.claude/rules/` では `paths:` が無視されるバグ (Issue #21858) があるため、pathsなしの常時適用ルールとして配置する。

### `claude-init` CLI 廃止 → `/project-init` スラッシュコマンドに移行 (2026-03-05)

`claude-init` はシェルスクリプトとして `bin/` に配置していたが、Claude Code のスラッシュコマンド `/project-init` に移行して廃止。理由:

- Claude が直接テンプレートを読み取り配置するため、シェルスクリプトの中間処理が不要
- `templates/` は `install.sh` で `~/.claude/templates/` にシンボリックリンクされる
- ユーザーは Claude Code セッション内で `/project-init python` のように実行する

### `/project-init` に `.claude/rules/` を導入 (2026-03-05)

テンプレートの Code Style / Testing / Constraints を `.claude/rules/` に分離し、CLAUDE.md はプロジェクト概要・ビルドコマンドのみに縮小する。

**生成するルールファイル構成** (言語共通 + 言語固有):

| ファイル | paths | 内容 |
| ---------- | ------- | ------ |
| `.claude/rules/testing.md` | 言語別テストglob | テスト規約 (AAA, 命名, モック最小) |
| `.claude/rules/security.md` | なし | 入力バリデーション, パラメータ化クエリ, 秘密情報禁止 |
| `.claude/rules/code-style.md` | なし | 言語固有の命名規則・フォーマッタ設定 |

**既知の注意点**:

| 注意 | 詳細 |
| ------ | ------ |
| YAML引用符必須 | `paths:` のglobは `"**/*.ts"` と引用符で囲む (Issue #13905) |
| `~/.claude/rules/` でpaths不可 | ユーザーレベルでは `paths:` が無視される (Bug #21858, OPEN) |
| 1ファイル1トピック | 500行超はNG。簡潔に保つ |
| Lint強制可能なルールは書かない | hooks/formatter に委譲してコンテキスト節約 |

## [自動] セッション継続プロトコル

以下のルールはClaude自身が自律的に実行する。ユーザーへの確認は不要。

### PROGRESS.md 自動更新

ファイル: `.claude/progress.md`

以下のタイミングで自動的に更新すること:

1. **タスク着手時** → 「現在のタスク」セクションを更新
2. **設計判断を下した時** → 「判断ログ」に理由(Why)とともに追記
3. **Planモードで結論が出た時** → 実装に入る前に書き出し
4. **タスク完了時** → 完了マーク + 次のタスク

### コンテキスト警告への対応

hookがコンテキスト使用率の警告を発した場合:

- **⚠️ 70%警告**: PROGRESS.md が最新か確認し、必要なら更新
- **🚨 85%警告**: 即座に PROGRESS.md を更新。特に:
  - 現在のタスクの状況
  - 設計判断の理由(Why) ← 最も失われやすい
  - 未完了事項と次のステップ
- **Planモード中に警告が出た場合**: 一度Planを抜けて PROGRESS.md を更新し、再度Planに戻る

### セッション開始時

1. `.claude/progress.md` がhookから注入されるので、その内容を確認
2. 未完了タスクがあれば、そこから再開
3. ユーザーに「前回の続きから再開します」と一言伝える

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
