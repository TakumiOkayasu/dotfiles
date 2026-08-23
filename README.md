# dotfile-work

個人開発・業務環境で使う dotfiles と Claude Code / Codex 設定を管理する。

## セットアップ

```bash
git clone git@github.com:TakumiOkayasu/dotfile-work.git
cd dotfile-work
./install.sh
```

source ~/.bashrc          # 設定反映
./install.sh -u           # アンインストール (リンク削除、バックアップ復元)

> **Windows**: WSL内で実行する。例: PowerShellから `wsl bash ./install.sh -f`

## 構成

| ディレクトリ | 配置先 / 用途 |
| --- | --- |
| `config/shell/` | `~/` - bash/zsh/fish設定、共通aliases/env |
| `config/git/` | `~/`, `~/.config/git/` - Git設定、補完、global ignore、attributes |
| `config/vim/` | `~/` - .vimrc |
| `claude/` | `~/.claude/` - Claude Code固有の入力 (agent, hook, settings) |
| `codex/` | `~/.codex/` - Codex固有の入力 (AGENTS.md, SUBAGENTS.md, agent, hook) |
| `common/` | install時にClaude/Codex形式へ変換 - command/rule/skillの共有正本 |
| `bin/` | `~/.local/bin` - CLIツール |

### CLIツール (bin/)

| コマンド | 説明 |
| --- | --- |
| `ai-init-project` | 現在のGitリポジトリへruntime-neutralな `.ai/` knowledge stateを初期化 |
| `claude-init-project` | 現在のGitリポジトリへ `.claude/notes` と `scratch` の雛形を配置 |
| `git-new-feature <name>` | ブランチ作成 (`-f` fix / `-d` docs / `-r` refactor / `-c` chore) |
| `git-cleanup-branch` | マージ済みブランチ削除 (ローカル+リモート) |
| `gh-setup-repo` | GitHubリポジトリ設定 (ブランチ保護、PR後自動削除) |

`ai-init-project` は `.ai/state/`, `.ai/inbox/`, `.ai/knowledge/` と `manifest.toml` を作る。`.ai/` は Claude Code / Codex 共通のdurable knowledgeだけを持ち、`.claude/`, `.codex/`, `claude_tmp/`, `codex_tmp/` のruntime stateやscratchとは分離する。既存の `.ai/` に本workflowのmanifestが無い場合は、他toolの領域を奪わないよう初期化を拒否する。

`.ai/` はglobal gitignore対象で、元projectのrepositoryにはcommitしない。将来のcross-project collectorは `~/prog/` 直下の各projectから `.ai/` だけを収集し、`.claude/`, `.codex/`, `claude_tmp/`, `codex_tmp/` を直接exportしない。各runtimeの有用な発見は、必要な要点だけ `.ai/inbox/` へharvestしてから共有する。

Codex workflow は plugin skill (`$feat`, `$fix`, `$deep-review` など) から起動する。旧 `codex-cmd` と個別wrapperは配布しない。

### Claude Code設定 (claude/ + common/)

`install.sh` はtrackedな `claude/` と `common/` だけを読み、Claude用viewを `.generated/ai-assets/claude/` に生成・検証してから `~/.claude/` へリンクする。`global_CLAUDE.md` は `CLAUDE.md` にリネームされる。

| ディレクトリ | 内容 |
| --- | --- |
| `common/commands/` | Claude配置とCodex変換で共有するスラッシュコマンド |
| `common/rules/` | Claude配置とCodex変換で共有するルール |
| `common/skills/` | Claude配置とCodex変換で共有するオンデマンド手順 |
| `claude/hooks/` | Claude固有の自動処理 |
| `claude/vendor/` | 外部スキル (vercel-labs/agent-skills)。`install.sh` が自動cloneし、SessionStart hookで更新 |

共有するcommand/rule/skillは `common/` にだけ追加する。Claude固有の設定、hook、agentは `claude/` に追加する。未追跡ファイルは生成入力に含めない。

### Codex設定 (codex/)

`install.sh` は同じ `common/` 正本をCodex形式へ変換し、rules index/bundle、skill metadata、plugin bundleまで検証した後で `~/.codex/` と `~/.agents/plugins/marketplace.json` に配置する。hook定義は初回生成される `~/.codex/config.toml` のinline TOMLから読み込む。旧 `~/.codex/hooks.json` は新規配置しない。

| ディレクトリ / ファイル | 内容 |
| --- | --- |
| `global_AGENTS.md` | `~/.codex/AGENTS.md` にリネームして配置される Codex 常時指示 |
| `SUBAGENTS.md` | `~/.codex/SUBAGENTS.md` に配置する subagent mechanics |
| `config.toml.template` | 初回生成する `~/.codex/config.toml` の雛形。hook定義を含む |
| `hooks/` | hook 実体スクリプト |
| `skills/` | Codex固有skillの正本だけを置く。共有skillと標準workflowはinstall時生成 |
| `.generated/ai-assets/codex/rules/` | Git管理しない生成view。正本は `common/rules/` と生成script |

Codex設定の使い方は `codex/README.md` を参照。初回起動時に hook のレビュー警告が出た場合は、Codex 上で `/hooks` を開いて許可する。

### Codex skills の配置

共有skillは `common/skills/` を正本にし、Codex固有skillだけを `codex/skills/` で管理する。Claude/Codex向けview、標準workflow、rules集約、`plugins/dotfile-work-codex*` は `.generated/ai-assets/` に生成し、Git管理しない。

`scripts/claude-command-map.json` はcommand変換、許可するnested resource、Codex固有skill、core/extra分類の正本である。生成/同期/検証scriptは同じmanifestを読み、分類のずれを検出する。rules indexとbundleも共通rendererから生成し、verifierが元ruleとの一致を検査する。

通常は `install.sh` が自動生成する。開発中に生成結果だけを確認する場合は次を実行する。

```bash
python3 scripts/generate-ai-assets.py --repo .
```

生成は一時treeで全pipelineを完走し、成功した場合だけ `.generated/ai-assets` を差し替える。途中で失敗した場合は直前の完全なtreeを保持する。

Codexを選択したinstallでは `~/.codex/plugins/` と `~/.agents/plugins/marketplace.json` も同時に配置する。`/plugins` で `dotfile-work-codex` を有効化し、`dotfile-work-codex-extra` は必要な時だけ有効化する。

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
