# Claude Code 設定セットアップガイド

このガイドでは、dotfile-work リポジトリの Claude Code 設定を `~/.claude` (Windows: `%USERPROFILE%\.claude`) にシンボリックリンクとして配置する方法を説明します。

## 📋 概要

このセットアップスクリプトは、以下のファイル/ディレクトリのシンボリックリンクを作成します：

- `CLAUDE.md` - Claude Codeの基本設定とガイドライン
- `settings.json` - Claude Codeの設定ファイル
- `skills/` - カスタムスキルディレクトリ
- `hooks/` - フックスクリプト (存在する場合)

シンボリックリンクを使用することで、このリポジトリの設定を更新すると自動的に `~/.claude` の設定も更新されます。

---

## 🚀 セットアップ方法

### Linux / macOS / WSL の場合

1. **リポジトリのディレクトリに移動**

   ```bash
   cd /path/to/dotfile-work
   ```

2. **セットアップスクリプトを実行**

   ```bash
   ./setup-claude-config.sh
   ```

3. **実行結果の確認**

   スクリプトが以下の操作を実行します：
   - `~/.claude` ディレクトリを作成 (存在しない場合)
   - 既存の設定ファイルをバックアップ (タイムスタンプ付き)
   - シンボリックリンクを作成
   - 最終的なリンク状態を表示

### Windows の場合

1. **PowerShellを開く**

   - スタートメニューから「PowerShell」を検索して起動
   - 注意: 管理者権限は基本的に不要ですが、シンボリックリンク作成に失敗する場合は「管理者として実行」を試してください

2. **リポジトリのディレクトリに移動**

   ```powershell
   cd C:\path\to\dotfile-work
   ```

3. **実行ポリシーの確認 (初回のみ)**

   PowerShellスクリプトの実行が制限されている場合があります。以下のコマンドで現在のポリシーを確認：

   ```powershell
   Get-ExecutionPolicy
   ```

   `Restricted` の場合、以下のコマンドで一時的に許可：

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. **セットアップスクリプトを実行**

   ```powershell
   .\setup-claude-config.ps1
   ```

5. **実行結果の確認**

   スクリプトが以下の操作を実行します：
   - `%USERPROFILE%\.claude` ディレクトリを作成 (存在しない場合)
   - 既存の設定ファイルをバックアップ (タイムスタンプ付き)
   - シンボリックリンクを作成
   - 最終的なリンク状態を表示

---

## ✅ セットアップ後の確認方法

### Linux / macOS / WSL の場合

動作確認用スクリプトを実行：

```bash
./check-claude-config.sh
```

または、手動で確認：

```bash
ls -la ~/.claude
```

シンボリックリンクは `->` で表示されます：

```
lrwxrwxrwx 1 user user   42 Jan  6 12:00 CLAUDE.md -> /path/to/dotfile-work/claude-config/CLAUDE.md
lrwxrwxrwx 1 user user   48 Jan  6 12:00 settings.json -> /path/to/dotfile-work/claude-config/settings.json
lrwxrwxrwx 1 user user   43 Jan  6 12:00 skills -> /path/to/dotfile-work/claude-config/skills
```

### Windows の場合

PowerShellで確認：

```powershell
Get-ChildItem $env:USERPROFILE\.claude | Select-Object Name, LinkType, Target
```

シンボリックリンクは `LinkType` が `SymbolicLink` と表示されます。

---

## 🔧 トラブルシューティング

### シンボリックリンク作成に失敗する場合

#### Windows の場合

1. **開発者モードを有効にする**

   Windows 10 バージョン 1703 以降では、開発者モードを有効にすることで管理者権限なしでシンボリックリンクを作成できます：

   - 設定 > 更新とセキュリティ > 開発者向け > 開発者モード をオンにする

2. **管理者権限で実行**

   開発者モードを有効にしたくない場合は、PowerShellを「管理者として実行」してスクリプトを実行してください。

#### Linux / macOS / WSL の場合

- スクリプトに実行権限があるか確認：
  ```bash
  chmod +x setup-claude-config.sh
  ```

- ディスク容量が十分にあるか確認：
  ```bash
  df -h ~
  ```

### 既存設定のバックアップを確認する方法

セットアップスクリプトは、既存のファイルやディレクトリを `backup_yyyyMMdd_HHmmss` という形式でバックアップします。

#### Linux / macOS / WSL の場合

```bash
ls -la ~/.claude/*.backup_*
```

#### Windows の場合

```powershell
Get-ChildItem $env:USERPROFILE\.claude\*.backup_*
```

バックアップを復元する場合は、以下のようにリネームします：

```bash
# Linux / macOS / WSL
mv ~/.claude/settings.json.backup_20260106_120000 ~/.claude/settings.json

# Windows (PowerShell)
Move-Item $env:USERPROFILE\.claude\settings.json.backup_20260106_120000 $env:USERPROFILE\.claude\settings.json
```

### リンクを解除する方法

シンボリックリンクを削除したい場合：

#### Linux / macOS / WSL の場合

```bash
# 個別に削除
rm ~/.claude/CLAUDE.md
rm ~/.claude/settings.json
rm ~/.claude/skills
rm ~/.claude/hooks

# または、すべて削除
rm -rf ~/.claude
```

#### Windows の場合

```powershell
# 個別に削除
Remove-Item $env:USERPROFILE\.claude\CLAUDE.md
Remove-Item $env:USERPROFILE\.claude\settings.json
Remove-Item $env:USERPROFILE\.claude\skills
Remove-Item $env:USERPROFILE\.claude\hooks

# または、すべて削除
Remove-Item $env:USERPROFILE\.claude -Recurse -Force
```

注意: シンボリックリンクを削除しても、元のファイル (dotfile-work/claude-config 内) は削除されません。

### hooks ディレクトリが存在しないという警告が表示される場合

`hooks` ディレクトリはオプションです。必要に応じて後で追加できます：

```bash
# Linux / macOS / WSL
mkdir -p /path/to/dotfile-work/claude-config/hooks

# Windows (PowerShell)
New-Item -ItemType Directory -Path C:\path\to\dotfile-work\claude-config\hooks
```

作成後、再度セットアップスクリプトを実行すれば、hooksディレクトリのリンクも作成されます。

---

## 📝 セットアップ完了後の使用方法

セットアップが完了したら、Claude Codeを起動するだけで自動的に `~/.claude` の設定が読み込まれます。

設定を変更する場合は、このリポジトリ内の `claude-config` ディレクトリを編集してください：

```bash
# Linux / macOS / WSL
cd /path/to/dotfile-work/claude-config
vim CLAUDE.md

# Windows
cd C:\path\to\dotfile-work\claude-config
notepad CLAUDE.md
```

編集内容はシンボリックリンクを通じて `~/.claude` にも即座に反映されます。

---

## 🤝 サポート

問題が発生した場合は、以下を確認してください：

1. dotfile-work リポジトリが最新版か
2. シンボリックリンクが正しく作成されているか (上記の確認方法を参照)
3. Claude Codeのバージョンが最新か

それでも解決しない場合は、Issue を作成してください。
