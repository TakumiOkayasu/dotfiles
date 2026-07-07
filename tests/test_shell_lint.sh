#!/bin/sh
# tests/test_shell_lint.sh - シェルスクリプトの静的検査
#
# 目的:
#   - sh/bash: shellcheck で検査 (.shellcheckrc の設定を利用)
#   - zsh: shellcheck は zsh 非対応 (SC1071) のため zsh -n で構文チェックを補完する
#
# 対象は今回クリーン化した config/shell と hooks/bin 系に限定する。
# install.sh と tests/*.sh は本 lint の対象外 (別途対応が必要な既存指摘を持つため)。
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

fail=0

echo "== shellcheck (sh/bash) =="
# 検査対象: config/shell (zsh 除く) と claude/codex/common/scripts 配下の *.sh
# ベンダー同梱物 (.git-completion.bash / .git-prompt.sh) は除外する
sh_files=$(find config claude codex common scripts -type f \
    \( -name '*.sh' -o -name '*.bash' \) \
    ! -path 'config/shell/zsh/*' \
    ! -name '.git-completion.bash' \
    ! -name '.git-prompt.sh')
# 拡張子を持たない bash 設定ファイルを明示的に追加する
sh_files="$sh_files config/shell/bash/bashrc config/shell/bash/bash_profile"

for f in $sh_files; do
    [ -f "$f" ] || continue
    if shellcheck "$f"; then
        echo "OK: $f"
    else
        fail=1
    fi
done

echo "== zsh -n (zsh 構文チェック) =="
for f in config/shell/zsh/zshrc config/shell/zsh/zprofile; do
    [ -f "$f" ] || continue
    if zsh -n "$f"; then
        echo "OK: $f"
    else
        echo "NG: $f"
        fail=1
    fi
done

if [ "$fail" -eq 0 ]; then
    echo "shell lint: PASS"
else
    echo "shell lint: FAIL"
fi
exit "$fail"
