#!/bin/sh
# hook-dispatcher.sh - Codex hook entrypoint aggregator
#
# Codex requires hook commands to be reviewed before execution. Registering every
# small guard script separately makes first-run review noisy, so inline hooks in
# config.toml call this dispatcher once per event to run the local guard set.

# set -e を使わない（個別 hook の exit 2 を正しく伝播するため）

EVENT="${1:-}"

if SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P); then
    :
else
    SCRIPT_DIR=$(dirname "$0")
fi

if [ -t 0 ]; then
    INPUT=""
else
    INPUT=$(cat)
fi

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -n "$INPUT" ] && [ -n "$JQ" ]; then
    TOOL_NAME=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""
else
    TOOL_NAME=""
fi

run_hook() {
    _hook="$1"
    [ -x "${SCRIPT_DIR}/${_hook}" ] || return 0

    if [ -n "$INPUT" ]; then
        printf '%s\n' "$INPUT" | "${SCRIPT_DIR}/${_hook}"
    else
        "${SCRIPT_DIR}/${_hook}"
    fi
    _status=$?

    # exit 2 は Codex/Claude hook の明示ブロックとして扱う。
    [ "$_status" -eq 2 ] && exit 2
    if [ "$_status" -ne 0 ]; then
        echo "hook-dispatcher.sh: ${_hook} exited with ${_status}; continuing" >&2
    fi
    return 0
}

case "$EVENT" in
    pre-tool-use)
        run_hook rules-guard.sh
        run_hook env-file-protect.sh
        run_hook main-branch-code-warning.sh
        case "$TOOL_NAME" in
            Bash|"")
                run_hook destructive-command-block.sh
                run_hook docker-build-check.sh
                run_hook language-version-check.sh
                run_hook local-command-block.sh
                run_hook admin-command-block.sh
                run_hook secret-leak-check.sh
                ;;
        esac
        ;;
    post-tool-use)
        run_hook rules-enforce.sh
        ;;
    user-prompt-submit)
        CODEX_RULES_CONTEXT_MODE=simple-engineering
        export CODEX_RULES_CONTEXT_MODE
        run_hook rules-inject.sh
        unset CODEX_RULES_CONTEXT_MODE
        CODEX_PRIMARY_SOURCE_CHECK_MODE=quiet
        export CODEX_PRIMARY_SOURCE_CHECK_MODE
        run_hook primary-source-check.sh
        unset CODEX_PRIMARY_SOURCE_CHECK_MODE
        ;;
    pre-compact)
        run_hook pre-compact-backup.sh
        ;;
    stop)
        run_hook rules-enforce.sh
        ;;
    session-start)
        run_hook rules-inject.sh
        run_hook session-start-reminder.sh
        run_hook session-resume.sh
        run_hook project-environment-check.sh
        run_hook primary-source-reminder.sh
        ;;
    *)
        echo "hook-dispatcher.sh: unknown event: ${EVENT}" >&2
        exit 0
        ;;
esac

exit 0
