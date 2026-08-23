#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "ai-knowledge-search"


def run(*args: str, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [*args], cwd=cwd, text=True, capture_output=True, check=False
    )
    if check and result.returncode != 0:
        raise AssertionError(
            f"command failed ({result.returncode}): {' '.join(args)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def make_ai(project: Path, project_id: str) -> None:
    (project / ".ai" / "knowledge").mkdir(parents=True)
    (project / ".ai" / "inbox").mkdir(parents=True)
    (project / ".ai" / "manifest.toml").write_text(
        f'schema_version = 1\nowner = "dotfile-work"\nproject_id = "{project_id}"\n',
        encoding="utf-8",
    )


def main() -> int:
    assert SCRIPT.is_file(), SCRIPT

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        current = root / "current"
        make_ai(current, "github.com/example/current")
        (current / ".ai" / "knowledge" / "local.md").write_text(
            "# Atomic publish\n\nUse an atomic tree after validation.\n",
            encoding="utf-8",
        )
        (current / ".ai" / "inbox" / "candidate.md").write_text(
            "# Candidate\n\nAtomic candidate not verified.\n",
            encoding="utf-8",
        )

        repository = root / "central"
        other = repository / "projects" / "other--123"
        make_ai(other, "ignored")
        # Collector copies the contents of .ai directly into projects/<key>/.
        copied = repository / "projects" / "other--123"
        (copied / "knowledge").mkdir(parents=True, exist_ok=True)
        (copied / "knowledge" / "remote.md").write_text(
            "# Cross project\n\nAtomic generation prevents partial state.\n",
            encoding="utf-8",
        )

        duplicate = repository / "projects" / "current--456"
        (duplicate / "knowledge").mkdir(parents=True)
        (duplicate / "knowledge" / "duplicate.md").write_text(
            "Atomic current copy should be skipped.\n",
            encoding="utf-8",
        )

        (repository / "index.json").write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "projects": [
                        {
                            "project_id": "github.com/example/other",
                            "path": "projects/other--123",
                        },
                        {
                            "project_id": "github.com/example/current",
                            "path": "projects/current--456",
                        },
                    ],
                }
            ),
            encoding="utf-8",
        )

        result = run(
            str(SCRIPT),
            "atomic",
            "generation",
            "--repository",
            str(repository),
            "--json",
            cwd=current,
        )
        data = json.loads(result.stdout)
        ids = {item["project_id"] for item in data}
        assert "github.com/example/current" in ids
        assert "github.com/example/other" in ids
        assert len([item for item in data if item["project_id"] == "github.com/example/current"]) == 1
        assert all(item["kind"] == "knowledge" for item in data)

        inbox = run(
            str(SCRIPT),
            "candidate",
            "--repository",
            str(repository),
            "--include-inbox",
            "--json",
            cwd=current,
        )
        inbox_data = json.loads(inbox.stdout)
        assert any(item["kind"] == "inbox" for item in inbox_data)

        env = os.environ.copy()
        env["AI_KNOWLEDGE_REPOSITORY"] = str(repository)
        from_env = subprocess.run(
            [str(SCRIPT), "partial", "state", "--json"],
            cwd=current,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        assert from_env.returncode == 0, from_env.stderr
        assert any(
            item["project_id"] == "github.com/example/other"
            for item in json.loads(from_env.stdout)
        )

    print("test_ai_knowledge_search: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
