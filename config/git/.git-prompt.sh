# Git for Windows用プロンプト設定
# ~/.config/git/git-prompt.sh として配置

# Git補完を読み込み(補完機能のみ使用)
if test -z "$WINELOADERNOEXEC"; then
    GIT_EXEC_PATH="$(git --exec-path 2>/dev/null)"
    COMPLETION_PATH="${GIT_EXEC_PATH%/libexec/git-core}"
    COMPLETION_PATH="${COMPLETION_PATH%/lib/git-core}"
    COMPLETION_PATH="$COMPLETION_PATH/share/git/completion"
    if test -f "$COMPLETION_PATH/git-completion.bash"; then
        . "$COMPLETION_PATH/git-completion.bash"
    fi
fi

# 色定義
_PS1_GREEN='\[\033[01;32m\]'
_PS1_BLUE='\[\033[01;34m\]'
_PS1_YELLOW='\[\033[33m\]'
_PS1_RED='\[\033[01;31m\]'
_PS1_RESET='\[\033[00m\]'

# プロンプト部品
_PS1_USER_HOST="${_PS1_GREEN}\u@\h${_PS1_RESET}"
_PS1_PATH="${_PS1_BLUE}\w${_PS1_RESET}"
_PS1_NEWLINE='\n'

# プロンプト記号(root/一般ユーザー)
if [ "$(id -u)" -eq 0 ]; then
    _PS1_PROMPT="${_PS1_RED}#${_PS1_RESET} "
else
    _PS1_PROMPT="${_PS1_BLUE}\$${_PS1_RESET} "
fi

# Git情報取得(自前実装・直感的記号版)
# 形式: (branch ✎✓⏸★ ⬆1⬇2)
#   ✎  = 編集中 (unstaged changes)
#   ✓  = 保存準備OK (staged changes)
#   ⏸  = 一時停止 (stash あり)
#   ★  = 新規ファイル (untracked files)
#   ⬆n = アップロード可 (ahead/push可能)
#   ⬇n = 更新あり (behind/pull必要)
#   ⚠ CONFLICT = 要対応 (コンフリクト中)
#   ⟳ REBASE   = 処理中 (rebase中)
#   ⟳ MERGING  = 処理中 (merge中)
_get_git_info() {
    # Gitリポジトリ内かチェック
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null) || return

    local branch=""
    local status_icons=""
    local special_state=""

    # 特殊状態チェック(rebase/merge/conflict)
    if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; then
        special_state="⟳ REBASE"
        # rebase中のブランチ名
        if [ -f "$git_dir/rebase-merge/head-name" ]; then
            branch=$(cat "$git_dir/rebase-merge/head-name")
            branch=${branch#refs/heads/}
        fi
    elif [ -f "$git_dir/MERGE_HEAD" ]; then
        special_state="⟳ MERGING"
    fi

    # コンフリクトチェック
    if git ls-files --unmerged 2>/dev/null | grep -q .; then
        special_state="⚠ CONFLICT"
    fi

    # ブランチ名取得(まだ取得できていない場合)
    if [ -z "$branch" ]; then
        branch=$(git symbolic-ref --short HEAD 2>/dev/null)
        if [ -z "$branch" ]; then
            # detached HEAD
            branch=$(git rev-parse --short HEAD 2>/dev/null)
            branch="($branch)"
        fi
    fi

    # 作業ツリー内のみ状態チェック
    local inside_worktree
    inside_worktree=$(git rev-parse --is-inside-work-tree 2>/dev/null)
    if [ "$inside_worktree" = "true" ]; then
        # unstaged changes
        if ! git diff --quiet 2>/dev/null; then
            status_icons+="✎"
        fi

        # staged changes
        if ! git diff --cached --quiet 2>/dev/null; then
            status_icons+="✓"
        fi

        # stash
        if git stash list 2>/dev/null | grep -q .; then
            status_icons+="⏸"
        fi

        # untracked files
        if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
            status_icons+="★"
        fi

        # upstream比較(ahead/behind)
        local upstream
        upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
        if [ -n "$upstream" ]; then
            local ahead behind
            ahead=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null)
            behind=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null)
            [ "$ahead" -gt 0 ] 2>/dev/null && status_icons+="⬆$ahead"
            [ "$behind" -gt 0 ] 2>/dev/null && status_icons+="⬇$behind"
        fi
    fi

    # 出力組み立て
    local result="$branch"
    [ -n "$status_icons" ] && result+=" $status_icons"
    [ -n "$special_state" ] && result+="|$special_state"

    echo " ($result)"
}

# プロンプト設定
# 形式:
#   user@host:path (branch ✎✓⏸★ ⬆1⬇1|STATE)
#   $ (青Bold、rootは赤Bold #)
_update_ps1() {
    local git_info
    git_info=$(_get_git_info)
    PS1="${_PS1_USER_HOST}:${_PS1_PATH}${_PS1_YELLOW}${git_info}${_PS1_RESET}${_PS1_NEWLINE}${_PS1_PROMPT}"
}
