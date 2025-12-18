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

### インストール

```bash
./install.sh
```

- 既存ファイルは自動でバックアップされます (`.bak` 拡張子が付与される)
- シンボリックリンクが既に存在する場合は再作成されます

### 設定の反映

```bash
source ~/.bashrc
```

### 手動でシンボリックリンク作成 (非推奨)

基本的に `install.sh` を使用してください。手動で作成する場合の例:

```bash
ln -sf "$(pwd)/.bashrc" "$HOME/.bashrc"
```

**注意**: 手動の場合、既存ファイルのバックアップは行われません。

