# Claude Code Configuration Setup Script for Windows
# This script creates symbolic links from %USERPROFILE%\.claude to the dotfile-work\claude-config directory
# and sets up the global gitignore file

# Get the script directory path
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigSourceDir = Join-Path $ScriptDir "claude-config"
$TargetDir = Join-Path $env:USERPROFILE ".claude"
$GitIgnoreGlobal = Join-Path $env:USERPROFILE ".gitignore_global"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Claude Code Configuration Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if source directory exists
if (-not (Test-Path $ConfigSourceDir)) {
    Write-Host "Error: Source directory $ConfigSourceDir does not exist" -ForegroundColor Red
    exit 1
}

Write-Host "Source directory: $ConfigSourceDir" -ForegroundColor Blue
Write-Host "Target directory: $TargetDir" -ForegroundColor Blue
Write-Host ""

# Create target directory if it doesn't exist
if (-not (Test-Path $TargetDir)) {
    Write-Host "Creating directory: $TargetDir" -ForegroundColor Green
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
} else {
    Write-Host "Directory already exists: $TargetDir" -ForegroundColor Yellow
}

# Function to create backup with timestamp
function Backup-IfExists {
    param (
        [string]$TargetPath
    )

    if (Test-Path $TargetPath) {
        $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupPath = "$TargetPath.backup_$Timestamp"
        Write-Host "Backing up existing $TargetPath to $BackupPath" -ForegroundColor Yellow
        Move-Item -Path $TargetPath -Destination $BackupPath -Force
    }
}

# Function to create symbolic link
function Create-SymbolicLink {
    param (
        [string]$SourceName
    )

    $SourcePath = Join-Path $ConfigSourceDir $SourceName
    $TargetPath = Join-Path $TargetDir $SourceName

    if (-not (Test-Path $SourcePath)) {
        Write-Host "Warning: $SourceName does not exist in source directory, skipping" -ForegroundColor Yellow
        return $false
    }

    Backup-IfExists $TargetPath

    Write-Host "Creating symlink: $TargetPath -> $SourcePath" -ForegroundColor Green

    # Determine if source is a file or directory
    $ItemType = if (Test-Path $SourcePath -PathType Container) { "Directory" } else { "File" }

    try {
        $result = New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath -Force -ErrorAction Stop
        return $true
    } catch {
        Write-Host "Error creating symlink: $_" -ForegroundColor Red
        Write-Host "Note: Symbolic links may require administrator privileges or Developer Mode enabled." -ForegroundColor Yellow
        Write-Host "To enable Developer Mode: Settings > Update & Security > For developers > Developer Mode" -ForegroundColor Yellow
        return $false
    }
}

Write-Host "Creating symbolic links..." -ForegroundColor Cyan
Write-Host ""

# Create symlinks for each configuration item
$Items = @("CLAUDE.md", "settings.json", "skills", "hooks")
$SuccessCount = 0

foreach ($Item in $Items) {
    if (Create-SymbolicLink $Item) {
        $SuccessCount++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Display final link status
Write-Host "Final Configuration Status:" -ForegroundColor Cyan
Write-Host ""

foreach ($Item in $Items) {
    $TargetPath = Join-Path $TargetDir $Item

    if (Test-Path $TargetPath) {
        $ItemInfo = Get-Item $TargetPath -ErrorAction SilentlyContinue

        if ($ItemInfo.LinkType -eq "SymbolicLink") {
            $LinkTarget = $ItemInfo.Target
            if (Test-Path $TargetPath) {
                Write-Host "✓ $Item`: $TargetPath -> $LinkTarget" -ForegroundColor Green
            } else {
                Write-Host "✗ $Item`: $TargetPath -> $LinkTarget (broken link)" -ForegroundColor Red
            }
        } else {
            Write-Host "⚠ $Item`: $TargetPath (exists but not a symlink)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ $Item`: $TargetPath (does not exist)" -ForegroundColor Red
    }
}

Write-Host ""

if ($SuccessCount -eq $Items.Count) {
    Write-Host "You can now use Claude Code with your configured settings!" -ForegroundColor Green
} elseif ($SuccessCount -gt 0) {
    Write-Host "Setup partially completed. Some items could not be linked." -ForegroundColor Yellow
} else {
    Write-Host "Setup failed. Please check the errors above." -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Global Gitignore Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ask user to select gitignore variant
Write-Host "Select gitignore variant:" -ForegroundColor Blue
Write-Host "  1) work (includes CLAUDE.md exclusion)" -ForegroundColor White
Write-Host "  2) private" -ForegroundColor White
Write-Host ""
$GitIgnoreChoice = Read-Host "Enter choice (1/2) [1]"

if ($GitIgnoreChoice -eq "2") {
    $GitIgnoreVariant = "private"
} else {
    $GitIgnoreVariant = "work"
}

$GitIgnoreSource = Join-Path $ScriptDir ".gitignore.$GitIgnoreVariant"

if (Test-Path $GitIgnoreSource) {
    Backup-IfExists $GitIgnoreGlobal

    Write-Host "Creating symlink: $GitIgnoreGlobal -> $GitIgnoreSource" -ForegroundColor Green

    try {
        New-Item -ItemType SymbolicLink -Path $GitIgnoreGlobal -Target $GitIgnoreSource -Force -ErrorAction Stop | Out-Null
        Write-Host "✓ Global gitignore ($GitIgnoreVariant) linked successfully" -ForegroundColor Green
    } catch {
        Write-Host "Error creating symlink: $_" -ForegroundColor Red
        Write-Host "Note: Symbolic links may require administrator privileges or Developer Mode enabled." -ForegroundColor Yellow
    }
} else {
    Write-Host "Warning: $GitIgnoreSource does not exist" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
