# zprofile / zshrc が共有する PATH 設定。
# Kiri にも docker が付属するため、既存の docker を優先する。
if [[ -f "$HOME/.kiri/bin/kiri" && -x "$HOME/.kiri/bin/kiri" && ":${PATH:-}:" != *":$HOME/.kiri/bin:"* ]]; then
    export PATH="${PATH:+$PATH:}$HOME/.kiri/bin"
fi
