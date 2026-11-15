"""Category declarations and execution cooperate through explicit contracts."""

from pathlib import Path
import shlex
import shutil

import pytest

from tests.install_helpers import ROOT, run_installer_functions


def repository(tmp_path: Path, *, backend: bool = True) -> Path:
    repo = tmp_path / "repo"
    (repo / "config").mkdir(parents=True)
    (repo / "config/value").write_text("shared settings\n")
    if backend:
        (repo / "scripts").mkdir()
        shutil.copy2(ROOT / "scripts/stow-install.sh", repo / "scripts/stow-install.sh")
    return repo


def test_failed_declaration_preserves_targets(tmp_path: Path) -> None:
    repo = repository(tmp_path)
    home = tmp_path / "home"
    home.mkdir()
    target = home / ".value"
    target.write_text("existing\n")
    result = run_installer_functions(tmp_path, f'''
        DOTFILES_DIR={shlex.quote(str(repo))}
        failing_specs() {{ emit_link_spec config/value .value; return 27; }}
        if apply_link_package sample "$HOME" install failing_specs; then exit 99
        else [ "$?" -eq 27 ]; fi
    ''')
    assert result.returncode == 0, result.stdout + result.stderr
    assert target.read_text() == "existing\n"
    assert not (home / ".value.bak").exists()


def test_invalid_declaration_is_rejected_before_any_backup(tmp_path: Path) -> None:
    repo = repository(tmp_path)
    outside = tmp_path / "outside"
    outside.write_text("keep\n")
    result = run_installer_functions(tmp_path, f'''
        DOTFILES_DIR={shlex.quote(str(repo))}
        if apply_link_package sample "$HOME" install emit_link_spec config/value ../outside; then exit 99
        else [ "$?" -eq 2 ]; fi
    ''')
    assert result.returncode == 0, result.stdout + result.stderr
    assert outside.read_text() == "keep\n"
    assert not (tmp_path / "outside.bak").exists()


def test_missing_backend_is_detected_before_target_preparation(tmp_path: Path) -> None:
    repo = repository(tmp_path, backend=False)
    home = tmp_path / "home"
    home.mkdir()
    target = home / ".value"
    target.write_text("existing\n")
    result = run_installer_functions(tmp_path, f'''
        DOTFILES_DIR={shlex.quote(str(repo))}
        if apply_link_package sample "$HOME" install emit_link_spec config/value .value; then exit 99
        else [ "$?" -eq 1 ]; fi
    ''')
    assert result.returncode == 0, result.stdout + result.stderr
    assert target.read_text() == "existing\n"
    assert not (home / ".value.bak").exists()


@pytest.mark.parametrize("interpreter", ["sh", "bash"])
def test_destination_is_explicit_and_independent_of_producer_scratch(tmp_path: Path, interpreter: str) -> None:
    repo = repository(tmp_path)
    destination = tmp_path / "runtime"
    destination.mkdir()
    result = run_installer_functions(tmp_path, f'''
        DOTFILES_DIR={shlex.quote(str(repo))}
        STOW_TARGET_DIR=caller-value
        declarations() {{ _package=other; _spec_file=/missing; emit_link_spec config/value .value; }}
        apply_link_package sample {shlex.quote(str(destination))} install declarations
        [ "$STOW_TARGET_DIR" = caller-value ]
    ''', interpreter=interpreter)
    assert result.returncode == 0, result.stdout + result.stderr
    assert (destination / ".value").readlink() == repo / "config/value"
    assert not (tmp_path / "home/.value").exists()


def test_failed_content_composer_never_replaces_file_or_backup(tmp_path: Path) -> None:
    home = tmp_path / "home"
    home.mkdir()
    target = home / ".generated"
    target.write_text("existing\n")
    backup = home / ".generated.bak"
    backup.write_text("previous\n")
    result = run_installer_functions(tmp_path, '''
        failing_content() { printf 'partial'; return 31; }
        if install_generated_file "$HOME/.generated" example failing_content; then exit 99
        else [ "$?" -eq 31 ]; fi
    ''')
    assert result.returncode == 0, result.stdout + result.stderr
    assert target.read_text() == "existing\n"
    assert backup.read_text() == "previous\n"


@pytest.mark.parametrize("runtime", ["claude", "codex"])
def test_category_propagates_failed_deployment_to_checked_caller(tmp_path: Path, runtime: str) -> None:
    result = run_installer_functions(tmp_path, f'''
        {runtime.upper()}_SELECTED=true
        deploy_runtime_assets() {{ return 37; }}
        _claude_setup_vendor_skills() {{ echo unexpected-after-failure; }}
        _codex_generate_config_from_template() {{ echo unexpected-after-failure; }}
        if install_{runtime}_config; then exit 99
        else [ "$?" -eq 37 ]; fi
    ''')
    assert result.returncode == 0, result.stdout + result.stderr
    assert "unexpected-after-failure" not in result.stdout


def test_uninstall_manifest_uses_the_same_preflight_as_declarations(tmp_path: Path) -> None:
    repo = repository(tmp_path)
    marker = tmp_path / "backend-called"
    backend = repo / "scripts/stow-install.sh"
    backend.write_text(f"#!/bin/sh\ntouch {shlex.quote(str(marker))}\n")
    manifest = repo / ".stow-work/.manifests/sample.links"
    manifest.parent.mkdir(parents=True)
    manifest.write_text("config/value:../outside\n")
    result = run_installer_functions(tmp_path, f'''
        DOTFILES_DIR={shlex.quote(str(repo))}
        empty_specs() {{ :; }}
        if apply_link_package sample "$HOME" uninstall empty_specs; then exit 99
        else [ "$?" -eq 2 ]; fi
    ''')
    assert result.returncode == 0, result.stdout + result.stderr
    assert not marker.exists()


@pytest.mark.parametrize("interpreter", ["sh", "bash"])
def test_append_failure_propagates_through_a_checked_category(tmp_path: Path, interpreter: str) -> None:
    home = tmp_path / "home"
    home.mkdir()
    rc = home / ".bashrc"
    rc.write_text("# unterminated")
    result = run_installer_functions(tmp_path, '''
        apply_link_package() { :; }
        printf() { return 43; }
        SHELL_TYPE=bash
        if install_shell_append; then exit 99
        else [ "$?" -eq 43 ]; fi
    ''', interpreter=interpreter)
    assert result.returncode == 0, result.stdout + result.stderr
    assert rc.read_text() == "# unterminated"


@pytest.mark.parametrize("runtime", ["claude", "codex"])
def test_legacy_link_removal_propagates_failure_under_checked_caller(tmp_path: Path, runtime: str) -> None:
    result = run_installer_functions(tmp_path, f'''
        remove_link() {{ return 41; }}
        if _{runtime}_unlink_managed_files; then exit 99
        else [ "$?" -eq 41 ]; fi
    ''')
    assert result.returncode == 0, result.stdout + result.stderr


def test_vendor_setup_stops_at_first_failed_link(tmp_path: Path) -> None:
    vendor = tmp_path / "home/.claude/vendor/agent-skills"
    (vendor / ".git").mkdir(parents=True)
    (vendor / "skills").mkdir()
    result = run_installer_functions(tmp_path, '''
        VENDOR_SKILLS='first second'
        _claude_vendor_link_skill() {
            if [ "$2" = first ]; then return 47; fi
            echo unexpected-second-link
        }
        if _claude_setup_vendor_skills; then exit 99
        else [ "$?" -eq 47 ]; fi
    ''')
    assert result.returncode == 0, result.stdout + result.stderr
    assert "unexpected-second-link" not in result.stdout


def test_vendor_removal_reports_failed_checkout_cleanup(tmp_path: Path) -> None:
    vendor = tmp_path / "home/.claude/vendor/agent-skills"
    vendor.mkdir(parents=True)
    result = run_installer_functions(tmp_path, '''
        VENDOR_SKILLS=''
        rm() { return 53; }
        if _claude_unlink_vendor_skills; then exit 99
        else [ "$?" -eq 1 ]; fi
    ''')
    assert result.returncode == 0, result.stdout + result.stderr
    assert vendor.is_dir()
