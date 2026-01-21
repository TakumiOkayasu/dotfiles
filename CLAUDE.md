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
│   │   ├── .gitconfig.work    # Linux/work environment
│   │   └── .gitconfig.private # macOS/personal environment
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
│   │   ├── session-start-reminder.sh     # Session start
│   │   ├── git-commit-push-block.sh      # Block Claude from commit/push
│   │   ├── main-branch-code-warning.sh   # Warn edits on main
│   │   ├── branch-from-main-check.sh     # Verify branch from main
│   │   ├── git-post-command-reminder.sh  # Auto cleanup merged branches
│   │   ├── doc-consistency-reminder.sh   # Doc consistency check
│   │   └── failure-check.sh              # Error detection
│   ├── skills/                # 4-tier skill system (55 skills)
│   │   ├── 1-core/            # Always applied (10)
│   │   ├── 2-domain/          # Project selection (21)
│   │   ├── 3-task/            # On-demand (17)
│   │   └── 4-utility/         # Special purpose (7)
│   └── templates/lang/        # Project templates
└── docs/
    ├── USAGE.md               # Usage guide v2.0
    └── SETTINGS_GUIDE.md      # settings.json guide
```

## Key Concepts

### 4-Tier Skills System

| Tier | Directory | Load | Count | Purpose |
|------|-----------|------|-------|---------|
| 1-core | skills/1-core/ | Always | 10 | Mandatory rules (TDD, debugging, forbidden-actions) |
| 2-domain | skills/2-domain/ | Project config | 21 | Domain-specific (web-backend, embedded, security) |
| 3-task | skills/3-task/ | On-demand | 17 | Task-specific (design, integration, maintenance) |
| 4-utility | skills/4-utility/ | Manual | 7 | Special utilities (consultation, daily-report) |

### Install Flow

1. `install.sh` reads files from `config/` and `claude/` via `git ls-files`
2. Creates symlinks to `$HOME` (config) and `~/.claude` (claude)
3. `global_CLAUDE.md` is renamed to `CLAUDE.md` when linked to `~/.claude/`
4. Existing files are backed up with `.bak` extension

### Platform Detection

- macOS: Uses `.gitconfig.private`
- Linux/WSL: Uses `.gitconfig.work`
- Detected via `detect_platform()` in `install.sh:118`

## Development Notes

- All shell scripts use POSIX sh for portability
- Japanese documentation throughout (user preference)
- Token optimization is a primary concern (settings.json: maxTokens: 2000)
- Hooks block Claude from running `git commit` or `git push` directly
