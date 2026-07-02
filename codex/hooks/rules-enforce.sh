#!/bin/sh
# rules-enforce.sh - deterministic markdown-rules compliance gate for Codex.
# Delegates to rules-enforce.py. This wrapper exists because hook-dispatcher runs *.sh.

SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(cd "$SCRIPT_DIR" 2>/dev/null && pwd -P) || SCRIPT_DIR=$(dirname "$0")
PYTHON=${PYTHON:-python3}

if command -v "$PYTHON" >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/rules-enforce.py" ]; then
    exec "$PYTHON" "$SCRIPT_DIR/rules-enforce.py" "$@"
fi

# Safe fallback: if Python is unavailable, do not deadlock read-only work.
# Mutating protection is still handled by rules-guard.sh / command-safety.rules.
echo "[rules-enforce] WARN: python3 or rules-enforce.py not found; deterministic rule scan skipped." >&2
exit 0
