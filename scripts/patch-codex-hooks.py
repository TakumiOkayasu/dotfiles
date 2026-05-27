#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib
DISPATCHER = '#!/bin/sh\n# hook-dispatcher.sh - Codex hook entrypoint aggregator\n#\n# Codex requires hook commands to be reviewed before execution. Registering every\n# small guard script separately makes first-run review noisy, so hooks.json calls\n# this dispatcher once per event and the dispatcher runs the local guard set.\n\n# set -e を使わない（個別 hook の exit 2 を正しく伝播するため）\n\nEVENT="${1:-}"\n\nif SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P); then\n    :\nelse\n    SCRIPT_DIR=$(dirname "$0")\nfi\n\nif [ -t 0 ]; then\n    INPUT=""\nelse\n    INPUT=$(cat)\nfi\n\nJQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")\nif [ -n "$INPUT" ] && [ -n "$JQ" ]; then\n    TOOL_NAME=$(printf \'%s\\n\' "$INPUT" | "$JQ" -r \'.tool_name // ""\' 2>/dev/null) || TOOL_NAME=""\nelse\n    TOOL_NAME=""\nfi\n\nrun_hook() {\n    _hook="$1"\n    [ -x "${SCRIPT_DIR}/${_hook}" ] || return 0\n\n    if [ -n "$INPUT" ]; then\n        printf \'%s\\n\' "$INPUT" | "${SCRIPT_DIR}/${_hook}"\n    else\n        "${SCRIPT_DIR}/${_hook}"\n    fi\n    _status=$?\n\n    # exit 2 は Codex/Claude hook の明示ブロックとして扱う。\n    [ "$_status" -eq 2 ] && exit 2\n    if [ "$_status" -ne 0 ]; then\n        echo "hook-dispatcher.sh: ${_hook} exited with ${_status}; continuing" >&2\n    fi\n    return 0\n}\n\ncase "$EVENT" in\n    pre-tool-use)\n        run_hook rules-guard.sh\n        run_hook env-file-protect.sh\n        run_hook main-branch-code-warning.sh\n        case "$TOOL_NAME" in\n            Bash|"")\n                run_hook destructive-command-block.sh\n                run_hook docker-build-check.sh\n                run_hook language-version-check.sh\n                run_hook local-command-block.sh\n                run_hook admin-command-block.sh\n                run_hook secret-leak-check.sh\n                ;;\n        esac\n        ;;\n    post-tool-use)\n        run_hook context-monitor.sh\n        ;;\n    user-prompt-submit)\n        run_hook rules-inject.sh\n        run_hook context-monitor.sh\n        run_hook primary-source-check.sh\n        run_hook methodology-skill-reminder.sh\n        ;;\n    pre-compact)\n        run_hook pre-compact-backup.sh\n        ;;\n    session-start)\n        run_hook rules-inject.sh\n        run_hook session-start-reminder.sh\n        run_hook session-resume.sh\n        run_hook project-environment-check.sh\n        run_hook primary-source-reminder.sh\n        ;;\n    *)\n        echo "hook-dispatcher.sh: unknown event: ${EVENT}" >&2\n        exit 0\n        ;;\nesac\n\nexit 0\n'
def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument('--repo', default='.')
    root=pathlib.Path(ap.parse_args().repo).resolve()
    path=root/'codex'/'hooks'/'hook-dispatcher.sh'
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not (path.with_name(path.name+'.pre-plugin-only.bak')).exists():
        path.with_name(path.name+'.pre-plugin-only.bak').write_text(path.read_text(encoding='utf-8'), encoding='utf-8')
    path.write_text(DISPATCHER, encoding='utf-8')
    path.chmod(0o755)
    print(f'patched {path}')
    return 0
if __name__ == '__main__':
    raise SystemExit(main())
