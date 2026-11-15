"""Repository settings remain the source of truth without GNU Stow."""

import os
from pathlib import Path
import subprocess

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/stow-install.sh"


def install(repo: Path, home: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["/bin/sh", str(SCRIPT), "--repo", str(repo), "--target", str(home),
         "--package", "shell", "--link", "config/bashrc:.bashrc", *args],
        env={**os.environ, "PATH": "/usr/bin:/bin"},
        capture_output=True, text=True, check=False,
    )


def setup_paths(tmp_path: Path) -> tuple[Path, Path, Path]:
    repo = tmp_path / "repo"
    source = repo / "config/bashrc"
    source.parent.mkdir(parents=True)
    source.write_text("# shared settings\n")
    home = tmp_path / "home"
    home.mkdir()
    return repo, home, source


def test_append_through_installed_rc_changes_tracked_source(tmp_path: Path) -> None:
    repo, home, source = setup_paths(tmp_path)
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    subprocess.run(["git", "-C", str(repo), "add", "config/bashrc"], check=True)
    result = install(repo, home)
    assert result.returncode == 0, result.stderr
    assert (home / ".bashrc").readlink() == source
    with (home / ".bashrc").open("a") as rc:
        rc.write("export TOOL_MODE=shared\n")
    assert "export TOOL_MODE=shared" in source.read_text()
    diff = subprocess.run(["git", "-C", str(repo), "diff", "--", "config/bashrc"],
                          capture_output=True, text=True, check=True)
    assert "+export TOOL_MODE=shared" in diff.stdout


def test_dry_run_does_not_materialize_packages(tmp_path: Path) -> None:
    repo, home, _ = setup_paths(tmp_path)
    result = install(repo, home, "--dry-run")
    assert result.returncode == 0, result.stderr
    assert list(home.iterdir()) == []
    assert not (repo / ".stow-work").exists()


def test_uninstall_preserves_replaced_local_file(tmp_path: Path) -> None:
    repo, home, source = setup_paths(tmp_path)
    assert install(repo, home).returncode == 0
    rc = home / ".bashrc"
    rc.unlink()
    rc.write_text("# local replacement\n")
    result = install(repo, home, "--uninstall")
    assert result.returncode == 0, result.stderr
    assert rc.read_text() == "# local replacement\n"
    assert source.read_text() == "# shared settings\n"


def test_migrates_existing_stow_link_and_reinstalls(tmp_path: Path) -> None:
    repo, home, source = setup_paths(tmp_path)
    stage = repo / ".stow-work/shell/.bashrc"
    stage.parent.mkdir(parents=True)
    stage.symlink_to(source)
    (home / ".bashrc").symlink_to(stage)
    for _ in range(2):
        result = install(repo, home)
        assert result.returncode == 0, result.stderr
        assert (home / ".bashrc").readlink() == source
    result = install(repo, home, "--uninstall")
    assert result.returncode == 0, result.stderr
    assert not (home / ".bashrc").is_symlink()
    assert source.read_text() == "# shared settings\n"


def test_migration_preserves_rc_replaced_inside_old_package(tmp_path: Path) -> None:
    repo, home, source = setup_paths(tmp_path)
    stage = repo / ".stow-work/shell/.bashrc"
    stage.parent.mkdir(parents=True)
    stage.write_text("export TOOL_MODE=uncommitted\n")
    (home / ".bashrc").symlink_to(stage)
    result = install(repo, home)
    assert result.returncode != 0
    assert "unmanaged file" in result.stderr
    assert stage.read_text() == "export TOOL_MODE=uncommitted\n"
    assert (home / ".bashrc").readlink() == stage
    assert source.read_text() == "# shared settings\n"


def test_refuses_unowned_target_without_overwriting(tmp_path: Path) -> None:
    repo, home, source = setup_paths(tmp_path)
    (home / ".bashrc").write_text("# keep existing\n")
    result = install(repo, home)
    assert result.returncode != 0
    assert (home / ".bashrc").read_text() == "# keep existing\n"
    assert source.read_text() == "# shared settings\n"


def test_unfolds_owned_stow_directory_without_using_stow(tmp_path: Path) -> None:
    repo, home, source = setup_paths(tmp_path)
    stage = repo / ".stow-work/shell/.config"
    stage.mkdir(parents=True)
    (stage / "rc").symlink_to(source)
    (home / ".config").symlink_to(stage)
    args = ["/bin/sh", str(SCRIPT), "--repo", str(repo), "--target", str(home),
            "--package", "shell", "--link", "config/bashrc:.config/rc"]
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr
    assert not (home / ".config").is_symlink()
    assert (home / ".config/rc").readlink() == source


def test_never_writes_through_foreign_ancestor_link(tmp_path: Path) -> None:
    repo, home, _ = setup_paths(tmp_path)
    external = tmp_path / "external"
    external.mkdir()
    (external / "sentinel").write_text("keep\n")
    (home / ".config").symlink_to(external)
    result = subprocess.run(
        ["/bin/sh", str(SCRIPT), "--repo", str(repo), "--target", str(home),
         "--package", "shell", "--link", "config/bashrc:.config/rc"],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode != 0
    assert (home / ".config").readlink() == external
    assert list(external.iterdir()) == [external / "sentinel"]
