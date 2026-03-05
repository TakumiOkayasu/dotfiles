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
| `bin/` | 実行可能スクリプト (後述) |
| `claude-config/` | Claude Code設定ファイル (後述) |
| `claude-templates/` | Claude Code プロジェクトテンプレート (後述) |
| `install.sh` | シンボリックリンク作成スクリプト |

### 実行可能スクリプト (bin/)

| ファイル | 説明 |
|----------|------|
| `claude-init` | Claude Code プロジェクト初期化ツール |
| `git-new-feature` | 機能ブランチ作成 (feat/fix/docs/refactor/chore) |
| `git-cleanup-branch` | マージ済みブランチ削除 (ローカル・リモート両方) |
| `gh-setup-repo` | GitHubリポジトリ初期設定 (ブランチ保護、自動削除) |

`install.sh` 実行時に PATH に追加されます (.bashrc に設定済み)。

### Claude Code設定 (claude-config/)

| ファイル | 配置先 | 説明 |
|----------|--------|------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude Code用グローバル指示ファイル |
| `settings.json` | `~/.claude/settings.json` | Claude Code権限・hooks設定 |
| `skills/` | `~/.claude/skills/` | Claude Codeスキル定義 (6種類) |
| `hooks/` | `~/.claude/hooks/` | Claude Code自動リマインドhooks |

新しいファイルを追加する場合は `claude-config/` に配置して `git add` するだけでOK。
install.sh が `git ls-files` で自動検出してリンクを作成します。

#### ルール (常時適用, 2件)

`hallucination-prevention`, `hierarchical-architecture`

#### スキル (オンデマンド, 4件)

`systematic-debugging`, `test-driven-development`, `consultation`, `failure-logging`

#### Hooks

Claude Codeの動作時に自動でリマインドを表示:

| ファイル | トリガー | 内容 |
|----------|----------|------|
| `session-start-reminder.sh` | セッション開始時 | CLAUDE.mdの重要ルールをリマインド |
| `git-commit-push-block.sh` | git commit/push実行前 | **ブロック**: commit/pushはユーザーのみ |
| `main-branch-code-warning.sh` | コード編集前 | mainブランチでの編集を警告 |
| `git-post-command-reminder.sh` | git操作後 | マージ済みローカルブランチを自動削除 |
| `branch-from-main-check.sh` | ブランチ作成後 | mainから分岐していなければ警告 |
| `doc-consistency-reminder.sh` | ドキュメント編集後 | 関連ドキュメントとの整合性確認を促す |

### プロジェクトテンプレート (claude-templates/)

`claude-init` コマンドで使用するテンプレート。

| ディレクトリ | 内容 |
|--------------|------|
| `base/` | 共通テンプレート (commands, tasks) |
| `lang/` | 言語別テンプレート |

対応言語: `python`, `typescript`, `cpp`, `go`, `php-laravel`, `php-cakephp`

#### claude-init の使い方

新しいプロジェクトでClaude Code用の設定を初期化:

```bash
claude-init python        # Python用テンプレートで初期化
claude-init typescript    # TypeScript用テンプレートで初期化
claude-init --list        # 利用可能なテンプレート一覧
claude-init --help        # ヘルプ表示
```

#### Claude設定の更新 (update-claude-config.sh)

リポジトリをクローンせずにClaude設定のみを更新したい場合:

```bash
curl -o update-claude-config.sh https://raw.githubusercontent.com/TakumiOkayasu/dotfile-work/refs/heads/main/update-claude-config.sh
chmod +x update-claude-config.sh
./update-claude-config.sh
```

## 使い方

### インストール

```bash
./install.sh              # 対話モード (カテゴリ/ファイルを選択)
./install.sh -f           # 全ファイルをインストール (確認なし)
./install.sh -n           # ドライラン (変更内容をプレビュー)
./install.sh -u           # アンインストール (シンボリックリンクを削除)
./install.sh -h           # ヘルプを表示
```

### カテゴリ

| カテゴリ | 内容 |
|----------|------|
| shell | `.bashrc`, `.shell_aliases` |
| git | `.gitconfig`, `.git-completion.bash`, `.git-prompt.sh`, `.gitignore` |
| vim | `.vimrc` |
| claude | `claude-config/` 内のファイル全て |
| bin | `bin/` 内の実行可能スクリプト |

### インストール例

```bash
# ドライランで確認してから実行
./install.sh -n -f    # 何がインストールされるか確認
./install.sh -f       # 実際にインストール

# 設定を反映
source ~/.bashrc
```

### GitHubリポジトリの初期設定 (手動)

新しいGitHubリポジトリを作成したら、以下を実行:

```bash
gh-setup-repo              # 現在のリポジトリに設定を適用
gh-setup-repo --check      # 現在の設定を確認
```

設定内容:
- mainブランチの保護 (直接push禁止、PR必須)
- PRマージ後のリモートブランチ自動削除

**注意**: ブランチ保護はGitHub API の制限により失敗する場合があります。
その場合は GitHub Web UI から手動で設定してください:
Settings → Branches → Add rule → Branch name pattern: `main`

### アンインストール

```bash
./install.sh -u       # シンボリックリンクを削除 (バックアップがあれば復元)
```

## 注意事項

- 既存ファイルは自動でバックアップされます (`.bak` 拡張子が付与される)
- シンボリックリンクが既に存在する場合は再作成されます
- `.claude/` ディレクトリはローカルデータ (credentials, history等) を含むため `.gitignore` で無視されています
