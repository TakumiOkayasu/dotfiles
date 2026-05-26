#!/usr/bin/env python3
"""Idempotently wire prompt/rules hooks into codex/hooks/hook-dispatcher.sh."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--repo", default=".")
    return p.parse_args()


def ensure_after(text: str, anchor: str, line: str) -> str:
    if line in text:
        return text
    idx = text.find(anchor)
    if idx == -1:
        return text
    insert_at = idx + len(anchor)
    return text[:insert_at] + "\n" + line + text[insert_at:]


def patch_dispatcher(path: Path) -> bool:
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("""#!/bin/sh
EVENT="${1:-}"
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P || dirname "$0")
INPUT=$(cat)
run_hook() {
    _hook="$1"
    [ -x "${SCRIPT_DIR}/${_hook}" ] || return 0
    printf '%s\n' "$INPUT" | "${SCRIPT_DIR}/${_hook}"
    _status=$?
    [ "$_status" -eq 2 ] && exit 2
    return 0
}
case "$EVENT" in
    pre-tool-use)
        run_hook rules-guard.sh
        ;;
    user-prompt-submit)
        run_hook prompt-command-expand.sh
        run_hook rules-inject.sh
        ;;
    session-start)
        run_hook rules-inject.sh
        ;;
esac
exit 0
""", encoding="utf-8")
        return True

    original = path.read_text(encoding="utf-8")
    text = original

    # Add rules guard as the first pre-tool-use guard.
    text = ensure_after(text, "    pre-tool-use)", "        run_hook rules-guard.sh")

    # Expand prompt command before other prompt reminders, then inject rules.
    text = ensure_after(text, "    user-prompt-submit)", "        run_hook prompt-command-expand.sh")
    text = ensure_after(text, "        run_hook prompt-command-expand.sh", "        run_hook rules-inject.sh")

    # Inject at session start too; the hook is checksum-aware and cheap after first load.
    text = ensure_after(text, "    session-start)", "        run_hook rules-inject.sh")

    if text != original:
        backup = path.with_name(path.name + ".pre-rules-port.bak")
        if not backup.exists():
            backup.write_text(original, encoding="utf-8")
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> int:
    args = parse_args()
    repo = Path(args.repo).resolve()
    path = repo / "codex" / "hooks" / "hook-dispatcher.sh"
    changed = patch_dispatcher(path)
    print(f"patched {path.relative_to(repo)}: {changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
