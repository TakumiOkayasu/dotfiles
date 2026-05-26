#!/usr/bin/env python3
"""Patch install.sh so every Codex prompt/bin asset in this pack is installed.

The existing installer may only map `codex/bin/*.sh` and
`codex/prompts/commands/*.md`. This pack also ships extensionless bin wrappers
and prompt fragments/templates/evals, so this patch widens the mapping.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

TARGET_PATTERN = "bin/*|hooks/*.sh|prompts/*.md|prompts/commands/*.md|prompts/fragments/*.md|prompts/templates/*.md|prompts/evals/*.md|rules/*.md)"
OLD_PATTERN_RE = re.compile(r"(?m)^(\s*)bin/\*\.sh\|hooks/\*\.sh\|prompts/commands/\*\.md\|rules/\*\.md\)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".", help="dotfile-work repository root")
    return parser.parse_args()


def patch_install(path: Path) -> bool:
    if not path.exists():
        print(f"skip: install.sh not found: {path}", file=sys.stderr)
        return False

    original = path.read_text(encoding="utf-8")
    if TARGET_PATTERN in original:
        return False

    text, count = OLD_PATTERN_RE.subn(lambda m: f"{m.group(1)}{TARGET_PATTERN}", original, count=1)
    if count == 0:
        print("warning: codex_dest_for_relative mapping pattern not found; install.sh unchanged", file=sys.stderr)
        return False

    backup = path.with_name(path.name + ".pre-codex-unified.bak")
    if not backup.exists():
        backup.write_text(original, encoding="utf-8")
    path.write_text(text, encoding="utf-8")
    return True


def main() -> int:
    args = parse_args()
    repo = Path(args.repo).resolve()
    changed = patch_install(repo / "install.sh")
    print(f"patched install.sh Codex mapping: {changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
