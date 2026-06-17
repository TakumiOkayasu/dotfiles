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
| `config/git/` | `~/`, `~/.config/git/` | .gitconfig (work/private)、補完。gitignore/gitattributes は `~/.config/git/ignore`・`~/.config/git/attributes` |
| `config/vim/` | `~/` | .vimrc |
| `claude/` | `~/.claude/` | Claude Code設定一式 (後述) |
| `codex/` | `~/.codex/` | Codex設定一式 (AGENTS.md, SUBAGENTS.md, hooks, rules)。skills は plugin 配布用 source |
| `bin/` | `~/.local/bin/` | CLIツール (後述) |

### CLIツール (bin/)

| コマンド | 説明 |
| --- | --- |
| `git-new-feature <name>` | ブランチ作成 (`-f` fix / `-d` docs / `-r` refactor / `-c` chore) |
| `git-cleanup-branch` | マージ済みブランチ削除 (ローカル+リモート) |
| `gh-setup-repo` | GitHubリポジトリ設定 (ブランチ保護、PR後自動削除) |
| `codex-cmd <name> [args]` | Codex 用プロンプトコマンド起動 (`feat`, `fix`, `deep-review`, `code-review`, `commit`) |
| `codex-feat` / `codex-fix` / `codex-code-review` / `codex-deep-review` / `codex-commit` | Claude Code の slash command に近い Codex 起動ショートカット |

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
| `SUBAGENTS.md` | `~/.codex/SUBAGENTS.md` に配置される subagent mechanics |
| `hooks.json` | Codex hook 定義 (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `PreCompact`, `SessionStart`) |
| `hooks/` | hook 実体スクリプト |
| `skills/` | plugin 配布用 source。`install.sh` では `~/.agents/skills/` に重複配置しない |
| `rules/` | 参照ルール。常時ロード前提にはしない |
| `reference/` | 参照用ファイル。install対象外 |
| `prompts/commands/` | Claude slash command の代替プロンプト (`codex-cmd` / `codex-feat` から利用) |

Codex設定の使い方は `codex/README.md` を参照。初回起動時に hook レビュー警告が出た場合は、Codex 上で `/hooks` を開いて許可する。

### Codex skills の配置

Codex skill は `codex/skills/<name>/SKILL.md` を正本にし、ローカル plugin bundle へ配置して使う。bundle は `plugins/dotfile-work-codex*` に生成され、Git 管理しない。

標準 workflow skills を再生成して plugin bundle に反映する場合は、リポジトリルートで次を実行する。

```bash
python3 scripts/generate-standard-workflow-skills.py --repo . --overwrite
python3 scripts/sync-codex-plugin.py --repo . --clean
python3 scripts/verify-codex-plugin.py --repo .
```

既存の `codex/skills/` を bundle に反映するだけなら `sync-codex-plugin.py` と `verify-codex-plugin.py` だけでよい。

個人環境の `~/.codex/plugins/` と `~/.agents/plugins/marketplace.json` まで配置する場合は次を実行する。

```bash
python3 scripts/install-codex-plugin-personal.py --repo .
```

配置後は Codex を再起動し、`/plugins` で `dotfile-work-codex` を有効化する。`dotfile-work-codex-extra` は必要な時だけ有効化する。

## プラットフォーム

| 環境 | Git設定 |
| --- | --- |
| macOS | `.gitconfig.private` |
| Linux / WSL | `.gitconfig.work` |
