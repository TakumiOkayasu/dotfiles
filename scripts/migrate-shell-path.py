#!/usr/bin/env python3
"""Preview extraction of PATH assignments from a shell startup file."""

import argparse
import io
import re
import shutil
import subprocess
import sys
from pathlib import Path


STARTUP_SHELLS = {
    ".bashrc": "bash",
    ".bash_profile": "bash",
    ".bash_login": "bash",
    ".profile": "bash",
    ".zshenv": "zsh",
    ".zprofile": "zsh",
    ".zshrc": "zsh",
    ".zlogin": "zsh",
}
PATH_REFERENCE = r"(?:\$PATH|\$\{PATH\})"
DIRECTORY = r"(?:\$HOME|\$\{HOME\})?/[\w./ +@%=-]*"
PATH_ASSIGNMENT = re.compile(
    rf'(?:export[ \t]+)?PATH="(?:{DIRECTORY}:{PATH_REFERENCE}|{PATH_REFERENCE}:{DIRECTORY})"[ \t]*\n'
)


def parses(shell: str, source: str) -> bool:
    result = subprocess.run(
        [shell, "-fn"], input=source, env={}, capture_output=True, text=True,
        check=False, timeout=10,
    )
    return result.returncode == 0 and not result.stderr


def migration_patch(home: Path, startup: str, selected: str) -> str:
    line_range = re.fullmatch(r"([1-9][0-9]*)(?::([1-9][0-9]*))?", selected)
    if line_range is None:
        raise SystemExit("行番号は N または N:M で指定してください")
    first = int(line_range[1])
    last = int(line_range[2] or line_range[1])

    rc = home / startup
    destination = Path(".config/shell/path") / f"{startup[1:]}.sh"
    if rc.is_symlink() or not rc.is_file():
        raise SystemExit(f"{startup}: 通常ファイルを指定してください")
    target = home / destination
    if target.exists() or target.is_symlink():
        raise SystemExit(f"{destination}: 移管先がすでに存在します")
    for parent in target.parents:
        if parent == home:
            break
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise SystemExit(f"{destination}: 移管先の親が通常のディレクトリではありません")

    lines = list(io.StringIO(rc.read_bytes().decode("utf-8")))
    if not first <= last <= len(lines):
        raise SystemExit(f"{startup}: 行番号が範囲外です")
    assignments = lines[first - 1:last]
    if not all(PATH_ASSIGNMENT.fullmatch(line) for line in assignments):
        raise SystemExit(f"{startup}: 指定範囲には対応する PATH 代入だけを含めてください")

    shell = shutil.which(STARTUP_SHELLS[startup])
    if shell is None:
        raise SystemExit(f"{STARTUP_SHELLS[startup]} が見つかりません")
    prefix = "".join(lines[:first - 1])
    # A stray ')' must fail to parse at a command boundary. An open heredoc can
    # accept it as data even when the parser accepted the unfinished prefix.
    if prefix.endswith("\\\n") or not parses(shell, prefix) or parses(shell, prefix + ")\n"):
        raise SystemExit(f"{startup}: 独立した PATH 代入の開始行を指定してください")

    return render_patch(startup, destination, first, assignments)


def render_patch(startup: str, destination: Path, first: int, assignments: list[str]) -> str:
    count = len(assignments)
    return "".join([
        f"--- a/{startup}\n+++ b/{startup}\n@@ -{first},{count} +{first} @@\n",
        *("-" + line for line in assignments),
        f'+. "$HOME/{destination}"\n',
        f"--- /dev/null\n+++ b/{destination}\n@@ -0,0 +1,{count} @@\n",
        *("+" + line for line in assignments),
    ])


def main() -> int:
    parser = argparse.ArgumentParser(description="Bash/Zsh の PATH 設定を移管するパッチを表示します")
    parser.add_argument("startup", choices=STARTUP_SHELLS)
    parser.add_argument("lines", metavar="N[:M]", help="移管する連続した行の範囲")
    args = parser.parse_args()
    try:
        patch = migration_patch(Path.home(), args.startup, args.lines)
    except (OSError, UnicodeError, subprocess.TimeoutExpired):  # codex-rule-ignore: report IO and syntax-check failures at the CLI boundary
        raise SystemExit("起動ファイルの読み込みまたは構文確認に失敗しました") from None
    sys.stdout.write(patch)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
