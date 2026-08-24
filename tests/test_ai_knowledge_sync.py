#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "ai-knowledge-sync"
KEYGEN = ROOT / "bin" / "ai-knowledge-keygen"
PROJECT_REF_RE = re.compile(r"^[0-9a-f]{20}$")
FILE_REF_RE = re.compile(r"^[0-9a-f]{20}\.(?:md|txt|json|jsonl|toml|yaml|yml)$")


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


def write_manifest(
    project: Path,
    project_id: str,
    *,
    enabled: bool,
    include_inbox: bool = False,
    owner: str = "dotfile-work",
) -> None:
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
                f"include_inbox = {'true' if include_inbox else 'false'}",
                "",
            ]
        ),
        encoding="utf-8",
    )


def make_project(
    root: Path,
    name: str,
    project_id: str,
    *,
    enabled: bool = True,
    include_inbox: bool = False,
    owner: str = "dotfile-work",
) -> Path:
    project = root / name
    init_repo(project)
    write_manifest(
        project,
        project_id,
        enabled=enabled,
        include_inbox=include_inbox,
        owner=owner,
    )
    (project / ".ai" / "knowledge" / "finding.md").write_text(
        f"# {name}\n\nReusable finding.\n", encoding="utf-8"
    )
    (project / ".ai" / "inbox" / "candidate.md").write_text(
        f"# {name} candidate\n\nUnverified finding.\n", encoding="utf-8"
    )
    return project


def make_key(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("k" * 64 + "\n", encoding="utf-8")
    if os.name == "posix":
        path.chmod(0o600)


def sync(
    source: Path,
    repository: Path,
    key: Path,
    *,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return run(
        str(SCRIPT),
        "--source-root",
        str(source),
        "--repository",
        str(repository),
        "--redaction-key-file",
        str(key),
        "--no-push",
        check=check,
    )


def index(repository: Path) -> dict[str, object]:
    return json.loads((repository / "index.json").read_text(encoding="utf-8"))


def exported_files(repository: Path) -> list[Path]:
    return sorted(path for path in (repository / "projects").rglob("*") if path.is_file())


def main() -> int:
    assert SCRIPT.is_file(), SCRIPT
    assert KEYGEN.is_file(), KEYGEN

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / "prog"
        source.mkdir()
        key = root / "config" / "redaction.key"
        make_key(key)

        project_a = make_project(
            source, "project-a", "github.com/example/project-a", enabled=True
        )
        project_b = make_project(
            source,
            "project-b",
            "github.com/example/project-b",
            enabled=True,
            include_inbox=True,
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

        (project_a / ".ai" / "knowledge" / "finding.md").write_text(
            "\n".join(
                [
                    "# Sanitized reusable finding",
                    "",
                    "Customer {{private:customer:Acme Corporation}} hit a reusable lock pattern.",
                    "Ticket {{redact:INC-12345}} supplied the original evidence.",
                    f"Local path: {project_a}/src/Worker.php",
                    "Project metadata: github.com/example/project-a",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        # State is local durable state, not an export source. Secrets here must not be copied.
        (project_a / ".ai" / "state" / "qcd-observations.jsonl").write_text(
            '{"token":"state-only-secret-value"}\n', encoding="utf-8"
        )

        # Keep the central private repository under the same ~/prog root to verify self-skip.
        repository = source / "ai-knowledge-private"
        init_repo(repository)

        first = sync(source, repository, key)
        assert "projects exported: 2" in first.stdout
        data = index(repository)
        assert data["schema_version"] == 2
        projects = data["projects"]
        assert isinstance(projects, list) and len(projects) == 2
        assert all(set(item) == {"path", "project_ref"} for item in projects)
        assert all(PROJECT_REF_RE.fullmatch(item["project_ref"]) for item in projects)
        assert all(item["path"] == f"projects/{item['project_ref']}" for item in projects)
        index_text = (repository / "index.json").read_text(encoding="utf-8")
        assert "github.com/example/project-a" not in index_text
        assert "github.com/example/project-b" not in index_text
        assert "project-a" not in index_text
        assert "project-b" not in index_text

        files = exported_files(repository)
        assert files
        assert all(FILE_REF_RE.fullmatch(path.name) for path in files)
        assert not any("state" in path.parts for path in files)
        assert sum("inbox" in path.parts for path in files) == 1
        assert sum("knowledge" in path.parts for path in files) == 2

        corpus = "\n".join(path.read_text(encoding="utf-8") for path in files)
        assert "Acme Corporation" not in corpus
        assert "INC-12345" not in corpus
        assert "github.com/example/project-a" not in corpus
        assert str(project_a) not in corpus
        assert "state-only-secret-value" not in corpus
        assert re.search(r"<customer:[0-9a-f]{12}>", corpus)
        assert "<redacted>" in corpus
        assert "$PROJECT/src/Worker.php" in corpus
        assert re.search(r"<project:[0-9a-f]{20}>", corpus)

        first_commit_count = int(git(repository, "rev-list", "--count", "HEAD").stdout)
        second = sync(source, repository, key)
        assert "committed: no" in second.stdout
        assert int(git(repository, "rev-list", "--count", "HEAD").stdout) == first_commit_count

        # Opting out removes only the previously managed sanitized export.
        previous_paths = {item["path"] for item in projects}
        write_manifest(
            project_b,
            "github.com/example/project-b",
            enabled=False,
            include_inbox=True,
        )
        sync(source, repository, key)
        data = index(repository)
        assert len(data["projects"]) == 1
        remaining_paths = {item["path"] for item in data["projects"]}
        assert len(previous_paths - remaining_paths) == 1
        assert not (repository / next(iter(previous_paths - remaining_paths))).exists()

        # Secret-bearing exportable content fails before destination mutation.
        secret_file = project_a / ".ai" / "knowledge" / "secret.md"
        secret_file.write_text("password=super-secret-value-123\n", encoding="utf-8")
        before = git(repository, "rev-parse", "HEAD").stdout.strip()
        rejected = sync(source, repository, key, check=False)
        assert rejected.returncode != 0
        assert "credential assignment detected" in rejected.stderr
        assert git(repository, "rev-parse", "HEAD").stdout.strip() == before
        assert git(repository, "status", "--porcelain").stdout.strip() == ""
        secret_file.unlink()

        entropy_file = project_a / ".ai" / "knowledge" / "entropy.md"
        entropy_file.write_text(
            "Standalone value: AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_+/=aBcDeFgHiJ\n",
            encoding="utf-8",
        )
        entropy_rejected = sync(source, repository, key, check=False)
        assert entropy_rejected.returncode != 0
        assert "high-entropy token detected" in entropy_rejected.stderr
        entropy_file.unlink()

        # Explicit private markers are the only supported deterministic pseudonymization input.
        malformed = project_a / ".ai" / "knowledge" / "malformed.md"
        malformed.write_text("{{private:customer}}\n", encoding="utf-8")
        rejected = sync(source, repository, key, check=False)
        assert rejected.returncode != 0
        assert "malformed redaction marker" in rejected.stderr
        malformed.unlink()

        # Legacy schema 1 is refused because a normal commit cannot sanitize Git history.
        legacy = root / "legacy-central"
        init_repo(legacy)
        (legacy / "index.json").write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "projects": [
                        {
                            "project_id": "github.com/example/leaked-name",
                            "path": "projects/leaked-name--123",
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        git(legacy, "add", "--", "index.json")
        git(legacy, "commit", "-q", "-m", "legacy")
        legacy_rejected = sync(source, legacy, key, check=False)
        assert legacy_rejected.returncode != 0
        assert "legacy knowledge index schema 1" in legacy_rejected.stderr

        # Missing or weak keys fail before any export.
        missing = root / "missing.key"
        key_rejected = sync(source, repository, missing, check=False)
        assert key_rejected.returncode != 0
        assert "redaction key not found" in key_rejected.stderr
        weak = root / "weak.key"
        weak.write_text("too-short\n", encoding="utf-8")
        if os.name == "posix":
            weak.chmod(0o600)
        weak_rejected = sync(source, repository, weak, check=False)
        assert weak_rejected.returncode != 0
        assert "at least 32 bytes" in weak_rejected.stderr

        # A dirty central repository is never overwritten.
        (repository / "local-note.txt").write_text("unsaved\n", encoding="utf-8")
        dirty = sync(source, repository, key, check=False)
        assert dirty.returncode != 0
        assert "uncommitted changes" in dirty.stderr

        # Key generation is create-only and produces a private file.
        generated = root / "new-config" / "knowledge.key"
        generated_result = run(str(KEYGEN), "--path", str(generated))
        assert generated_result.returncode == 0
        assert len(generated.read_text(encoding="utf-8").strip()) == 64
        if os.name == "posix":
            assert generated.stat().st_mode & 0o077 == 0
        generated_again = run(str(KEYGEN), "--path", str(generated), check=False)
        assert generated_again.returncode != 0
        assert "refusing to overwrite existing key" in generated_again.stderr

    print("test_ai_knowledge_sync: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
