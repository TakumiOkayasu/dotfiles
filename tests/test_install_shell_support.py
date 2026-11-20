"""Installer support matches the shipped shell configurations."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

from tests.install_helpers import copy_installer, run_installer_functions

ROOT = Path(__file__).resolve().parent.parent



def test_fish_login_uses_supported_default(tmp_path):
    result = run_installer_functions(tmp_path, "detect_current_shell", shell="/usr/bin/fish")
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "bash"


def test_shell_menu_offers_only_shipped_shells(tmp_path):
    result = run_installer_functions(
        tmp_path, 'select_shell_type; printf "selected=%s\\n" "$SHELL_TYPE"',
        input_text="3\n",
    )
    assert result.returncode == 0, result.stderr
    assert "fish" not in result.stdout.lower()
    assert "selected=all" in result.stdout


@pytest.mark.parametrize("mode", ["full", "append"])
def test_all_shell_preview_excludes_fish(tmp_path, mode):
    result = run_installer_functions(
        tmp_path, f'SHELL_TYPE=all; SHELL_COMPONENTS={mode}; _preview_shell; get_shell_rc_display all; show_help',
    )
    assert result.returncode == 0, result.stderr
    assert "fish" not in result.stdout.lower()


def test_full_install_only_requests_shipped_shell_sources(tmp_path):
    result = run_installer_functions(tmp_path, '''
        shell_link_specs all
    ''')
    assert result.returncode == 0, result.stderr
    sources = [spec.split(":", 1)[0] for spec in result.stdout.splitlines()]
    assert sources
    assert all((ROOT / source).is_file() for source in sources)
    assert not any("fish" in source for source in sources)


def test_append_all_preserves_fish_config(tmp_path):
    home = tmp_path / "home"
    fish = home / ".config/fish/config.fish"
    fish.parent.mkdir(parents=True)
    fish.write_text("# user fish config\n")
    for shell in ("bash", "zsh"):
        (home / f".{shell}rc").write_text("# user config\n")
    result = run_installer_functions(tmp_path, '''
        apply_link_package() { :; }
        SHELL_TYPE=all
        install_shell_append
    ''')
    assert result.returncode == 0, result.stderr
    assert fish.read_text() == "# user fish config\n"
    for shell in ("bash", "zsh"):
        assert ".shell_common" in (home / f".{shell}rc").read_text()


@pytest.mark.parametrize("shell", ["bash", "zsh"])
@pytest.mark.parametrize("legacy", [False, True])
def test_append_does_not_write_through_managed_shell_links(
    tmp_path: Path, shell: str, legacy: bool,
) -> None:
    checkout = tmp_path / "checkout"
    source = checkout / "config/shell" / shell / f"{shell}rc"
    source.parent.mkdir(parents=True)
    source.write_text("# managed config\n")
    home = tmp_path / "home"
    home.mkdir()
    rc = home / f".{shell}rc"
    target = source
    if legacy:
        target = checkout / ".stow-work/shell" / rc.name
        target.parent.mkdir(parents=True)
        target.symlink_to(Path("../../config/shell") / shell / source.name)
    rc.symlink_to(target)

    result = run_installer_functions(tmp_path, f'''
        DOTFILES_DIR="$HOME/../checkout"
        apply_link_package() {{ :; }}
        SHELL_TYPE={shell}
        install_shell_append
    ''')

    assert result.returncode == 0, result.stdout + result.stderr
    assert rc.readlink() == target
    assert source.read_text() == "# managed config\n"


@pytest.mark.parametrize("interpreter", ["sh", "bash"])
@pytest.mark.parametrize("existing", [
    "", "# user config", "# user config\n", "# user config\n\n",
])
def test_append_preserves_content_and_completes_with_errexit(
    tmp_path: Path, interpreter: str, existing: str,
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    rc = home / ".zshrc"
    rc.write_text(existing)
    commands = '''
        append_shell_common_to_rc zsh
        printf 'completed\\n'
    '''
    result = run_installer_functions(tmp_path, commands, interpreter=interpreter)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "completed" in result.stdout
    prefix = existing + ("\n" if existing and not existing.endswith("\n") else "")
    expected = (
        prefix + '\n# === dotfile-work: BEGIN ===\n'
        '[ -f "$HOME/.shell_common" ] && . "$HOME/.shell_common"\n'
        '# === dotfile-work: END ===\n'
    )
    assert rc.read_text() == expected

    result = run_installer_functions(tmp_path, commands, interpreter=interpreter)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "completed" in result.stdout
    assert rc.read_text() == expected


@pytest.mark.parametrize("interpreter", ["sh", "bash"])
def test_trailing_newline_write_failure_stops_install(
    tmp_path: Path, interpreter: str,
) -> None:
    home = tmp_path / "home"
    home.mkdir()
    rc = home / ".zshrc"
    rc.write_text("# no newline")
    result = run_installer_functions(tmp_path, '''
        printf() { return 73; }
        _ensure_trailing_newline "$HOME/.zshrc"
        echo unexpected-success
    ''', interpreter=interpreter)
    assert result.returncode == 73, result.stdout + result.stderr
    assert "unexpected-success" not in result.stdout
    assert rc.read_text() == "# no newline"


def test_interactive_append_continues_to_git_and_cli_install(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    home = tmp_path / "home"
    home.mkdir()
    (repo / "scripts").mkdir(parents=True)
    copy_installer(repo)
    shutil.copy2(ROOT / "scripts/stow-install.sh", repo / "scripts/stow-install.sh")
    shutil.copytree(ROOT / "config", repo / "config")
    (repo / "bin").mkdir()
    shutil.copy2(ROOT / "bin/git-new-feature", repo / "bin/git-new-feature")
    rc = home / ".zshrc"
    rc.write_text("# user config\n")
    (home / ".shell_common").symlink_to(repo / "config/shell/common.sh")

    for _ in range(2):
        result = subprocess.run(
            ["sh", str(repo / "install.sh")],
            check=False, input="1\n\n2\ny\n2\n1\ny\n4\nn\ny\n",
            env={**os.environ, "HOME": str(home), "SHELL": "/bin/zsh"},
            capture_output=True, text=True, timeout=30,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        assert "結果" in result.stdout
        assert rc.read_text().startswith("# user config\n")
        assert rc.read_text().count("# === dotfile-work: BEGIN ===") == 1
        assert (home / ".shell_common").resolve() == repo / "config/shell/common.sh"
        gitconfig = (home / ".gitconfig").read_text()
        assert (repo / "config/git/.gitconfig.common").read_text() in gitconfig
        assert (repo / "config/git/.gitconfig.private").read_text() in gitconfig
        assert (home / ".local/bin/git-new-feature").resolve() == (
            repo / "bin/git-new-feature"
        )


@pytest.mark.parametrize("legacy", ["link", "source_block"])
def test_uninstall_still_cleans_legacy_fish_config(tmp_path, legacy):
    fish = tmp_path / "home/.config/fish/config.fish"
    fish.parent.mkdir(parents=True)
    if legacy == "link":
        fish.symlink_to(ROOT / "config/shell/fish/config.fish")
    else:
        fish.write_text('# user config\n# === dotfile-work: BEGIN ===\nbass source "$HOME/.shell_common"\n# === dotfile-work: END ===\n')
    result = run_installer_functions(tmp_path, '''
        apply_link_package() { :; }
        uninstall_shell_config
    ''')
    assert result.returncode == 0, result.stderr
    if legacy == "link":
        assert not fish.is_symlink()
    else:
        assert fish.read_text() == "# user config\n"
