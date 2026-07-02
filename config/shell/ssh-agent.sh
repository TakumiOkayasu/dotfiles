#!/bin/sh
# config/shell/ssh-agent.sh - SSH Agent 共通ロジック (POSIX sh)
#
# 読み込み元: bashrc, zshrc
# 機能: 既存のagentに接続を試み、なければ新規起動、鍵を自動追加
#
# 注意: keychain があれば優先使用。既にSSH_AUTH_SOCKが有効なら何もしない

# SC1090: 動的パス ($_ssa_env) の source は追跡不可を許容
# SC2317: source されていれば return、直接実行なら : (静的解析は後者を到達不能と誤検出)
# shellcheck disable=SC1090,SC2317

# keychain があれば優先使用 (パスフレーズキャッシュ機能付き)
if command -v keychain >/dev/null 2>&1; then
    eval "$(keychain --eval --quiet id_ed25519 id_rsa 2>/dev/null)"
    return 0 2>/dev/null || :
fi

# SSH_AUTH_SOCK が既に有効なソケットを指していれば何もしない
if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    return 0 2>/dev/null || :
fi

_setup_ssh_agent() {
    _ssa_env="$HOME/.ssh/agent.env"

    # .sshディレクトリがなければ作成 (パーミッションは作成後に付与)
    [ -d "$HOME/.ssh" ] || { mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"; }

    # 既存のagentに接続を試みる
    if [ -f "$_ssa_env" ]; then
        . "$_ssa_env" >/dev/null
        # agentプロセスが生きているか確認
        if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
            rm -f "$_ssa_env"
            unset SSH_AUTH_SOCK SSH_AGENT_PID
        fi
    fi

    # agentが起動していなければ新規起動
    if [ -z "$SSH_AUTH_SOCK" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
        ssh-agent -s > "$_ssa_env"
        chmod 600 "$_ssa_env"
        . "$_ssa_env" >/dev/null
    fi

    # 鍵が登録されていなければ追加
    if ! ssh-add -l >/dev/null 2>&1; then
        for _ssa_key in "$HOME"/.ssh/id_*; do
            # 公開鍵(.pub)はスキップ
            case "$_ssa_key" in *.pub) continue ;; esac
            # ファイルが存在すれば追加
            [ -f "$_ssa_key" ] && ssh-add "$_ssa_key" 2>/dev/null
        done
    fi

    unset _ssa_env _ssa_key
}

_setup_ssh_agent
unset -f _setup_ssh_agent
unset _ssa_env _ssa_key 2>/dev/null
