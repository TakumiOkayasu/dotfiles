#!/bin/sh
# config/shell/ssh-agent.sh - SSH Agent 共通ロジック (POSIX sh)
#
# 読み込み元: bashrc, zshrc
# 機能: 既存のagentに接続を試み、なければ新規起動、鍵を自動追加
#
# 注意: keychain等が既にSSH_AUTH_SOCKを設定している場合は何もしない
#       (linux.sh/macos.shとの衝突回避)

# SSH_AUTH_SOCK が既に有効なソケットを指していれば何もしない
if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    return 0 2>/dev/null || :
fi

_setup_ssh_agent() {
    _ssa_env="$HOME/.ssh/agent.env"

    # .sshディレクトリがなければ作成
    [ -d "$HOME/.ssh" ] || mkdir -p -m 700 "$HOME/.ssh"

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
