#Requires -Version 5.1
<#
.SYNOPSIS
    Windows用 dotfiles インストーラー
    dotfiles のシンボリックリンクをホームディレクトリに作成します

.DESCRIPTION
    dotfiles リポジトリからユーザーのホームディレクトリへシンボリックリンクを作成します。
    対話モード、強制モード、ドライランモード、アンインストールモードをサポートしています。

.PARAMETER Force
    確認なしで全ファイルをインストール

.PARAMETER DryRun
    変更を加えずにプレビューを表示

.PARAMETER Uninstall
    このインストーラーで作成したシンボリックリンクを削除

.PARAMETER Help
    ヘルプメッセージを表示

.EXAMPLE
    .\install.ps1              # 対話モードでインストール
    .\install.ps1 -Force       # 全てをインストール
    .\install.ps1 -DryRun      # インストール内容をプレビュー
    .\install.ps1 -Uninstall   # シンボリックリンクを削除
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$Help
)

# Strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Script directory
$script:DotfilesDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Counters
$script:CountCreated = 0
$script:CountSkipped = 0
$script:CountBackup = 0
$script:CountRemoved = 0

# Selected items
$script:SelectedIndices = [System.Collections.ArrayList]@()
$script:ClaudeSelected = $false

#region Color Output

function Write-Success { param([string]$Message) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-Skip { param([string]$Message) Write-Host "[--] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-Err { param([string]$Message) Write-Host "[NG] " -ForegroundColor Red -NoNewline; Write-Host $Message }
function Write-Info { param([string]$Message) Write-Host "[->] " -ForegroundColor Blue -NoNewline; Write-Host $Message }
function Write-Header { param([string]$Message) Write-Host "`n$Message" -ForegroundColor Cyan }

#endregion

#region File Definitions

# GitConfig source will be set dynamically based on environment selection
$script:GitConfigSource = ".gitconfig.private"
$script:IsWorkEnvironment = $false

$script:FileDefs = @(
    @{ Category = "shell"; Source = ".bashrc"; Dest = "$env:USERPROFILE\.bashrc"; Description = "Bash設定とプロンプト設定" }
    @{ Category = "shell"; Source = ".shell_aliases"; Dest = "$env:USERPROFILE\.shell_aliases"; Description = "シェルエイリアス (共通コマンド)" }
    @{ Category = "git"; Source = ".git-completion.bash"; Dest = "$env:USERPROFILE\.git-completion.bash"; Description = "Gitコマンド補完" }
    @{ Category = "git"; Source = ".git-prompt.sh"; Dest = "$env:USERPROFILE\.git-prompt.sh"; Description = "プロンプトにGitブランチ情報を表示" }
    @{ Category = "git"; Source = ".gitignore"; Dest = "$env:USERPROFILE\.config\git\ignore"; Description = "グローバルgitignoreパターン" }
    @{ Category = "vim"; Source = ".vimrc"; Dest = "$env:USERPROFILE\.vimrc"; Description = "Vimエディタ設定" }
)

$script:Categories = @{
    "shell" = "シェル設定 (bashrc, エイリアス)"
    "git" = "Git設定と補完"
    "vim" = "Vimエディタ設定"
    "claude" = "Claude Code AIアシスタント設定"
}

#endregion

#region Claude Config Functions

function Get-ClaudeConfigFiles {
    Push-Location $script:DotfilesDir
    try {
        $files = git ls-files "claude-config/" 2>$null
        if ($files) {
            $result = @($files -split "`n" | Where-Object { $_ -ne "" })
            return $result
        }
        return @()
    }
    finally {
        Pop-Location
    }
}

function Get-ClaudeDestPath {
    param([string]$RelativePath)

    # Remove "claude-config/" prefix
    $relative = $RelativePath -replace "^claude-config/", ""

    # skills/ directory maps to ~/.claude/commands/
    if ($relative -match "^skills/") {
        $skillPath = $relative -replace "^skills/", ""
        $parts = $skillPath -split "/", 2
        $skillName = $parts[0]
        $skillFile = if ($parts.Length -gt 1) { $parts[1] } else { "" }

        if ($skillFile -eq "SKILL.md") {
            return "$env:USERPROFILE\.claude\commands\SKILL-$skillName.md"
        }
        else {
            return "$env:USERPROFILE\.claude\commands\$skillName-$skillFile"
        }
    }
    else {
        return "$env:USERPROFILE\.claude\$relative"
    }
}

#endregion

#region Core Functions

function Test-IsSymlink {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force
    return ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
}

function Get-SymlinkTarget {
    param([string]$Path)
    if (-not (Test-IsSymlink $Path)) { return $null }
    $item = Get-Item $Path -Force
    return $item.Target
}

function New-SymlinkSafe {
    param(
        [string]$Source,
        [string]$Destination
    )

    $srcPath = Join-Path $script:DotfilesDir $Source

    if (-not (Test-Path $srcPath)) {
        Write-Skip "スキップ: $srcPath (ファイルが見つかりません)"
        $script:CountSkipped++
        return
    }

    $destDir = Split-Path -Parent $Destination

    if ($DryRun) {
        Write-Info "[DRY RUN] 作成予定: $Destination -> $srcPath"
        if ((Test-Path $Destination) -and -not (Test-IsSymlink $Destination)) {
            Write-Info "[DRY RUN] バックアップ予定: $Destination -> $Destination.bak"
        }
        return
    }

    # Create destination directory if needed
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Handle existing file/symlink
    if (Test-IsSymlink $Destination) {
        Remove-Item $Destination -Force
    }
    elseif (Test-Path $Destination) {
        Write-Info "バックアップ: $Destination -> $Destination.bak"
        Move-Item $Destination "$Destination.bak" -Force
        $script:CountBackup++
    }

    # Create symlink
    $isDirectory = (Get-Item $srcPath).PSIsContainer
    if ($isDirectory) {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $srcPath | Out-Null
    }
    else {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $srcPath | Out-Null
    }

    Write-Success "作成完了: $Destination"
    Write-Host "         -> $srcPath"
    $script:CountCreated++
}

function Remove-SymlinkSafe {
    param(
        [string]$Source,
        [string]$Destination
    )

    $srcPath = Join-Path $script:DotfilesDir $Source

    if (-not (Test-IsSymlink $Destination)) {
        Write-Skip "スキップ: $Destination (シンボリックリンクではありません)"
        $script:CountSkipped++
        return
    }

    $target = Get-SymlinkTarget $Destination

    # Only remove if link points to our dotfiles
    if ($target -ne $srcPath) {
        Write-Skip "スキップ: $Destination (別の場所を指しています)"
        $script:CountSkipped++
        return
    }

    if ($DryRun) {
        Write-Info "[DRY RUN] 削除予定: $Destination"
        return
    }

    Remove-Item $Destination -Force
    Write-Success "削除完了: $Destination"
    $script:CountRemoved++

    # Restore backup if exists
    if (Test-Path "$Destination.bak") {
        Move-Item "$Destination.bak" $Destination -Force
        Write-Info "復元完了: $Destination.bak -> $Destination"
    }
}

function Install-ClaudeConfig {
    $files = @(Get-ClaudeConfigFiles)

    if ($files.Count -eq 0) {
        Write-Skip "gitにclaude-configファイルが見つかりません"
        return
    }

    # Ensure directories exist
    $claudeDir = "$env:USERPROFILE\.claude"
    $commandsDir = "$env:USERPROFILE\.claude\commands"

    if ($DryRun) {
        Write-Info "[DRY RUN] ディレクトリ作成予定: $claudeDir"
        Write-Info "[DRY RUN] ディレクトリ作成予定: $commandsDir"
    }
    else {
        if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }
        if (-not (Test-Path $commandsDir)) { New-Item -ItemType Directory -Path $commandsDir -Force | Out-Null }
    }

    foreach ($file in $files) {
        $dest = Get-ClaudeDestPath $file
        New-SymlinkSafe -Source $file -Destination $dest
    }
}

function Uninstall-ClaudeConfig {
    $files = @(Get-ClaudeConfigFiles)

    if ($files.Count -eq 0) { return }

    foreach ($file in $files) {
        $dest = Get-ClaudeDestPath $file
        Remove-SymlinkSafe -Source $file -Destination $dest
    }
}

#endregion

#region Interactive Mode

function Show-CategoryMenu {
    Write-Header "インストールするカテゴリを選択してください"
    Write-Host ""

    $i = 1
    foreach ($cat in @("shell", "git", "vim", "claude")) {
        $desc = $script:Categories[$cat]
        Write-Host "  $i) " -NoNewline
        Write-Host $desc
        $i++
    }

    Write-Host ""
    Write-Host "  a) 全てのカテゴリ"
    Write-Host "  q) 終了"
    Write-Host ""
}

function Show-FilesInCategory {
    param([string]$Category)

    $desc = $script:Categories[$Category]
    Write-Header "$desc のファイル一覧"
    Write-Host ""

    if ($Category -eq "claude") {
        $files = @(Get-ClaudeConfigFiles)
        $i = 1
        foreach ($file in $files) {
            $relative = $file -replace "^claude-config/", ""
            $displayDest = Get-ClaudeDestPath $file
            $displayDest = $displayDest -replace [regex]::Escape($env:USERPROFILE), "~"

            Write-Host "  $i) $relative"
            Write-Host "     -> $displayDest" -ForegroundColor Cyan
            $i++
        }
    }
    else {
        $indices = @(Get-IndicesByCategory $Category)

        $i = 1
        foreach ($idx in $indices) {
            $def = $script:FileDefs[$idx]
            Write-Host "  $i) $($def.Source)"
            Write-Host "     $($def.Description)" -ForegroundColor Cyan
            $i++
        }
    }

    Write-Host ""
    Write-Host "  a) このカテゴリの全ファイル"
    Write-Host "  b) カテゴリメニューに戻る"
    Write-Host ""
}

function Get-IndicesByCategory {
    param([string]$Category)

    $indices = @()
    for ($i = 0; $i -lt $script:FileDefs.Count; $i++) {
        if ($script:FileDefs[$i].Category -eq $Category) {
            $indices += $i
        }
    }
    return $indices
}

function Select-FilesInteractive {
    while ($true) {
        Show-CategoryMenu
        $choice = Read-Host "カテゴリを選択 (1-4/a/q)"

        switch ($choice.ToLower()) {
            "q" {
                Write-Host "キャンセルしました。"
                exit 0
            }
            "a" {
                # Select all
                for ($i = 0; $i -lt $script:FileDefs.Count; $i++) {
                    if (-not $script:SelectedIndices.Contains($i)) {
                        [void]$script:SelectedIndices.Add($i)
                    }
                }
                $script:ClaudeSelected = $true
                return
            }
            { $_ -in @("1", "2", "3", "4") } {
                $cats = @("shell", "git", "vim", "claude")
                $selectedCat = $cats[[int]$choice - 1]
                Select-FromCategory $selectedCat
            }
            default {
                Write-Err "無効な選択です"
            }
        }

        # If we have selections, ask if done
        if ($script:SelectedIndices.Count -gt 0 -or $script:ClaudeSelected) {
            $cont = Read-Host "`n他のカテゴリも選択しますか? [Y/n]"
            if ($cont.ToLower() -eq "n") { return }
        }
    }
}

function Select-FromCategory {
    param([string]$Category)

    if ($Category -eq "claude") {
        Show-FilesInCategory $Category
        $choice = Read-Host "全てのClaude設定ファイルをインストールしますか? [Y/n]"
        if ($choice.ToLower() -ne "n") {
            $script:ClaudeSelected = $true
            Write-Success "全てのClaude設定ファイルを追加しました"
        }
        return
    }

    $indices = @(Get-IndicesByCategory $Category)
    $fileCount = @($indices).Count

    while ($true) {
        Show-FilesInCategory $Category
        $choice = Read-Host "ファイルを選択 (1-$fileCount/a/b)"

        switch ($choice.ToLower()) {
            "b" { return }
            "a" {
                foreach ($idx in $indices) {
                    if (-not $script:SelectedIndices.Contains($idx)) {
                        [void]$script:SelectedIndices.Add($idx)
                    }
                }
                $desc = $script:Categories[$Category]
                Write-Success "$desc の全ファイルを追加しました"
                return
            }
            default {
                if ($choice -match '^\d+$') {
                    $num = [int]$choice
                    if ($num -ge 1 -and $num -le $fileCount) {
                        $idx = $indices[$num - 1]
                        if (-not $script:SelectedIndices.Contains($idx)) {
                            [void]$script:SelectedIndices.Add($idx)
                        }
                        $def = $script:FileDefs[$idx]
                        Write-Success "追加: $($def.Source)"
                    }
                    else {
                        Write-Err "無効な選択です"
                    }
                }
                else {
                    Write-Err "無効な選択です"
                }
            }
        }
    }
}

function Confirm-Installation {
    if ($script:SelectedIndices.Count -eq 0 -and -not $script:ClaudeSelected) {
        Write-Err "ファイルが選択されていません"
        exit 1
    }

    Write-Header "インストールするファイル"
    Write-Host ""

    # Show regular dotfiles
    foreach ($idx in $script:SelectedIndices) {
        $def = $script:FileDefs[$idx]
        $destDisplay = $def.Dest -replace [regex]::Escape($env:USERPROFILE), "~"
        Write-Host "  + $($def.Source) -> $destDisplay" -ForegroundColor Green
    }

    # Show claude config files if selected
    if ($script:ClaudeSelected) {
        Write-Host ""
        Write-Host "  Claude Code設定 (claude-config/):" -ForegroundColor Cyan
        $files = @(Get-ClaudeConfigFiles)
        foreach ($file in $files) {
            $relative = $file -replace "^claude-config/", ""
            $displayDest = Get-ClaudeDestPath $file
            $displayDest = $displayDest -replace [regex]::Escape($env:USERPROFILE), "~"
            Write-Host "    + $relative -> $displayDest"
        }
    }

    Write-Host ""
    $confirm = Read-Host "インストールを実行しますか? [Y/n]"
    if ($confirm.ToLower() -eq "n") {
        Write-Host "キャンセルしました。"
        exit 0
    }
}

#endregion

#region Work Environment Setup

function Select-Environment {
    Write-Header "環境の選択"
    Write-Host ""
    Write-Host "  1) 個人用 (.gitconfig.private)"
    Write-Host "  2) 仕事用 (.gitconfig.work)"
    Write-Host ""

    $choice = Read-Host "環境を選択してください [1/2]"

    switch ($choice) {
        "2" {
            $script:GitConfigSource = ".gitconfig.work"
            $script:IsWorkEnvironment = $true
            Write-Success "仕事用環境を選択しました"
        }
        default {
            $script:GitConfigSource = ".gitconfig.private"
            $script:IsWorkEnvironment = $false
            Write-Success "個人用環境を選択しました"
        }
    }
}

function Install-GitConfig {
    Write-Header "Git設定のインストール"

    $srcPath = Join-Path $script:DotfilesDir $script:GitConfigSource
    $destPath = "$env:USERPROFILE\.gitconfig"

    if (-not (Test-Path $srcPath)) {
        Write-Skip "スキップ: $srcPath (ファイルが見つかりません)"
        $script:CountSkipped++
        return
    }

    if ($DryRun) {
        Write-Info "[DRY RUN] 作成予定: $destPath -> $srcPath"
        return
    }

    # Handle existing file/symlink
    if (Test-IsSymlink $destPath) {
        Remove-Item $destPath -Force
    }
    elseif (Test-Path $destPath) {
        Write-Info "バックアップ: $destPath -> $destPath.bak"
        Move-Item $destPath "$destPath.bak" -Force
        $script:CountBackup++
    }

    # Create symlink
    New-Item -ItemType SymbolicLink -Path $destPath -Target $srcPath | Out-Null
    Write-Success "作成完了: $destPath"
    Write-Host "         -> $srcPath"
    $script:CountCreated++
}

function Set-WorkEnvironment {
    if (-not $script:IsWorkEnvironment) {
        return
    }

    $gitignoreGlobal = "$env:USERPROFILE\.gitignore_global"

    Write-Header "仕事環境の追加設定"
    Write-Host ""
    $addIgnore = Read-Host "CLAUDE.mdをgit追跡から除外しますか? [Y/n]"

    if ($addIgnore.ToLower() -ne "n") {
        if ($DryRun) {
            Write-Info "[DRY RUN] 追加予定: CLAUDE.md, .claude/ -> $gitignoreGlobal"
            Write-Info "[DRY RUN] 設定予定: core.excludesfile -> $gitignoreGlobal"
            return
        }

        $patternsAdded = 0

        # Add patterns to global gitignore if not already present
        $existingContent = if (Test-Path $gitignoreGlobal) { Get-Content $gitignoreGlobal -Raw } else { "" }

        if ($existingContent -notmatch "(?m)^CLAUDE\.md$") {
            Add-Content -Path $gitignoreGlobal -Value "CLAUDE.md"
            $patternsAdded++
        }

        if ($existingContent -notmatch "(?m)^\.claude/$") {
            Add-Content -Path $gitignoreGlobal -Value ".claude/"
            $patternsAdded++
        }

        # Configure git to use global gitignore
        git config --global core.excludesfile $gitignoreGlobal

        if ($patternsAdded -gt 0) {
            Write-Success "CLAUDE.md と .claude/ をグローバルgitignoreに追加しました"
        }
        else {
            Write-Info "グローバルgitignoreは既に設定済みです"
        }
        Write-Success "core.excludesfile を設定しました: $gitignoreGlobal"
    }
    else {
        Write-Info "グローバルgitignore設定をスキップしました"
    }
}

#endregion

#region Main Functions

function Install-Files {
    Write-Header "dotfilesをインストール中: $script:DotfilesDir"

    # Install regular dotfiles
    foreach ($idx in $script:SelectedIndices) {
        $def = $script:FileDefs[$idx]
        New-SymlinkSafe -Source $def.Source -Destination $def.Dest
    }

    # Install Claude config if selected
    if ($script:ClaudeSelected) {
        Install-ClaudeConfig
    }
}

function Uninstall-Files {
    Write-Header "dotfilesをアンインストール中"

    # Uninstall regular dotfiles
    foreach ($def in $script:FileDefs) {
        Remove-SymlinkSafe -Source $def.Source -Destination $def.Dest
    }

    # Uninstall Claude config
    Uninstall-ClaudeConfig
}

function Show-Summary {
    Write-Header "サマリー"
    Write-Host ""

    if ($Uninstall) {
        Write-Host "  削除: $script:CountRemoved" -ForegroundColor Green
    }
    else {
        Write-Host "  作成: $script:CountCreated" -ForegroundColor Green
        Write-Host "  バックアップ: $script:CountBackup" -ForegroundColor Yellow
    }
    Write-Host "  スキップ: $script:CountSkipped" -ForegroundColor Yellow
    Write-Host ""

    if (-not $DryRun -and -not $Uninstall -and $script:CountCreated -gt 0) {
        Write-Host "変更を適用するにはシェルを再起動してください。" -ForegroundColor Cyan
        Write-Host ""
    }
}

function Show-Help {
    $helpText = @"
Windows用 dotfiles インストーラー - dotfiles のシンボリックリンクを作成

使い方:
    .\install.ps1 [オプション]

オプション:
    -Help          このヘルプメッセージを表示
    -Force         確認なしで全ファイルをインストール
    -DryRun        変更を加えずにプレビューを表示
    -Uninstall     シンボリックリンクを削除

カテゴリ:
    shell   Bash設定 (.bashrc, .shell_aliases)
    git     Git設定 (.gitconfig, .git-completion.bash など)
    vim     Vim設定 (.vimrc)
    claude  Claude Code設定 (claude-config/)

使用例:
    .\install.ps1              # 対話モードでインストール
    .\install.ps1 -Force       # 全てをインストール
    .\install.ps1 -DryRun      # インストール内容をプレビュー
    .\install.ps1 -Uninstall   # シンボリックリンクを削除
    .\install.ps1 -DryRun -Uninstall  # アンインストール内容をプレビュー

Claude設定について:
    claude-config/ 内のファイルは 'git ls-files' で自動検出されます。
    - claude-config/CLAUDE.md -> ~/.claude/CLAUDE.md
    - claude-config/settings.json -> ~/.claude/settings.json
    - claude-config/skills/*/SKILL.md -> ~/.claude/commands/SKILL-*.md
    新しいClaude設定ファイルを追加するには、claude-config/ に追加して
    gitにコミットしてください。

仕事環境について:
    対話モードでは、仕事用環境かどうか確認されます。
    「はい」の場合、CLAUDE.md と .claude/ が ~/.gitignore_global に追加され、
    gitがこのファイルを使用するように設定されます (core.excludesfile)。
    これにより、仕事用リポジトリでClaude設定ファイルが追跡されなくなります。

注意:
    Windowsでシンボリックリンクを作成するには、管理者権限または
    開発者モードの有効化が必要です。
"@
    Write-Host $helpText
}

#endregion

#region Entry Point

function Main {
    if ($Help) {
        Show-Help
        return
    }

    # Check for admin privileges (needed for symlinks without Developer Mode)
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin -and -not $DryRun) {
        Write-Host ""
        Write-Host "警告: 管理者権限で実行されていません。" -ForegroundColor Yellow
        Write-Host "管理者権限または開発者モードがないとシンボリックリンクの作成に失敗する場合があります。" -ForegroundColor Yellow
        Write-Host ""
    }

    if ($DryRun) {
        Write-Header "DRY RUN モード - 変更は行われません"
    }

    if ($Uninstall) {
        if (-not $Force -and -not $DryRun) {
            $confirm = Read-Host "全てのシンボリックリンクを削除しますか? [y/N]"
            if ($confirm.ToLower() -ne "y") {
                Write-Host "キャンセルしました。"
                return
            }
        }
        Uninstall-Files
    }
    else {
        # Select environment first (determines gitconfig source)
        if (-not $Force) {
            Select-Environment
        }

        if ($Force) {
            # Force mode: select all files
            for ($i = 0; $i -lt $script:FileDefs.Count; $i++) {
                [void]$script:SelectedIndices.Add($i)
            }
            $script:ClaudeSelected = $true
        }
        else {
            # Interactive mode
            Select-FilesInteractive
            Confirm-Installation
        }

        Install-Files

        # Install gitconfig based on environment selection
        Install-GitConfig

        # Ask about work environment setup (only in interactive mode)
        if (-not $Force) {
            Set-WorkEnvironment
        }
    }

    Show-Summary
}

Main

#endregion
