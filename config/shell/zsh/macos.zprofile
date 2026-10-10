#!/bin/zsh
# shell/zsh/macos.zprofile - macOS の zsh login shell 向け設定
#
# 読み込み元: zprofile (Darwin の login shell のみ)

# OrbStack: command-line tools and integration
if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
    source "$HOME/.orbstack/shell/init.zsh"
fi
