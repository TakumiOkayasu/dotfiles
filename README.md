# dotfiles

個人用dotfilesリポジトリ

## 含まれるファイル

| ディレクトリ | 内容 |
|--------------|------|
| `config/shell/` | シェル設定 (bash, zsh, fish, 共通aliases/env) |
| `config/git/` | Git設定 (.gitconfig, .gitignore, 補完/プロンプト) |
| `config/vim/` | Vim設定 (.vimrc) |
| `bin/` | 実行可能スクリプト (後述) |
| `claude/` | Claude Code設定・テンプレート (後述) |
| `install.sh` | シンボリックリンク作成スクリプト (POSIX sh) |

### 実行可能スクリプト (bin/)

| ファイル | 説明 |
|----------|------|
| `git-new-feature` | 機能ブランチ作成 (feat/fix/docs/refactor/chore) |
| `git-cleanup-branch` | マージ済みブランチ削除 (ローカル・リモート両方) |
| `gh-setup-repo` | GitHubリポジトリ初期設定 (ブランチ保護、自動削除) |

`install.sh` 実行時に PATH に追加されます (common.sh に設定済み)。

### Claude Code設定 (claude/)

| ファイル | 配置先 | 説明 |
|----------|--------|------|
| `global_CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude Code用グローバル指示ファイル |
| `settings.json` | `~/.claude/settings.json` | Claude Code権限・hooks設定 |
| `rules/` | `~/.claude/rules/` | 常時適用の制約・規約 |
| `skills/` | `~/.claude/skills/` | オンデマンドの作業手順 |
| `bin/` | `~/.claude/bin/` | CLIツール |
| `hooks/` | `~/.claude/hooks/` | Claude Code自動リマインドhooks |
| `templates/` | `~/.claude/templates/` | /project-init テンプレート |

新しいファイルを追加する場合は `claude/` に配置して `git add` するだけでOK。
install.sh が `git ls-files` で自動検出してリンクを作成します。

#### ルール (常時適用)

`hallucination-prevention`, `hierarchical-architecture`

#### スキル (オンデマンド)

`systematic-debugging`, `test-driven-development`, `consultation`, `failure-logging`

#### Hooks

Claude Codeの動作時に自動でリマインドを表示。代表的なhooks (詳細はCLAUDE.mdを参照):

| ファイル | トリガー | 内容 |
|----------|----------|------|
| `session-start-reminder.sh` | セッション開始時 | CLAUDE.mdの重要ルールをリマインド |
| `git-commit-push-block.sh` | git commit/push実行前 | **ブロック**: commit/pushはユーザーのみ |
| `main-branch-code-warning.sh` | コード編集前 | mainブランチでの編集を警告 |
| `commit-checkpoint.sh` | git commit後 | 進捗の自動チェックポイント |
| `context-monitor.sh` | 全Bash操作後 | コンテキスト使用量監視 |

### プロジェクトテンプレート (claude/templates/)

`/project-init` スラッシュコマンドで使用するテンプレート。

| ディレクトリ | 内容 |
|--------------|------|
| `lang/` | 言語別 CLAUDE.md テンプレート |
| `rules/common/` | 共通ルール (security, design-principles, error-handling) |
| `rules/<lang>/` | 言語別ルール (code-style, testing) |

対応言語 (使用頻度順): `java`, `cpp`, `typescript`, `python`, `go`, `c`, `swift`, `php-cakephp`, `php-laravel`, `dart`, `kotlin`, `rust`, `ruby`, `csharp`

エイリアス入力にも対応 (例: `ts`→typescript, `py`→python, `c++`→cpp, `cake`→php-cakephp)

#### /project-init の使い方

Claude Codeセッション内で実行:

```
/project-init               # プロジェクトから言語を自動検出して初期化
/project-init python        # Python用テンプレートで初期化
/project-init ts            # エイリアスも使用可能
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
| shell | `config/shell/` (bash, zsh, fish, 共通設定) |
| git | `config/git/` (.gitconfig, .gitignore, 補完/プロンプト) |
| vim | `config/vim/.vimrc` |
| claude | `claude/` 内のファイル全て |
| bin | `bin/` 内の実行可能スクリプト |

### インストール例

```bash
# ドライランで確認してから実行
./install.sh -n -f    # 何がインストールされるか確認
./install.sh -f       # 実際にインストール

# 設定を反映
source ~/.bashrc
```

### GitHubリポジトリの初期設定

新しいGitHubリポジトリを作成したら、以下を実行:

```bash
gh-setup-repo              # 現在のリポジトリに設定を適用
gh-setup-repo --check      # 現在の設定を確認
```

設定内容:
- mainブランチの保護 (直接push禁止、PR必須)
- PRマージ後のリモートブランチ自動削除

ブランチ保護は `gh-setup-repo` で手動設定が必要です。

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
