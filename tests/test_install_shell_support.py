"""Installer support matches the shipped shell configurations."""

import os
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent


def run_installer_functions(tmp_path, commands, *, input_text="", shell="/bin/bash"):
    home = tmp_path / "home"
    home.mkdir(exist_ok=True)
    library = (ROOT / "install.sh").read_text().rsplit('\nmain "$@"', 1)[0]
    runner = tmp_path / "install.sh"
    runner.write_text(library + f'\nDOTFILES_DIR="{ROOT}"\n' + commands + "\n")
    return subprocess.run(
        ["sh", str(runner)], input=input_text, capture_output=True, text=True,
        env={**os.environ, "HOME": str(home), "SHELL": shell}, check=False,
    )


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
        stow_specs_add() { printf '%s\\n' "$2"; }
        add_shell_full_stow_specs unused all
    ''')
    assert result.returncode == 0, result.stderr
    sources = result.stdout.splitlines()
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
        install_stow_specs_file() { :; }
        SHELL_TYPE=all
        install_shell_append || exit $?
    ''')
    assert result.returncode == 0, result.stderr
    assert fish.read_text() == "# user fish config\n"
    for shell in ("bash", "zsh"):
        assert ".shell_common" in (home / f".{shell}rc").read_text()


@pytest.mark.parametrize("legacy", ["link", "source_block"])
def test_uninstall_still_cleans_legacy_fish_config(tmp_path, legacy):
    fish = tmp_path / "home/.config/fish/config.fish"
    fish.parent.mkdir(parents=True)
    if legacy == "link":
        fish.symlink_to(ROOT / "config/shell/fish/config.fish")
    else:
        fish.write_text('# user config\n# === dotfile-work: BEGIN ===\nbass source "$HOME/.shell_common"\n# === dotfile-work: END ===\n')
    result = run_installer_functions(tmp_path, '''
        uninstall_stow_specs_file() { :; }
        uninstall_shell_config
    ''')
    assert result.returncode == 0, result.stderr
    if legacy == "link":
        assert not fish.is_symlink()
    else:
        assert fish.read_text() == "# user config\n"
