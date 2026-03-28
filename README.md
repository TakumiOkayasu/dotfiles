# dotfiles

個人用dotfilesリポジトリ。Shell/Git/Vim設定とClaude Code設定を `install.sh` でシンボリックリンク配置する。

## クイックスタート

```bash
./install.sh -n           # ドライラン (プレビュー)
./install.sh -f           # 全ファイルインストール
source ~/.bashrc           # 設定反映
```

## インストールオプション

```bash
./install.sh              # 対話モード (カテゴリ選択)
./install.sh -f           # 全ファイル強制インストール
./install.sh -n           # ドライラン
./install.sh -u           # アンインストール (リンク削除、バックアップ復元)
```

> **Windows**: PowerShell → `wsl bash ./install.sh -f` / Git Bash → 直接実行可

## 構成

| ディレクトリ | 配置先 | 内容 |
| --- | --- | --- |
| `config/shell/` | `~/` | bash/zsh/fish設定、共通aliases/env |
| `config/git/` | `~/` | .gitconfig (work/private)、.gitignore、補完 |
| `config/vim/` | `~/` | .vimrc |
| `claude/` | `~/.claude/` | Claude Code設定一式 (後述) |
| `bin/` | `~/bin/` | CLIツール (後述) |

### CLIツール (bin/)

| コマンド | 説明 |
| --- | --- |
| `git-new-feature <name>` | ブランチ作成 (`-f` fix / `-d` docs / `-r` refactor / `-c` chore) |
| `git-cleanup-branch` | マージ済みブランチ削除 (ローカル+リモート) |
| `gh-setup-repo` | GitHubリポジトリ設定 (ブランチ保護、PR後自動削除) |

### Claude Code設定 (claude/)

`install.sh` で `~/.claude/` にリンクされる。`global_CLAUDE.md` は `CLAUDE.md` にリネーム。

| ディレクトリ | 内容 |
| --- | --- |
| `commands/` | スラッシュコマンド (`/project-init`, `/feat`, `/fix` 等) |
| `hooks/` | 自動処理 (破壊的操作ブロック、セッション管理、コンテキスト監視) |
| `rules/` | 常時適用ルール |
| `skills/` | オンデマンド手順 |
| `templates/` | `/project-init` 用言語別テンプレート |
| `vendor/` | 外部スキル (vercel-labs/agent-skills)。`install.sh` が自動 clone、SessionStart hook で1日1回更新 |

新ファイル追加は `claude/` に配置して `git add` するだけ。`install.sh` が `git ls-files` で自動検出する。

## プラットフォーム

| 環境 | Git設定 |
| --- | --- |
| macOS | `.gitconfig.private` |
| Linux / WSL | `.gitconfig.work` |
