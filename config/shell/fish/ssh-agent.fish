# config/shell/fish/ssh-agent.fish - SSH Agent (fish ネイティブ)
#
# 読み込み元: config.fish
# 機能: 既存のagentに接続を試み、なければ新規起動、鍵を自動追加

# SSH_AUTH_SOCK が既に有効なソケットを指していれば何もしない
if test -n "$SSH_AUTH_SOCK" -a -S "$SSH_AUTH_SOCK"
    return
end

function _setup_ssh_agent
    set -l ssh_env "$HOME/.ssh/agent.env"

    # 既存のagentに接続を試みる
    if test -f "$ssh_env"
        # agent.envをfishで読み込む (SSH_AUTH_SOCK, SSH_AGENT_PID を抽出)
        set -l auth_sock (grep SSH_AUTH_SOCK "$ssh_env" | sed 's/.*=\(.*\);.*/\1/')
        set -l agent_pid (grep SSH_AGENT_PID "$ssh_env" | sed 's/.*=\(.*\);.*/\1/')

        if test -n "$auth_sock" -a -n "$agent_pid"
            set -gx SSH_AUTH_SOCK $auth_sock
            set -gx SSH_AGENT_PID $agent_pid

            # agentプロセスが生きているか確認
            if not kill -0 $SSH_AGENT_PID 2>/dev/null
                rm -f "$ssh_env"
                set -e SSH_AUTH_SOCK
                set -e SSH_AGENT_PID
            end
        end
    end

    # agentが起動していなければ新規起動
    if test -z "$SSH_AUTH_SOCK"; or not test -S "$SSH_AUTH_SOCK"
        ssh-agent -s > "$ssh_env"
        chmod 600 "$ssh_env"

        set -l auth_sock (grep SSH_AUTH_SOCK "$ssh_env" | sed 's/.*=\(.*\);.*/\1/')
        set -l agent_pid (grep SSH_AGENT_PID "$ssh_env" | sed 's/.*=\(.*\);.*/\1/')
        set -gx SSH_AUTH_SOCK $auth_sock
        set -gx SSH_AGENT_PID $agent_pid
    end

    # 鍵が登録されていなければ追加
    if not ssh-add -l &>/dev/null
        for key in $HOME/.ssh/id_*
            string match -q '*.pub' $key; and continue
            test -f $key; and ssh-add $key 2>/dev/null
        end
    end
end

_setup_ssh_agent
functions -e _setup_ssh_agent
