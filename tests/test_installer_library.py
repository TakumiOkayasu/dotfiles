"""Loading definitions is separate from initializing and running the installer."""

import os
from pathlib import Path
import shutil
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize("shell", ["sh", "bash"])
def test_library_load_preserves_caller_state(tmp_path: Path, shell: str) -> None:
    home = tmp_path / "home"
    home.mkdir()
    result = subprocess.run(
        [shell, "-c", '''
set -eu
INSTALLER_LIB_DIR=$1
DOTFILES_DIR=caller-root
MODE_DRY_RUN=caller-mode
before_options=$-
trap 'printf "caller-exit\\n"' EXIT
before_traps=$(trap)
. "$INSTALLER_LIB_DIR/library.sh"
[ "$DOTFILES_DIR" = caller-root ]
[ "$MODE_DRY_RUN" = caller-mode ]
[ "$-" = "$before_options" ]
[ "$(trap)" = "$before_traps" ]
command -v main >/dev/null
command -v initialize_installer >/dev/null
command -v install_shell_config >/dev/null
printf 'loaded\\n'
''', "sh", str(ROOT / "scripts/install")],
        cwd=tmp_path, env={**os.environ, "HOME": str(home)},
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == "loaded\ncaller-exit\n"
    assert result.stderr == ""
    assert list(home.iterdir()) == []


@pytest.mark.parametrize("shell", ["sh", "bash"])
def test_runtime_root_validation_still_precedes_help(tmp_path: Path, shell: str) -> None:
    result = subprocess.run(
        [shell, str(ROOT / "install.sh"), "--help"], cwd=tmp_path,
        env={**os.environ, "HOME": str(tmp_path), "CODEX_HOME": "relative-root"},
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 2
    assert result.stdout == ""
    assert "runtime config directory must be absolute" in result.stderr


@pytest.mark.parametrize("shell", ["sh", "bash"])
def test_shell_install_uses_repository_root_from_other_cwd(
    tmp_path: Path, shell: str,
) -> None:
    repo = tmp_path / "repository with spaces"
    repo.mkdir()
    shutil.copy2(ROOT / "install.sh", repo / "install.sh")
    shutil.copytree(ROOT / "scripts", repo / "scripts", ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copytree(ROOT / "config/shell", repo / "config/shell")
    home = tmp_path / "home"
    home.mkdir()
    other = tmp_path / "other"
    other.mkdir()
    result = subprocess.run(
        [shell, str(repo / "install.sh")], cwd=other,
        env={**os.environ, "HOME": str(home)}, input="1\n1\n1\nn\ny\n",
        capture_output=True, text=True, check=False, timeout=30,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert (home / ".bashrc").is_symlink()
    assert (home / ".bashrc").readlink() == repo / "config/shell/bash/bashrc"
    assert list(other.iterdir()) == []
