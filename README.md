# dotfiles

個人用dotfilesリポジトリ。Shell/Git/Vim設定とClaude Code/Codex設定を `install.sh` でシンボリックリンク配置する。

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
| `codex/` | `~/.codex/` | Codex設定一式 (hooks.json, hooks, skills, rules) |
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
| `commands/` | スラッシュコマンド (`/feat`, `/fix`, `/commit`, `/code-review`) |
| `hooks/` | 自動処理 (破壊的操作ブロック、セッション管理、コンテキスト監視) |
| `rules/` | 常時適用ルール |
| `skills/` | オンデマンド手順 |
| `vendor/` | 外部スキル (vercel-labs/agent-skills)。`install.sh` が自動 clone、SessionStart hook で1日1回更新 |

新ファイル追加は `claude/` に配置して `git add` するだけ。`install.sh` が `git ls-files` で自動検出する。

### Codex設定 (codex/)

`install.sh` で `~/.codex/` にリンクされる。Codex の自動 hook は `~/.codex/hooks.json` が読み込まれる。

| ディレクトリ / ファイル | 内容 |
| --- | --- |
| `global_AGENTS.md` | `~/.codex/AGENTS.md` にリネームして配置される Codex 常時指示 |
| `hooks.json` | Codex hook 定義 (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `PreCompact`, `SessionStart`) |
| `hooks/` | hook 実体スクリプト |
| `skills/` | Codex skill |
| `rules/` | 参照ルール |
| `prompts/commands/` | Claude slash command の代替プロンプト |

Codex設定の使い方は `codex/README.md` を参照。初回起動時に hook レビュー警告が出た場合は、Codex 上で `/hooks` を開いて許可する。

## プラットフォーム

| 環境 | Git設定 |
| --- | --- |
| macOS | `.gitconfig.private` |
| Linux / WSL | `.gitconfig.work` |
