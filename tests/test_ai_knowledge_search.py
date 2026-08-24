#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import hmac
import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "ai-knowledge-search"


def run(*args: str, cwd: Path | None = None, check: bool = True, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [*args], cwd=cwd, env=env, text=True, capture_output=True, check=False
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


def make_key(path: Path) -> bytes:
    value = b"s" * 64
    path.write_bytes(value + b"\n")
    if os.name == "posix":
        path.chmod(0o600)
    return value


def project_ref(key: bytes, project_id: str) -> str:
    payload = f"project\0{project_id}".encode("utf-8")
    return hmac.new(key, payload, hashlib.sha256).hexdigest()[:20]


def main() -> int:
    assert SCRIPT.is_file(), SCRIPT

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        key_file = root / "redaction.key"
        key = make_key(key_file)
        current_id = "github.com/example/current"
        other_id = "github.com/example/other"
        current_ref = project_ref(key, current_id)
        other_ref = project_ref(key, other_id)

        current = root / "current"
        make_ai(current, current_id)
        (current / ".ai" / "knowledge" / "local.md").write_text(
            "# Atomic publish\n\nUse an atomic tree after validation.\n",
            encoding="utf-8",
        )
        (current / ".ai" / "inbox" / "candidate.md").write_text(
            "# Candidate\n\nAtomic candidate not verified.\n",
            encoding="utf-8",
        )

        repository = root / "central"
        other = repository / "projects" / other_ref
        (other / "knowledge").mkdir(parents=True)
        (other / "knowledge" / "a1b2c3d4e5f6a7b8c9d0.md").write_text(
            "# Cross project\n\nAtomic generation prevents partial state.\n",
            encoding="utf-8",
        )
        (other / "inbox").mkdir(parents=True)
        (other / "inbox" / "b1b2c3d4e5f6a7b8c9d0.md").write_text(
            "Remote candidate is still a candidate.\n",
            encoding="utf-8",
        )

        duplicate = repository / "projects" / current_ref
        (duplicate / "knowledge").mkdir(parents=True)
        (duplicate / "knowledge" / "c1b2c3d4e5f6a7b8c9d0.md").write_text(
            "Atomic current copy should be skipped.\n",
            encoding="utf-8",
        )

        (repository / "index.json").write_text(
            json.dumps(
                {
                    "schema_version": 2,
                    "projects": [
                        {"project_ref": other_ref, "path": f"projects/{other_ref}"},
                        {"project_ref": current_ref, "path": f"projects/{current_ref}"},
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
            "--redaction-key-file",
            str(key_file),
            "--json",
            cwd=current,
        )
        data = json.loads(result.stdout)
        ids = {item["project_id"] for item in data}
        assert current_id in ids
        assert other_ref in ids
        assert current_ref not in ids
        assert len([item for item in data if item["project_id"] == current_id]) == 1
        assert all(item["kind"] == "knowledge" for item in data)

        inbox = run(
            str(SCRIPT),
            "candidate",
            "--repository",
            str(repository),
            "--redaction-key-file",
            str(key_file),
            "--include-inbox",
            "--json",
            cwd=current,
        )
        inbox_data = json.loads(inbox.stdout)
        assert any(item["kind"] == "inbox" for item in inbox_data)
        assert any(item["project_id"] == other_ref for item in inbox_data)

        env = os.environ.copy()
        env["AI_KNOWLEDGE_REPOSITORY"] = str(repository)
        env["AI_KNOWLEDGE_REDACTION_KEY_FILE"] = str(key_file)
        from_env = run(
            str(SCRIPT), "partial", "state", "--json", cwd=current, env=env
        )
        assert any(item["project_id"] == other_ref for item in json.loads(from_env.stdout))

        # Central search requires the local HMAC key; local-only search remains usable.
        missing_key = run(
            str(SCRIPT),
            "atomic",
            "--repository",
            str(repository),
            "--redaction-key-file",
            str(root / "missing.key"),
            "--json",
            cwd=current,
            check=False,
        )
        assert missing_key.returncode != 0
        assert "redaction key not found" in missing_key.stderr

        local_only = run(
            str(SCRIPT),
            "atomic",
            "--repository",
            str(root / "no-central"),
            "--redaction-key-file",
            str(root / "missing.key"),
            "--json",
            cwd=current,
        )
        assert any(item["project_id"] == current_id for item in json.loads(local_only.stdout))

        # Legacy central indexes are deliberately refused rather than exposing raw identifiers.
        legacy = root / "legacy"
        legacy.mkdir()
        (legacy / "index.json").write_text(
            json.dumps(
                {
                    "schema_version": 1,
                    "projects": [
                        {"project_id": other_id, "path": "projects/other--123"}
                    ],
                }
            ),
            encoding="utf-8",
        )
        legacy_result = run(
            str(SCRIPT),
            "atomic",
            "--repository",
            str(legacy),
            "--redaction-key-file",
            str(key_file),
            "--json",
            cwd=current,
            check=False,
        )
        assert legacy_result.returncode != 0
        assert "legacy knowledge index schema 1" in legacy_result.stderr

    print("test_ai_knowledge_search: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
