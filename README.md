# dotfiles

個人用dotfilesリポジトリ

## 含まれるファイル

| ファイル | 説明 |
|----------|------|
| `.bashrc` | Bash設定ファイル |
| `.shell_aliases` | シェル共通エイリアス定義 (Bash/Zsh, macOS/Linux対応) |
| `.vimrc` | Vim設定ファイル |
| `.gitconfig` | Git設定 (エイリアス, ユーザー情報等) |
| `.gitignore` | グローバルgitignore |
| `.git-completion.bash` | Git補完スクリプト |
| `.git-prompt.sh` | Gitプロンプト表示スクリプト |
| `.claude/` | Claude Code設定ディレクトリ |
| `CLAUDE.md` | Claude Code用指示ファイル |
| `settings.json` | Claude Code権限設定 |
| `SKILL-github.md` | GitHub PRレビュースキル |
| `SKILL-gitlab.md` | GitLab MRレビュースキル |
| `install.sh` | シンボリックリンク作成スクリプト |

## 使い方

### インストールスクリプト (推奨)

```bash
./install.sh
```

既存ファイルは自動でバックアップ (`.bak`) されます。

### 手動でシンボリックリンク作成

```bash
# dotfilesディレクトリのパス
DOTFILES_DIR="$(pwd)"

# シェル関連
ln -sf "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
ln -sf "$DOTFILES_DIR/.shell_aliases" "$HOME/.shell_aliases"

# Vim
ln -sf "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"

# Git関連
ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES_DIR/.git-completion.bash" "$HOME/.git-completion.bash"
ln -sf "$DOTFILES_DIR/.git-prompt.sh" "$HOME/.git-prompt.sh"

# グローバルgitignore (.gitconfigで参照されるパス)
mkdir -p "$HOME/.config/git"
ln -sf "$DOTFILES_DIR/.gitignore" "$HOME/.config/git/ignore"

# Claude Code設定
ln -sf "$DOTFILES_DIR/.claude" "$HOME/.claude"
ln -sf "$DOTFILES_DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$DOTFILES_DIR/settings.json" "$HOME/.claude/settings.json"

# Claude Code スキルファイル
mkdir -p "$HOME/.claude/commands"
ln -sf "$DOTFILES_DIR/SKILL-github.md" "$HOME/.claude/commands/SKILL-github.md"
ln -sf "$DOTFILES_DIR/SKILL-gitlab.md" "$HOME/.claude/commands/SKILL-gitlab.md"
```

### 設定の反映

```bash
source ~/.bashrc
```

