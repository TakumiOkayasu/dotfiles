# dotfiles

個人用dotfilesリポジトリ

## 含まれるファイル

| ファイル | 説明 |
|----------|------|
| `.bashrc` | Bash設定ファイル |
| `.bash_aliases` | エイリアス定義 (grep, ls, docker等) |
| `.vimrc` | Vim設定ファイル |
| `.gitconfig` | Git設定 (エイリアス, ユーザー情報等) |
| `.gitignore` | グローバルgitignore |
| `.git-completion.bash` | Git補完スクリプト |
| `.git-prompt.sh` | Gitプロンプト表示スクリプト |
| `.claude/` | Claude Code設定ディレクトリ |
| `CLAUDE.md` | Claude Code用指示ファイル |

## 使い方

### シンボリックリンク作成

```bash
# dotfilesディレクトリのパス
DOTFILES_DIR="$(pwd)/dotfile-work"

# Bash関連
ln -sf "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
ln -sf "$DOTFILES_DIR/.bash_aliases" "$HOME/.bash_aliases"

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
```

### 設定の反映

```bash
source ~/.bashrc
```

