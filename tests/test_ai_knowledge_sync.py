#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "ai-knowledge-sync"


def run(*args: str, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [*args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )
    if check and result.returncode != 0:
        raise AssertionError(
            f"command failed ({result.returncode}): {' '.join(args)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def git(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run("git", "-C", str(repo), *args, check=check)


def init_repo(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    git(path, "init", "-q")
    git(path, "config", "user.email", "test@example.com")
    git(path, "config", "user.name", "Test")
    (path / "README.md").write_text("test\n", encoding="utf-8")
    git(path, "add", "--", "README.md")
    git(path, "commit", "-q", "-m", "initial")


def write_manifest(project: Path, project_id: str, *, enabled: bool, owner: str = "dotfile-work") -> None:
    ai = project / ".ai"
    (ai / "state").mkdir(parents=True, exist_ok=True)
    (ai / "inbox").mkdir(parents=True, exist_ok=True)
    (ai / "knowledge").mkdir(parents=True, exist_ok=True)
    (ai / "manifest.toml").write_text(
        "\n".join(
            [
                "schema_version = 1",
                f'owner = "{owner}"',
                f'project_id = "{project_id}"',
                "",
                "[export]",
                f"enabled = {'true' if enabled else 'false'}",
                "",
            ]
        ),
        encoding="utf-8",
    )


def make_project(root: Path, name: str, project_id: str, *, enabled: bool = True, owner: str = "dotfile-work") -> Path:
    project = root / name
    init_repo(project)
    write_manifest(project, project_id, enabled=enabled, owner=owner)
    (project / ".ai" / "knowledge" / "finding.md").write_text(
        f"# {name}\n\nReusable finding.\n", encoding="utf-8"
    )
    return project


def sync(source: Path, repository: Path, *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run(
        str(SCRIPT),
        "--source-root",
        str(source),
        "--repository",
        str(repository),
        "--no-push",
        check=check,
    )


def index(repository: Path) -> dict[str, object]:
    return json.loads((repository / "index.json").read_text(encoding="utf-8"))


def main() -> int:
    assert SCRIPT.is_file(), SCRIPT

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / "prog"
        source.mkdir()

        project_a = make_project(
            source, "project-a", "github.com/example/project-a", enabled=True
        )
        project_b = make_project(
            source, "project-b", "github.com/example/project-b", enabled=True
        )
        make_project(
            source,
            "foreign-ai",
            "github.com/example/foreign-ai",
            enabled=True,
            owner="another-tool",
        )

        # Only immediate children of ~/prog are projects. Nested repositories are ignored.
        nested = source / "group" / "nested-project"
        make_project(
            source / "group", "nested-project", "github.com/example/nested", enabled=True
        )
        assert nested.is_dir()

        # Keep the central private repository under the same ~/prog root to verify self-skip.
        repository = source / "ai-knowledge-private"
        init_repo(repository)

        first = sync(source, repository)
        assert "projects synced: 2" in first.stdout
        data = index(repository)
        projects = data["projects"]
        assert isinstance(projects, list) and len(projects) == 2
        ids = {item["project_id"] for item in projects}
        assert ids == {
            "github.com/example/project-a",
            "github.com/example/project-b",
        }
        for item in projects:
            copied = repository / item["path"] / "knowledge" / "finding.md"
            assert copied.is_file(), copied

        first_commit_count = int(git(repository, "rev-list", "--count", "HEAD").stdout)
        second = sync(source, repository)
        assert "committed: no" in second.stdout
        assert int(git(repository, "rev-list", "--count", "HEAD").stdout) == first_commit_count

        # Opting out removes only the previously managed current-tree copy.
        previous_b_path = next(
            item["path"]
            for item in projects
            if item["project_id"] == "github.com/example/project-b"
        )
        write_manifest(
            project_b, "github.com/example/project-b", enabled=False
        )
        sync(source, repository)
        data = index(repository)
        assert [item["project_id"] for item in data["projects"]] == [
            "github.com/example/project-a"
        ]
        assert not (repository / previous_b_path).exists()

        # A selected project containing sensitive-looking files fails before destination mutation.
        (project_a / ".ai" / ".env").write_text("TOKEN=do-not-copy\n", encoding="utf-8")
        before = git(repository, "rev-parse", "HEAD").stdout.strip()
        rejected = sync(source, repository, check=False)
        assert rejected.returncode != 0
        assert "sensitive-looking path" in rejected.stderr
        assert git(repository, "rev-parse", "HEAD").stdout.strip() == before
        assert git(repository, "status", "--porcelain").stdout.strip() == ""
        (project_a / ".ai" / ".env").unlink()

        # A dirty central repository is never overwritten.
        (repository / "local-note.txt").write_text("unsaved\n", encoding="utf-8")
        dirty = sync(source, repository, check=False)
        assert dirty.returncode != 0
        assert "uncommitted changes" in dirty.stderr

    print("test_ai_knowledge_sync: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
