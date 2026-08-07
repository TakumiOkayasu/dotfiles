# dotfiles

個人用dotfilesリポジトリ。Shell/Git/Vim設定とClaude Code/Codex設定を、`install.sh` でシンボリックリンクまたは通常ファイルとして配置する。

## クイックスタート

```bash
./install.sh -n           # ドライラン (プレビュー)
./install.sh -f           # 全ファイルインストール
source ~/.bashrc          # 設定反映
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
| `config/git/` | `~/`, `~/.config/git/` | Git設定、補完、global ignore、attributes |
| `config/vim/` | `~/` | .vimrc |
| `claude/` | `~/.claude/` | Claude Code設定一式 (後述) |
| `codex/` | `~/.codex/` | Codex設定一式 (AGENTS.md, SUBAGENTS.md, hooks, rules)。skills は plugin 配布用 source |
| `common/` | `~/.claude/`, Codex向け生成物 | Claude/Codexの共有正本 |
| `bin/` | `~/.local/bin/` | CLIツール (後述) |

### CLIツール (bin/)

| コマンド | 説明 |
| --- | --- |
| `claude-init-project` | 現在のGitリポジトリへ `.claude/notes` と `scratch` の雛形を配置 |
| `git-new-feature <name>` | ブランチ作成 (`-f` fix / `-d` docs / `-r` refactor / `-c` chore) |
| `git-cleanup-branch` | マージ済みブランチ削除 (ローカル+リモート) |
| `gh-setup-repo` | GitHubリポジトリ設定 (ブランチ保護、PR後自動削除) |

Codex workflow は plugin skill (`$feat`, `$fix`, `$deep-review` など) から起動する。旧 `codex-cmd` と個別wrapperは配布しない。

### Claude Code設定 (claude/ + common/)

`install.sh` で `claude/` の固有設定と `common/` の共有資産が `~/.claude/` にリンクされる。`global_CLAUDE.md` は `CLAUDE.md` にリネーム。

| ディレクトリ | 内容 |
| --- | --- |
| `common/commands/` | Claude配置とCodex変換で共有するスラッシュコマンド |
| `common/rules/` | Claude配置とCodex変換で共有するルール |
| `common/skills/` | Claude配置とCodex変換で共有するオンデマンド手順 |
| `claude/hooks/` | Claude固有の自動処理 |
| `claude/vendor/` | 外部スキル (vercel-labs/agent-skills)。`install.sh` が自動cloneし、SessionStart hookで更新 |

共有するcommand/rule/skillは `common/` に追加する。Claude固有の設定、hook、agentは `claude/` に追加する。`install.sh` はtracked fileを自動検出する。

### Codex設定 (codex/)

`install.sh` でCodex設定を `~/.codex/` に配置する。hook定義は初回生成される `~/.codex/config.toml` のinline TOMLから読み込む。旧 `~/.codex/hooks.json` は新規配置しない。

| ディレクトリ / ファイル | 内容 |
| --- | --- |
| `global_AGENTS.md` | `~/.codex/AGENTS.md` にリネームして配置される Codex 常時指示 |
| `SUBAGENTS.md` | `~/.codex/SUBAGENTS.md` に配置される subagent mechanics |
| `config.toml.template` | 初回生成する `~/.codex/config.toml` の雛形。hook定義を含む |
| `hooks/` | hook 実体スクリプト |
| `skills/` | plugin 配布用 source。`install.sh` では `~/.agents/skills/` に重複配置しない |
| `rules/` | 参照ルール。常時ロード前提にはしない |

Codex設定の使い方は `codex/README.md` を参照。初回起動時に hook レビュー警告が出た場合は、Codex 上で `/hooks` を開いて許可する。

### Codex skills の配置

共有skillは `common/skills/` を正本にし、Codex固有skillは `codex/skills/` で管理する。`codex/skills/` には共有skillのCodex向け生成viewも含まれる。bundleは `plugins/dotfile-work-codex*` に生成され、Git管理しない。

`scripts/claude-command-map.json` はcommand変換、許可するnested resource、Codex固有skill、core/extra分類の正本である。生成/同期/検証scriptは同じmanifestを読み、分類のずれを検出する。rules indexとbundleも共通rendererから生成し、verifierが元ruleとの一致を検査する。

標準 workflow skills を再生成して plugin bundle に反映する場合は、リポジトリルートで次を実行する。

```bash
uv run python scripts/generate-standard-workflow-skills.py --repo . --overwrite
uv run python scripts/port-claude-assets-to-codex.py --repo . --overwrite --no-backup --prune
uv run python scripts/apply-codex-performance-profile.py --repo .
uv run python scripts/sync-codex-plugin.py --repo . --clean
uv run python scripts/verify-codex-plugin.py --repo .
```

生成済みの `codex/skills/` をbundleへ反映するだけなら `sync-codex-plugin.py` と `verify-codex-plugin.py` だけでよい。

個人環境の `~/.codex/plugins/` と `~/.agents/plugins/marketplace.json` まで配置する場合は次を実行する。

```bash
uv run python scripts/install-codex-plugin-personal.py --repo .
```

配置後は Codex を再起動し、`/plugins` で `dotfile-work-codex` を有効化する。`dotfile-work-codex-extra` は必要な時だけ有効化する。

## Git設定の配置

Git設定は環境別設定と共通設定を分けて配置する。

| 配置先 | 形式 | 生成元 |
| --- | --- | --- |
| `~/.gitconfig` | シンボリックリンク | Linux/WSLでは `config/git/.gitconfig.work`、macOSでは `config/git/.gitconfig.private` |
| `~/.gitconfig.common` | 通常ファイル | `config/git/.gitconfig.common` のコピー |
| `~/.config/git/ignore` | 通常ファイル | `config/git/.gitignore.common` と環境別variantの結合 |
| `~/.config/git/attributes` | シンボリックリンク | `config/git/.gitattributes` |

`~/.gitconfig` は `~/.gitconfig.common` をincludeする。common設定とglobal ignoreはcopy/生成ファイルなので、正本を変更した後は `./install.sh` を再実行して反映する。

## プラットフォーム

| 環境 | Git設定 |
| --- | --- |
| macOS | `.gitconfig.private` |
| Linux / WSL | `.gitconfig.work` |
