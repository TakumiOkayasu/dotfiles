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
| `claude-config/` | Claude Code設定ファイル (後述) |
| `install.sh` | シンボリックリンク作成スクリプト |

### Claude Code設定 (claude-config/)

| ファイル | 配置先 | 説明 |
|----------|--------|------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | Claude Code用グローバル指示ファイル |
| `settings.json` | `~/.claude/settings.json` | Claude Code権限設定 |

新しいファイルを追加する場合は `claude-config/` に配置して `git add` するだけでOK。
install.sh が `git ls-files` で自動検出してリンクを作成します。

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

### インストール例

```bash
# ドライランで確認してから実行
./install.sh -n -f    # 何がインストールされるか確認
./install.sh -f       # 実際にインストール

# 設定を反映
source ~/.bashrc
```

### アンインストール

```bash
./install.sh -u       # シンボリックリンクを削除 (バックアップがあれば復元)
```

## 注意事項

- 既存ファイルは自動でバックアップされます (`.bak` 拡張子が付与される)
- シンボリックリンクが既に存在する場合は再作成されます
- `.claude/` ディレクトリはローカルデータ (credentials, history等) を含むため `.gitignore` で無視されています
