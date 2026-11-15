#!/bin/sh
#
# dotfiles インストーラー (POSIX sh互換)
# dotfilesのシンボリックリンクをホームディレクトリに作成します
#
# 使い方:
#   ./install.sh              # 対話モード(デフォルト)
#   ./install.sh -f           # 全ファイルを強制インストール
#   ./install.sh -n           # ドライラン(プレビューのみ)
#   ./install.sh -u           # アンインストール
#

set -eu

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER_LIB_DIR="$DOTFILES_DIR/scripts/install"
# shellcheck source=scripts/install/library.sh
. "$INSTALLER_LIB_DIR/library.sh"

initialize_installer "$DOTFILES_DIR"
main "$@"
