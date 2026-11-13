"""Run shell configuration checks without inheriting the developer's HOME."""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

SHELL_CONFIG = Path(__file__).resolve().parents[1] / "config/shell"
BASH_NON_TTY_DIAGNOSTICS = re.compile(
    r"(?:.*/)?bash: (?:cannot set terminal process group \(-?\d+\): "
    r"Inappropriate ioctl for device|no job control in this shell)\n"
)


def run_shell(
    tmp_path: Path,
    shell: str,
    commands: str,
    *,
    before: str = "",
    environment: dict[str, str] | None = None,
    interactive: bool = True,
    source: Path | None = None,
    source_count: int = 1,
    expected_stderr: str = "",
    path_prefix: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    executable = shutil.which(shell)
    if executable is None:
        pytest.skip(f"{shell} is not installed")
    home = tmp_path / "home"
    home.mkdir(exist_ok=True)
    (home / ".shell_common").write_text("")
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir(exist_ok=True)
    # A system-wide mise/fzf installation must not participate in fake-tool tests.
    system_bin = tmp_path / "system-bin"
    system_bin.mkdir(exist_ok=True)
    for name in (
        "basename",
        "cat",
        "chmod",
        "cut",
        "date",
        "dirname",
        "find",
        "getent",
        "grep",
        "id",
        "ln",
        "locale",
        "ls",
        "mkdir",
        "mv",
        "readlink",
        "rm",
        "sed",
        "sort",
        "stat",
        "tr",
        "uname",
        "wc",
    ):
        target = shutil.which(name)
        link = system_bin / name
        if target is not None and not link.is_symlink():
            link.symlink_to(target)
    paths = (
        [fake_bin, system_bin]
        if path_prefix is None
        else [fake_bin, path_prefix, system_bin]
    )
    source = source or SHELL_CONFIG / shell / f"{shell}rc"
    checked_source = (
        f'source "{source}"\n'
        "_source_status=$?\n"
        'if [ "$_source_status" -ne 0 ]; then exit "$_source_status"; fi\n'
    )
    command = before + "\n" + checked_source * source_count + commands
    args = (
        [executable, "--noprofile", "--norc"]
        if shell == "bash"
        else [executable, "-df"]
    )
    args += ["-ic" if interactive else "-c", command]
    result = subprocess.run(
        args,
        cwd=home,
        env={
            "HOME": str(home),
            "DOTFILES_DIR": str(tmp_path / "no-dotfiles"),
            "PATH": ":".join(str(path) for path in paths),
            "TERM": "xterm",
            "LANG": "C",
            **(environment or {}),
        },
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )
    assert result.returncode == 0, (
        f"Shell exited with status {result.returncode}\n{result.stdout}{result.stderr}"
    )
    # Bash -ic without a TTY emits these two harness diagnostics, not rc warnings.
    stderr = (
        BASH_NON_TTY_DIAGNOSTICS.sub("", result.stderr)
        if shell == "bash"
        else result.stderr
    )
    assert stderr == expected_stderr, f"Unexpected stderr: {stderr!r}"
    return result


def write_command(tmp_path: Path, name: str, body: str) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir(exist_ok=True)
    executable = fake_bin / name
    executable.write_text("#!/bin/sh\n" + body + "\n")
    executable.chmod(0o755)
