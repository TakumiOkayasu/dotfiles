# Git for Windows用プロンプト設定
# ~/.config/git/git-prompt.sh として配置

# Git補完とプロンプト関数を読み込み
if test -z "$WINELOADERNOEXEC"; then
    GIT_EXEC_PATH="$(git --exec-path 2>/dev/null)"
    COMPLETION_PATH="${GIT_EXEC_PATH%/libexec/git-core}"
    COMPLETION_PATH="${COMPLETION_PATH%/lib/git-core}"
    COMPLETION_PATH="$COMPLETION_PATH/share/git/completion"
    if test -f "$COMPLETION_PATH/git-prompt.sh"; then
        . "$COMPLETION_PATH/git-completion.bash"
        . "$COMPLETION_PATH/git-prompt.sh"
    fi
fi

# Git状態表示の設定
# * = unstaged changes    + = staged changes
# $ = stash あり          % = untracked files
# < = behind  > = ahead   <> = diverged  = = up-to-date
GIT_PS1_SHOWDIRTYSTATE=1
GIT_PS1_SHOWSTASHSTATE=1
GIT_PS1_SHOWUNTRACKEDFILES=1
GIT_PS1_SHOWUPSTREAM="auto"
GIT_PS1_SHOWCONFLICTSTATE="yes"

# プロンプト設定
# 形式:
#   user@host:path (branch *+$%<>|CONFLICT)
#   $ (青Bold、rootは赤Bold #)
if type __git_ps1 &>/dev/null; then
    if [ "$(id -u)" -eq 0 ]; then
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(__git_ps1 " (%s)")\[\033[00m\]\n\[\033[01;31m\]#\[\033[00m\] '
    else
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(__git_ps1 " (%s)")\[\033[00m\]\n\[\033[01;34m\]$\[\033[00m\] '
    fi
else
    # __git_ps1 が利用できない場合
    if [ "$(id -u)" -eq 0 ]; then
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\n\[\033[01;31m\]#\[\033[00m\] '
    else
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\n\[\033[01;34m\]$\[\033[00m\] '
    fi
fi
