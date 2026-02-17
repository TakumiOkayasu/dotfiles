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

### CLI Tools (bin/)

```bash
claude-init <lang>        # Initialize Claude Code in a project (python|typescript|cpp|go|php-laravel|php-cakephp)
claude-init --list        # List available templates
git-new-feature <name>    # Create feature branch (feat/fix/docs/refactor/chore)
git-cleanup-branch        # Delete merged branches (local and remote)
gh-setup-repo             # Setup GitHub repo (branch protection, auto-delete)
```

## Architecture

```text
dotfile-work/
├── install.sh                 # Main installer (921 lines, POSIX sh)
├── config/
│   ├── shell/                 # Shell configs
│   │   ├── bash/bashrc        # Bash config
│   │   ├── zsh/zshrc          # Zsh config
│   │   ├── fish/config.fish   # Fish config
│   │   ├── common.sh          # Shared env/PATH
│   │   └── aliases.sh         # Shared aliases
│   ├── git/
│   │   ├── .gitconfig.common  # Shared settings (included by work/private)
│   │   ├── .gitconfig.work    # Linux/work environment
│   │   └── .gitconfig.private # macOS/personal environment
│   ├── .gitignore.common  # Common gitignore patterns
│   ├── .gitignore.work    # Work-specific patterns (ignores .claude/)
│   └── .gitignore.private # Private-specific patterns
│   └── vim/.vimrc
├── claude/                    # Claude Code config (~/.claude)
│   ├── global_CLAUDE.md       # Global instructions (Japanese)
│   ├── settings.json          # Claude settings (hooks, skills, lang:ja)
│   ├── .claudeignore          # Global ignore patterns (209 lines)
│   ├── commands/              # Slash commands
│   │   ├── bounce.md          # /bounce - idea discussion
│   │   ├── research.md        # /research - quick search
│   │   ├── deepresearch.md    # /deepresearch - thorough research
│   │   ├── implement.md       # /implement - implementation guide
│   │   ├── commit.md          # /commit - commit message generation
│   │   ├── code-review.md     # /code-review - code review
│   │   └── task.md            # /task - task management
│   ├── hooks/                 # Auto-reminders
│   │   ├── session-start-reminder.sh           # Session start
│   │   ├── git-commit-push-block.sh            # Block Claude from commit/push
│   │   ├── main-branch-code-warning.sh         # Warn edits on main
│   │   ├── branch-from-main-check.sh           # Verify branch from main
│   │   ├── git-post-command-reminder.sh        # Auto cleanup merged branches
│   │   ├── doc-consistency-reminder.sh         # Doc consistency check
│   │   ├── dev-environment-docker-enforce.sh   # Block local package manager commands
│   │   ├── hierarchical-architecture-naming-check.sh  # Naming convention check
│   │   ├── write-execute-guard.sh              # Write+Execute attack detection
│   │   └── failure-check.sh                    # Error detection
│   ├── skills/                # 4-tier skill system
│   │   ├── 1-core/            # Always applied
│   │   ├── 2-domain/          # Project selection
│   │   ├── 3-task/            # On-demand
│   │   └── 4-utility/         # Special purpose
│   └── templates/lang/        # Project templates
└── docs/
    ├── USAGE.md               # Usage guide v2.0
    └── SETTINGS_GUIDE.md      # settings.json guide
```

## Key Concepts

### 4-Tier Skills System

| Tier | Directory | Load | Purpose |
|------|-----------|------|---------|
| 1-core | skills/1-core/ | Always | Mandatory rules (TDD, debugging, forbidden-actions) |
| 2-domain | skills/2-domain/ | Project config | Domain-specific (web-backend, embedded, security) |
| 3-task | skills/3-task/ | On-demand | Task-specific (design, integration, maintenance) |
| 4-utility | skills/4-utility/ | Manual | Special utilities (consultation, daily-report) |

### Install Flow

1. `install.sh` reads files from `config/` and `claude/` via `git ls-files`
2. Creates symlinks to `$HOME` (config) and `~/.claude` (claude)
3. `global_CLAUDE.md` is renamed to `CLAUDE.md` when linked to `~/.claude/`
4. Existing files are backed up with `.bak` extension

### Platform Detection

- macOS: Uses `.gitconfig.private`
- Linux/WSL: Uses `.gitconfig.work`
- Detected via `detect_platform()` in `install.sh:118`

## Shell Config Rules

| 設定種別 | 配置先 | 理由 |
|----------|--------|------|
| PATH・環境変数 (共通) | `config/shell/common.sh` | bash/zsh/fish共通で使うため |
| エイリアス (共通) | `config/shell/aliases.sh` | 同上 |
| シェル固有設定 | `config/shell/<shell>/` | そのシェルでしか使わない設定 |
| ローカル設定 (Git管理外) | `~/.local.sh` or `~/.bash_profile.local` | 環境固有の設定 |

## Development Notes

- All shell scripts use POSIX sh for portability
- Japanese documentation throughout (user preference)
- Token optimization is a primary concern (settings.json: maxTokens: 2000)
- Hooks block Claude from running `git commit` or `git push` directly

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
