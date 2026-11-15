"""Safety contracts found by the installer deep review, using disposable homes."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess

import pytest

from tests.install_helpers import ROOT, copy_installer, run_installer_functions


def git_sources(tmp_path: Path) -> Path:
    repo = tmp_path / "repo"
    directory = repo / "config/git"
    directory.mkdir(parents=True)
    for stem in ("gitconfig", "gitignore"):
        for variant, text in (("common", "shared\n"), ("work", "work\n"), ("private", "private\n")):
            (directory / f".{stem}.{variant}").write_text(text)
    return repo


def snapshot(directory: Path) -> dict[str, tuple[str, str]]:
    result = {}
    for path in directory.rglob("*"):
        if path.is_symlink():
            result[str(path.relative_to(directory))] = ("link", str(path.readlink()))
        elif path.is_file():
            result[str(path.relative_to(directory))] = ("file", path.read_text())
    return result


@pytest.mark.parametrize("interpreter", ["sh", "bash"])
def test_git_dry_run_preserves_files_and_backups(tmp_path: Path, interpreter: str) -> None:
    repo = git_sources(tmp_path)
    home = tmp_path / "home"
    (home / ".config/git").mkdir(parents=True)
    (home / ".gitconfig").write_text("shared\nwork\n")
    (home / ".gitconfig.common").write_text("shared\n")
    (home / ".config/git/ignore").write_text("shared\nwork\n")
    for target in (home / ".gitconfig", home / ".gitconfig.common", home / ".config/git/ignore"):
        Path(str(target) + ".bak").write_text("original\n")
    before = snapshot(home)
    result = run_installer_functions(
        tmp_path, f'DOTFILES_DIR={shlex.quote(str(repo))}\nMODE_DRY_RUN=true\n'
        'uninstall_gitconfig\nuninstall_gitignore\n', interpreter=interpreter,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert snapshot(home) == before


def test_git_uninstall_preserves_edited_ignore_and_backup(tmp_path: Path) -> None:
    repo = git_sources(tmp_path)
    home = tmp_path / "home"
    (home / ".config/git").mkdir(parents=True)
    ignore = home / ".config/git/ignore"
    ignore.write_text("personal rules\n")
    backup = Path(str(ignore) + ".bak")
    backup.write_text("original rules\n")
    result = run_installer_functions(tmp_path, f'DOTFILES_DIR={shlex.quote(str(repo))}\nuninstall_gitignore')
    assert result.returncode == 0, result.stdout + result.stderr
    assert ignore.read_text() == "personal rules\n"
    assert backup.read_text() == "original rules\n"


@pytest.mark.parametrize("stem", ["gitconfig", "gitignore"])
def test_uninstall_recognizes_private_variant_without_current_selection(tmp_path: Path, stem: str) -> None:
    repo = git_sources(tmp_path)
    home = tmp_path / "home"
    (home / ".config/git").mkdir(parents=True)
    target = home / (".gitconfig" if stem == "gitconfig" else ".config/git/ignore")
    target.write_text("shared\nprivate\n")
    backup = Path(str(target) + ".bak")
    backup.write_text("original\n")
    result = run_installer_functions(tmp_path, f'DOTFILES_DIR={shlex.quote(str(repo))}\nuninstall_{stem}')
    assert result.returncode == 0, result.stdout + result.stderr
    assert target.read_text() == "original\n"
    assert not backup.exists()


def test_vendor_dry_run_preserves_dangling_link(tmp_path: Path) -> None:
    home = tmp_path / "home"
    (home / ".claude/skills").mkdir(parents=True)
    source = tmp_path / "vendor/skills/sample"
    source.mkdir(parents=True)
    target = home / ".claude/skills/sample"
    target.symlink_to("missing-user-skill")
    result = run_installer_functions(tmp_path, f'MODE_DRY_RUN=true\n_claude_vendor_link_skill {shlex.quote(str(tmp_path / "vendor"))} sample')
    assert result.returncode == 0, result.stdout + result.stderr
    assert target.is_symlink()
    assert str(target.readlink()) == "missing-user-skill"


def test_vendor_uninstall_preserves_user_replacement_link(tmp_path: Path) -> None:
    home = tmp_path / "home"
    (home / ".claude/skills").mkdir(parents=True)
    source = tmp_path / "custom-skill"
    source.mkdir()
    target = home / ".claude/skills/sample"
    target.symlink_to(source)
    result = run_installer_functions(tmp_path, 'VENDOR_SKILLS=sample\n_claude_unlink_vendor_skills')
    assert result.returncode == 0, result.stdout + result.stderr
    assert target.is_symlink()
    assert target.readlink() == source


@pytest.mark.parametrize("interpreter", ["sh", "bash"])
def test_partial_uninstall_reports_success(tmp_path: Path, interpreter: str) -> None:
    home = tmp_path / "home"
    home.mkdir()
    target = home / ".vimrc"
    target.symlink_to(ROOT / "config/vim/.vimrc")
    result = run_installer_functions(tmp_path, 'UNINSTALL_VIM=true\nuninstall_files\nprintf "done\\n"', interpreter=interpreter)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "done" in result.stdout
    assert not target.is_symlink()


def test_relative_owned_link_is_removed_from_any_cwd(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    source = repo / "config/vim/.vimrc"
    source.parent.mkdir(parents=True)
    source.write_text("set number\n")
    (repo / "scripts").mkdir()
    shutil.copy2(ROOT / "scripts/stow-install.sh", repo / "scripts/stow-install.sh")
    home = tmp_path / "home"
    home.mkdir()
    target = home / ".vimrc"
    target.symlink_to(os.path.relpath(source, home))
    result = run_installer_functions(tmp_path, f'DOTFILES_DIR={shlex.quote(str(repo))}\nuninstall_vim_files')
    assert result.returncode == 0, result.stdout + result.stderr
    assert not target.is_symlink()


@pytest.mark.parametrize("interpreter", ["sh", "bash"])
@pytest.mark.parametrize("backend_fails", [False, True])
def test_run_owns_temp_resources_with_space_in_tmpdir(tmp_path: Path, interpreter: str, backend_fails: bool) -> None:
    repo = tmp_path / "repo"
    copy_installer(repo)
    shutil.copytree(ROOT / "config/shell", repo / "config/shell")
    backend = repo / "scripts/stow-install.sh"
    if backend_fails:
        backend.write_text("#!/bin/sh\nexit 17\n")
        backend.chmod(0o755)
    else:
        shutil.copy2(ROOT / "scripts/stow-install.sh", backend)
    sentinel = tmp_path / "cache"
    sentinel.write_text("keep\n")
    temporary = tmp_path / "cache area"
    temporary.mkdir()
    home = tmp_path / "home"
    home.mkdir()
    result = subprocess.run(
        [interpreter, str(repo / "install.sh")], input="1\n1\n1\nn\ny\n",
        env={**os.environ, "HOME": str(home), "TMPDIR": str(temporary)},
        capture_output=True, text=True, check=False, timeout=30,
    )
    assert (result.returncode != 0) == backend_fails, result.stdout + result.stderr
    assert sentinel.read_text() == "keep\n"
    assert list(temporary.iterdir()) == []


def test_vendor_uninstall_does_not_consume_an_unowned_backup(tmp_path: Path) -> None:
    home = tmp_path / "home"
    (home / ".claude/skills").mkdir(parents=True)
    source = home / ".claude/vendor/agent-skills/skills/sample"
    source.mkdir(parents=True)
    target = home / ".claude/skills/sample"
    target.symlink_to(source)
    backup = home / ".claude/skills/sample.bak"
    backup.write_text("user backup\n")
    result = run_installer_functions(tmp_path, 'VENDOR_SKILLS=sample\n_claude_unlink_vendor_skills')
    assert result.returncode == 0, result.stdout + result.stderr
    assert not target.exists()
    assert backup.read_text() == "user backup\n"


def test_stale_directory_cleanup_preserves_hidden_user_files(tmp_path: Path) -> None:
    directory = tmp_path / "home/.claude/skills/mixed"
    directory.mkdir(parents=True)
    hidden = directory / ".user-notes"
    hidden.write_text("keep\n")
    (directory / "stale.md").symlink_to(ROOT / "common/skills/removed-example/SKILL.md")
    result = run_installer_functions(tmp_path, 'cleanup_stale_links_in Claude "$HOME/.claude" skills')
    assert result.returncode == 0, result.stdout + result.stderr
    assert hidden.read_text() == "keep\n"
