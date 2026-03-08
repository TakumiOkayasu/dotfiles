# VcXsrv + Ghostty セットアップガイド (WSL2)

WSL2上でGhosttyターミナルをVcXsrv経由で使用するための手順。
WSLgのRDP描画を迂回し、X11直接描画で安定した表示を得る。

## 背景

| 問題 | 原因 |
| ------ | ------ |
| Windows Terminalのデバイスロスト | DirectX + GPUドライバのTDR |
| WSLg経由のカーソル肥大化 | RDP + GTKの二重スケーリング |
| WSLg経由のIME不安定 | fcitx5とWSLgの相性 |

VcXsrv (X11サーバー) を使うことでWSLgを迂回し、上記の問題を回避する。

## 前提条件

- Windows 10/11 + WSL2 (Ubuntu 24.04)
- Ghostty インストール済み
- dotfile-work の `install.sh` 実行済み

## Step 1: VcXsrv インストール (Windows側)

[vcxsrv.com](https://vcxsrv.com/) からダウンロード・インストール。

## Step 2: DPIスケーリング無効化 (Windows側)

高DPI環境 (150%以上) では必須。

### GUI

1. `C:\Program Files\VcXsrv\vcxsrv.exe` を右クリック → プロパティ
2. 互換性 → 高DPI設定の変更
3. 「高いDPIスケールの動作を上書きします」にチェック
4. 拡大縮小の実行元: 「アプリケーション」を選択

### コマンド (PowerShell 管理者権限)

```powershell
$regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
$vcxsrvPath = "C:\Program Files\VcXsrv\vcxsrv.exe"
Set-ItemProperty -Path $regPath -Name $vcxsrvPath -Value "~ HIGHDPIAWARE" -Type String
```

## Step 3: XLaunch設定 (Windows側)

XLaunchを起動して以下の通り設定:

| 画面 | 設定 | 値 | 理由 |
| ------ | ------ | ---- | ------ |
| 1 | Display mode | Multiple windows | アプリごとに独立ウィンドウ |
| 1 | Display number | 0 | DISPLAYの:0に対応 |
| 2 | Client startup | Start no client | WSL側から接続 |
| 3 | Clipboard | ON | Windows-WSL間コピペ |
| 3 | Primary Selection | ON | 中クリック貼り付け |
| 3 | Native opengl | OFF | ONだとGhosttyが黒画面になる |
| 3 | Disable access control | ON | WSL2からの接続を許可 |

設定を `config.xlaunch` として保存。
本リポジトリでは `config/windows/config.xlaunch` で管理。

## Step 4: ファイアウォール設定 (Windows側、管理者PowerShell)

WSL2からVcXsrvへの接続を許可する。プライベートIPレンジのみに限定。

```powershell
New-NetFirewallRule -DisplayName "VcXsrv" -Direction Inbound `
  -Program "C:\Program Files\VcXsrv\vcxsrv.exe" -Action Allow `
  -RemoteAddress 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 -Profile Any
```

## Step 5: 自動起動登録 (Windows側)

```powershell
# シンボリックリンクでスタートアップに登録 (管理者PowerShell)
# ディストロ名は環境に合わせて変更
New-Item -ItemType SymbolicLink `
  -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\config.xlaunch" `
  -Target "\\wsl.localhost\<ディストロ名>\home\<ユーザー>\prog\dotfile-work\config\windows\config.xlaunch"
```

ディストロ名の確認:

```powershell
# 以下で True になるパスを使う
Test-Path "\\wsl.localhost\Ubuntu"
Test-Path "\\wsl.localhost\Ubuntu-24.04"
```

## Step 6: WSL側設定

### USE_VCXSRV 有効化

```bash
# ~/.local.sh に追加 (Git管理外)
echo 'export USE_VCXSRV=1' >> ~/.local.sh
```

これにより `wsl.sh` が DISPLAY をVcXsrvのホストIPに向ける。

### GTK4 カーソル設定

```bash
# dotfile-work に同梱済み。install.sh で配置するか手動コピー
mkdir -p ~/.config/gtk-4.0
cp config/gtk-4.0/settings.ini ~/.config/gtk-4.0/
```

内容:

```ini
[Settings]
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
```

### 反映

```bash
source ~/.bashrc
```

`wsl.sh` が自動的に以下を設定する:

| 設定 | 値 | 目的 |
| ------ | ---- | ------ |
| DISPLAY | `<ホストIP>:0` | VcXsrvに接続 |
| XCURSOR_SIZE | 24 | カーソルサイズ |
| XCURSOR_THEME | Adwaita | カーソルテーマ |
| GDK_SCALE | 1 | GTKスケーリング無効化 |
| GDK_DPI_SCALE | 1 | GTK DPIスケーリング無効化 |
| gsettings cursor-size | 24 | dconf経由のカーソル指定 |
| xrdb Xcursor.size | 24 | X11リソース経由のカーソル指定 |

## Step 7: Ghostty設定

`~/.config/ghostty/config`:

```text
font-family = UbuntuMono Nerd Font Mono
font-size = 16
theme = Dracula
window-decoration = true
window-save-state = always
shell-integration = bash
keybind = ctrl+shift+c=copy_to_clipboard
keybind = ctrl+shift+v=paste_from_clipboard
```

## Step 8: 動作確認

```bash
echo $DISPLAY          # → <ホストIP>:0
ghostty --window-width=200 --window-height=50
```

確認項目:

- [ ] Ghosttyウィンドウが表示される
- [ ] マウスカーソルが正常サイズ
- [ ] Ctrl+Shift+C/V でコピー&ペースト
- [ ] 日本語入力 (fcitx5インストール済みの場合)

## 日本語入力 (オプション)

```bash
sudo apt install fcitx5 fcitx5-mozc
fcitx5-configtool  # Mozcを入力メソッドに追加
```

`wsl.sh` がfcitx5を検出すると自動的に環境変数設定・デーモン起動を行う。
Ctrl+Space で日本語入力切替。

## トラブルシューティング

| 症状 | 原因 | 対策 |
| ------ | ------ | ------ |
| VcXsrv起動エラー (ポート競合) | 既存プロセスが残っている | `Stop-Process -Name vcxsrv -Force` で殺してから再起動 |
| DISPLAY が `:0` のまま | `~/.local.sh` の読み込み順 | `common.sh` でローカル設定がプラットフォーム設定より先に読まれるか確認。`unset DOTFILES_LOADED && source ~/.bashrc` |
| DISPLAY のIPが間違っている | `resolv.conf` のDNSプロキシIPとホストIPが異なる | wsl.shは `ip route show default` でホストIPを取得する。`resolv.conf` は使わない |
| VcXsrvにWSLから接続できない | Windowsファイアウォール | Step 4のファイアウォールルール追加 + VcXsrv再起動 |
| カーソルが巨大 | GTK4のスケーリングバグ | `~/.config/gtk-4.0/settings.ini` + `xrdb -merge` で24に固定 |
| Ghosttyが黒画面 | Native OpenGLがON | XLaunchで Native opengl を OFF にする |
| `\\wsl$` でパスが見つからない | ディストロ名の不一致 | `\\wsl.localhost\<正しいディストロ名>` を使用 |
| Ghosttyウィンドウが2つ出る | WSLg版とVcXsrv版が両方起動 | `pkill ghostty` で全プロセスを殺してから `source ~/.bashrc` で再起動 |
| ファイアウォール変更後も接続不可 | VcXsrvがルール変更前の状態で動作 | VcXsrvを再起動する (`Stop-Process -Name vcxsrv -Force` → XLaunch再実行) |

## 残タスク

### 未完了 (要対応)

| タスク | 詳細 | 優先度 |
| -------- | ------ | -------- |
| `install.sh` に `config/gtk-4.0/` の配置を追加 | `~/.config/gtk-4.0/settings.ini` へのシンボリックリンク作成。現在は手動コピーが必要 | 高 |
| `install.sh` に `config/windows/` の配置を追加 | Windowsファイルはシンボリックリンクではなくコピーが適切。install.shのWindows対応検討 | 中 |
| `jpinput` が未動作 | PowerShellダイアログが起動しない。`$0` パス解決バグは修正済みだが、PowerShell側のWinFormsダイアログ表示自体が動作していない。Goシングルバイナリへの書き直しを検討 | 高 |
| fcitx5 + Ghostty の日本語入力テスト | fcitx5/Mozcインストール後の実動作確認が未実施 | 中 |
| Ghostty設定のdotfiles管理 | `~/.config/ghostty/config` が現在Git管理外。`config/ghostty/` として管理するか検討 | 低 |

### 既知の制限

| 制限 | 原因 | 回避策 |
| ------ | ------ | -------- |
| GTK4 4.14のカーソルスケーリングバグ | Ubuntu 24.04のGTK4が古い (4.14.5)。4.18で修正済み | `settings.ini` + `xrdb` + `gsettings` の三重設定で対応 |
| VcXsrv の Native OpenGL が使えない | ONにするとGhosttyが黒画面になる | OFFで運用。ソフトウェアレンダリングのため描画欠け(黒い矩形)が発生する場合がある |
| PowerShellのjpinputダイアログ起動が遅い | PowerShellの初回起動コスト (0.5-1秒) | 許容できなければGoシングルバイナリに置き換え |
| WSLgとVcXsrvの共存 | `USE_VCXSRV=1` 切替式。同時使用は不可 | `~/.local.sh` でフラグ管理 |

### 将来の改善案

| 案 | 効果 | コスト |
| ---- | ------ | -------- |
| jpinput を Go で書き直し | 起動高速化、ダイアログの安定性向上 | 中 |
| chezmoi 移行 | install.sh の全問題を構造的に解決 | 大 (別プロジェクトで進行中) |
| Ghostty config のdotfiles管理 | 環境再現性の向上 | 小 |
| VcXsrv → X410 移行 | HiDPI対応、Wayland対応の改善 | 小 (有料) |

## 関連ファイル

| ファイル | 役割 |
| ---------- | ------ |
| `config/shell/local/wsl.sh` | DISPLAY設定、カーソル修正、fcitx5自動起動 |
| `config/shell/common.sh` | `~/.local.sh` → `wsl.sh` の読み込み順を管理 |
| `config/windows/config.xlaunch` | VcXsrv起動設定 |
| `config/gtk-4.0/settings.ini` | GTK4カーソルテーマ・サイズ |
| `config/shell/bash/bashrc` | Ghostty自動起動 |
| `bin/jpinput` | Windows IME日本語入力ヘルパー (bashラッパー) |
| `bin/jpinput-dialog.ps1` | PowerShellテキスト入力ダイアログ |
