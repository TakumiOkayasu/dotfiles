from __future__ import annotations

import hashlib
import json
import os
import re
import runpy
import subprocess
import sys
from dataclasses import replace
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from qa_nightmare_manifest import (
    MANIFEST_SPEC,
    ChecklistSpec,
    manifest_document,
    serialized_manifest,
)


MANIFEST = REPO_ROOT / "common" / "qa-nightmare" / "manifest.json"
CHECKLIST_ROOT = REPO_ROOT / "common" / "qa-nightmare" / "checklists"
PREFLIGHT = REPO_ROOT / "bin" / "qa-nightmare-preflight"
CASE_HEADING = re.compile(r"^### (?P<case_id>[A-Z]+-[0-9]+):", re.MULTILINE)
FIELD = re.compile(r"^- (?P<field>[^:\n]+):", re.MULTILINE)


def _create_target_repo(tmp_path: Path) -> Path:
    repo = tmp_path / "target-repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    (repo / "README.md").write_text("verified feature facts\n", encoding="utf-8")
    return repo


def _install_runtime(home: Path, runtime: str) -> Path:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    runtime_root = home / manifest["runtimes"][runtime]["home_relative_root"]
    checklist_root = runtime_root / "checklists"
    checklist_root.mkdir(parents=True)
    (runtime_root / "manifest.json").symlink_to(MANIFEST)
    for entry in manifest["checklists"]:
        (checklist_root / entry["file"]).symlink_to(
            CHECKLIST_ROOT / entry["file"]
        )
    return runtime_root


def _run_preflight(
    home: Path,
    runtime: str,
    repo: Path,
    *sources: str,
    is_source_only: bool = False,
) -> subprocess.CompletedProcess[str]:
    command = [
        str(PREFLIGHT),
        "--runtime",
        runtime,
        "--repo",
        str(repo),
    ]
    if is_source_only:
        command.append("--source-only")
    for source in sources:
        command.extend(("--source", source))
    return subprocess.run(
        command,
        env={**os.environ, "HOME": str(home)},
        text=True,
        capture_output=True,
        check=False,
    )


def test_should_match_typed_source_when_manifest_artifact_is_loaded() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert MANIFEST.read_bytes() == serialized_manifest()
    assert manifest == manifest_document()
    assert MANIFEST_SPEC.schema_version == 1
    assert MANIFEST_SPEC.digest_algorithm == "sha256"
    assert 0 < MANIFEST_SPEC.max_source_files
    assert (
        0
        < MANIFEST_SPEC.max_source_bytes
        <= MANIFEST_SPEC.max_total_source_bytes
    )
    assert manifest["runtimes"] == {
        "claude": {
            "home_relative_root": ".claude/skills/qa-nightmare",
            "manifest_file": "manifest.json",
            "checklist_directory": "checklists",
        },
        "codex": {
            "home_relative_root": ".codex/agents/qa-nightmare",
            "manifest_file": "manifest.json",
            "checklist_directory": "checklists",
        },
    }


def _assert_checklist_spec_matches_source(entry: ChecklistSpec) -> None:
    content = (CHECKLIST_ROOT / entry.file).read_bytes()
    text = content.decode("utf-8")
    headings = list(CASE_HEADING.finditer(text))

    assert entry.file == Path(entry.file).name
    assert entry.size_bytes == len(content)
    assert entry.sha256 == hashlib.sha256(content).hexdigest()
    assert entry.ids == tuple(
        heading.group("case_id") for heading in headings
    )
    assert len(entry.ids) == len(set(entry.ids))
    for index, heading in enumerate(headings):
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        fields = FIELD.findall(text[heading.end() : end])
        assert set(entry.required_fields).issubset(fields)
        assert len(fields) == len(set(fields))


def test_should_match_canonical_files_when_typed_manifest_is_verified() -> None:
    manifest_names = [entry.file for entry in MANIFEST_SPEC.checklists]
    source_names = sorted(path.name for path in CHECKLIST_ROOT.glob("*.md"))
    assert manifest_names == source_names

    for entry in MANIFEST_SPEC.checklists:
        _assert_checklist_spec_matches_source(entry)
    all_ids = [case_id for entry in MANIFEST_SPEC.checklists for case_id in entry.ids]
    total_checklist_bytes = sum(
        entry.size_bytes for entry in MANIFEST_SPEC.checklists
    )
    assert len(all_ids) == len(set(all_ids))
    assert total_checklist_bytes <= MANIFEST_SPEC.max_total_checklist_bytes


def test_should_reject_manifest_when_code_limit_is_exceeded(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    oversized_manifest = tmp_path / "manifest.json"
    namespace = runpy.run_path(str(PREFLIGHT))
    with oversized_manifest.open("wb") as manifest_file:
        manifest_file.truncate(namespace["MAX_TRUSTED_MANIFEST_BYTES"] + 1)
    monkeypatch.setitem(namespace, "TRUSTED_MANIFEST", oversized_manifest)
    namespace["load_trusted_manifest"].__globals__["TRUSTED_MANIFEST"] = (
        oversized_manifest
    )
    error_type = namespace["PreflightError"]

    with pytest.raises(error_type) as captured:
        namespace["load_trusted_manifest"]()

    assert captured.value.code == "trusted_manifest_too_large"


def test_should_reject_manifest_when_artifact_differs_from_typed_source(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    tampered_manifest = tmp_path / "manifest.json"
    content = serialized_manifest().replace(b'"sha256"', b'"sha25x"', 1)
    assert len(content) == len(serialized_manifest())
    tampered_manifest.write_bytes(content)
    namespace = runpy.run_path(str(PREFLIGHT))
    monkeypatch.setitem(namespace, "TRUSTED_MANIFEST", tampered_manifest)
    namespace["load_trusted_manifest"].__globals__["TRUSTED_MANIFEST"] = (
        tampered_manifest
    )
    error_type = namespace["PreflightError"]

    with pytest.raises(error_type) as captured:
        namespace["load_trusted_manifest"]()

    assert captured.value.code == "trusted_manifest_mismatch"


def test_should_emit_verified_snapshot_when_full_preflight_succeeds(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    runtime_root = _install_runtime(home, "claude")

    result = _run_preflight(home, "claude", repo, "README.md")

    assert result.returncode == 0, result.stderr
    output = json.loads(result.stdout)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    expected_names = [entry["file"] for entry in manifest["checklists"]]
    repository_identity = hashlib.sha256(
        os.fsencode(str(repo.resolve()))
    ).hexdigest()
    assert output["repo_provenance"] == {
        "repository_identity_sha256": repository_identity,
        "is_canonical_git_root": True,
        "accepted_sources": [
            {
                "path": "README.md",
                "sha256": hashlib.sha256(
                    (repo / "README.md").read_bytes()
                ).hexdigest(),
                "size_bytes": (repo / "README.md").stat().st_size,
            }
        ],
    }
    assert output["checklist_provenance"]["runtime"] == "claude"
    checklist_entries = output["checklist_provenance"]["checklists"]
    assert [entry["file"] for entry in checklist_entries] == expected_names
    assert all(
        set(entry) == {"file", "sha256", "is_structure_valid"}
        for entry in checklist_entries
    )
    assert all(
        entry["is_structure_valid"] is True
        for entry in output["checklist_provenance"]["checklists"]
    )
    assert output["checklist_snapshot"].startswith(
        '<<<CHECKLIST file="auth-bypass.md">>>\n'
    )
    assert output["checklist_snapshot"].endswith("<<<END CHECKLIST>>>\n")
    assert str(repo.resolve()) not in result.stdout
    assert str(runtime_root) not in result.stdout
    assert str(MANIFEST) not in result.stdout


def test_should_match_full_provenance_when_source_only_has_no_runtime(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    source_digest = hashlib.sha256(
        (repo / "README.md").read_bytes()
    ).hexdigest()

    source_only_result = _run_preflight(
        home, "claude", repo, "README.md", is_source_only=True
    )

    assert source_only_result.returncode == 0, source_only_result.stderr
    source_only_output = json.loads(source_only_result.stdout)
    expected_sources = [
        {
            "path": "README.md",
            "sha256": source_digest,
            "size_bytes": (repo / "README.md").stat().st_size,
        }
    ]
    assert source_only_output == {
        "schema_version": MANIFEST_SPEC.schema_version,
        "mode": "source-only",
        "repo_provenance": {
            "repository_identity_sha256": hashlib.sha256(
                os.fsencode(str(repo.resolve()))
            ).hexdigest(),
            "is_canonical_git_root": True,
            "accepted_sources": expected_sources,
        },
    }
    assert str(repo.resolve()) not in source_only_result.stdout
    assert "checklist_snapshot" not in source_only_output
    assert "checklist_provenance" not in source_only_output

    _install_runtime(home, "claude")
    full = _run_preflight(home, "claude", repo, "README.md")
    assert full.returncode == 0, full.stderr
    assert json.loads(full.stdout)["repo_provenance"] == (
        source_only_output["repo_provenance"]
    )


def test_should_reject_source_when_file_exceeds_manifest_limit(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    with (repo / "README.md").open("wb") as oversized:
        oversized.truncate(manifest["max_source_bytes"] + 1)

    result = _run_preflight(
        home, "claude", repo, "README.md", is_source_only=True
    )

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"] == {
        "code": "source_too_large",
        "message": "source exceeds manifest size limit: README.md",
    }
    assert result.stdout == ""


def test_should_hide_runtime_root_when_codex_runtime_is_selected(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    runtime_root = _install_runtime(home, "codex")

    result = _run_preflight(home, "codex", repo, "README.md")

    assert result.returncode == 0, result.stderr
    output = json.loads(result.stdout)
    assert output["checklist_provenance"]["runtime"] == "codex"
    assert str(runtime_root) not in result.stdout


def test_should_require_runtime_manifest_when_full_preflight_runs(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)

    result = _run_preflight(home, "claude", repo, "README.md")

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"] == {
        "code": "runtime_manifest_missing",
        "message": "runtime manifest missing: manifest.json",
    }


def test_should_reject_runtime_when_checklist_is_missing(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    runtime_root = _install_runtime(home, "claude")
    (runtime_root / "checklists" / "auth-bypass.md").unlink()

    result = _run_preflight(home, "claude", repo, "README.md")

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"] == {
        "code": "runtime_checklist_missing",
        "message": "runtime checklist missing: auth-bypass.md",
    }


def test_should_reject_runtime_when_checklist_target_is_stale(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    runtime_root = _install_runtime(home, "claude")
    stale = runtime_root / "checklists" / "auth-bypass.md"
    stale.unlink()
    stale.write_text("stale checklist must not be read\n", encoding="utf-8")

    result = _run_preflight(home, "claude", repo, "README.md")

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"] == {
        "code": "runtime_checklist_target",
        "message": "runtime checklist canonical target mismatch: auth-bypass.md",
    }
    assert "stale checklist must not be read" not in result.stderr


@pytest.mark.parametrize(
    ("requested", "expected_code"),
    (
        ("./README.md", "source_component"),
        ("docs/../README.md", "source_component"),
        ("docs", "source_not_regular"),
        ("ignored.txt", "source_gitignored"),
        ("credentials.json", "source_secret_bearing"),
        ("api-token.txt", "source_secret_bearing"),
        (".netrc", "source_secret_bearing"),
        (".npmrc", "source_secret_bearing"),
        (".pypirc", "source_secret_bearing"),
        ("api_key.txt", "source_secret_bearing"),
        ("credentials.yaml", "source_secret_bearing"),
        ("secrets.json", "source_secret_bearing"),
        ("server.pem", "source_secret_bearing"),
        (".git/config", "source_secret_bearing"),
    ),
)
def test_should_reject_source_when_relative_path_is_unsafe(
    tmp_path: Path, requested: str, expected_code: str
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    _install_runtime(home, "claude")
    (repo / "docs").mkdir()
    (repo / "ignored.txt").write_text("ignored\n", encoding="utf-8")
    (repo / "credentials.json").write_text("do not read\n", encoding="utf-8")
    (repo / "api-token.txt").write_text("do not read\n", encoding="utf-8")
    (repo / ".netrc").write_text("do not read\n", encoding="utf-8")
    (repo / ".npmrc").write_text("do not read\n", encoding="utf-8")
    (repo / ".pypirc").write_text("do not read\n", encoding="utf-8")
    (repo / "api_key.txt").write_text("do not read\n", encoding="utf-8")
    (repo / "credentials.yaml").write_text("do not read\n", encoding="utf-8")
    (repo / "secrets.json").write_text("do not read\n", encoding="utf-8")
    (repo / "server.pem").write_text("do not read\n", encoding="utf-8")
    (repo / ".gitignore").write_text("ignored.txt\n", encoding="utf-8")

    result = _run_preflight(home, "claude", repo, requested)

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"]["code"] == expected_code
    assert "do not read" not in result.stderr


def test_should_reject_source_when_absolute_sibling_is_requested(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    _install_runtime(home, "claude")
    sibling = tmp_path / "target-repo-evil" / "README.md"
    sibling.parent.mkdir()
    sibling.write_text("sibling sentinel must not be read\n", encoding="utf-8")

    result = _run_preflight(home, "claude", repo, str(sibling))

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"]["code"] == "source_absolute"
    assert "sibling sentinel must not be read" not in result.stderr


def test_should_reject_source_without_reading_when_symlink_is_external(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    _install_runtime(home, "claude")
    sentinel = tmp_path / "outside-sentinel.txt"
    sentinel.write_text("QA_NIGHTMARE_SECRET_SENTINEL\n", encoding="utf-8")
    (repo / "outside.md").symlink_to(sentinel)

    result = _run_preflight(home, "claude", repo, "outside.md")

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"]["code"] == "source_external_symlink"
    assert "QA_NIGHTMARE_SECRET_SENTINEL" not in result.stderr


def test_should_reject_source_when_canonical_alias_is_gitignored(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    ignored = repo / "ignored-dir"
    ignored.mkdir()
    (ignored / "facts.md").write_text(
        "QA_NIGHTMARE_IGNORED_SENTINEL\n", encoding="utf-8"
    )
    (repo / "alias").symlink_to(ignored, target_is_directory=True)
    (repo / ".gitignore").write_text("ignored-dir/\n", encoding="utf-8")

    result = _run_preflight(
        home, "claude", repo, "alias/facts.md", is_source_only=True
    )

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"]["code"] == "source_gitignored"
    assert "QA_NIGHTMARE_IGNORED_SENTINEL" not in result.stderr


def test_should_batch_gitignore_candidates_when_sources_are_validated(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo = _create_target_repo(tmp_path)
    (repo / "facts.md").write_text("verified facts\n", encoding="utf-8")
    namespace = runpy.run_path(str(PREFLIGHT))
    gitignore_calls: list[tuple[list[str], bytes]] = []

    def no_ignored_candidates(
        command: list[str], **kwargs: object
    ) -> subprocess.CompletedProcess[bytes]:
        gitignore_calls.append((command, kwargs["input"]))
        return subprocess.CompletedProcess(command, 1, stdout=b"", stderr=b"")

    monkeypatch.setattr(namespace["subprocess"], "run", no_ignored_candidates)

    result = namespace["validate_sources"](
        MANIFEST_SPEC,
        repo,
        ["README.md", "facts.md"],
    )

    assert [entry["path"] for entry in result] == ["README.md", "facts.md"]
    assert len(gitignore_calls) == 1
    command, candidates = gitignore_calls[0]
    assert command[-3:] == ["check-ignore", "--stdin", "-z"]
    assert candidates.split(b"\0") == [b"README.md", b"facts.md", b""]


def test_should_map_requested_source_when_canonical_alias_is_gitignored(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo = _create_target_repo(tmp_path)
    canonical_parent = repo / "canonical"
    canonical_parent.mkdir()
    (canonical_parent / "facts.md").write_text("ignored facts\n", encoding="utf-8")
    (repo / "alias").symlink_to(canonical_parent, target_is_directory=True)
    namespace = runpy.run_path(str(PREFLIGHT))
    calls = 0

    def canonical_is_ignored(
        command: list[str], **kwargs: object
    ) -> subprocess.CompletedProcess[bytes]:
        nonlocal calls
        calls += 1
        assert kwargs["input"] == b"canonical/facts.md\0"
        return subprocess.CompletedProcess(
            command,
            0,
            stdout=b"canonical/facts.md\0",
            stderr=b"",
        )

    monkeypatch.setattr(namespace["subprocess"], "run", canonical_is_ignored)
    error_type = namespace["PreflightError"]

    with pytest.raises(error_type) as captured:
        namespace["validate_sources"](
            MANIFEST_SPEC,
            repo,
            ["alias/facts.md"],
        )

    assert captured.value.code == "source_gitignored"
    assert str(captured.value) == "gitignored source rejected: alias/facts.md"
    assert calls == 1


def test_should_fail_closed_when_batched_gitignore_errors(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo = _create_target_repo(tmp_path)
    namespace = runpy.run_path(str(PREFLIGHT))

    def failed_check(
        command: list[str], **_kwargs: object
    ) -> subprocess.CompletedProcess[bytes]:
        return subprocess.CompletedProcess(command, 128, stdout=b"", stderr=b"fatal")

    monkeypatch.setattr(namespace["subprocess"], "run", failed_check)
    error_type = namespace["PreflightError"]

    with pytest.raises(error_type) as captured:
        namespace["validate_sources"](
            MANIFEST_SPEC,
            repo,
            ["README.md"],
        )

    assert captured.value.code == "source_git_check_failed"
    assert "fatal" not in str(captured.value)


def test_should_reject_without_exposure_when_source_contains_secret(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    _install_runtime(home, "claude")
    (repo / "README.md").write_text(
        "Authorization: Bearer QA_NIGHTMARE_SECRET_SENTINEL\n",
        encoding="utf-8",
    )

    result = _run_preflight(home, "claude", repo, "README.md")

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"] == {
        "code": "source_secret_content",
        "message": "secret-bearing source content rejected: README.md",
    }
    assert "QA_NIGHTMARE_SECRET_SENTINEL" not in result.stdout
    assert "QA_NIGHTMARE_SECRET_SENTINEL" not in result.stderr


@pytest.mark.parametrize(
    "source_name",
    ("TokenController.php", "token-service.md", "password-reset.md"),
)
def test_should_allow_source_when_auth_implementation_name_is_used(
    tmp_path: Path, source_name: str
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    (repo / source_name).write_text("auth implementation facts\n", encoding="utf-8")

    result = _run_preflight(
        home, "claude", repo, source_name, is_source_only=True
    )

    assert result.returncode == 0, result.stderr


def test_should_allow_source_when_auth_schema_uses_placeholders(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    (repo / "README.md").write_text(
        "Authorization: Bearer <token>\n"
        "Authorization: Basic [REDACTED]\n"
        "token: JWT\n"
        "password: string\n"
        "api_key: required\n"
        "secret: <placeholder>\n",
        encoding="utf-8",
    )

    result = _run_preflight(
        home, "claude", repo, "README.md", is_source_only=True
    )

    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize(
    "auth_fixture",
    (
        'password = "invalid"\n',
        'password = "test-password"\n',
        'token = "fixture-token"\n',
        "token = generated_token\n",
        "token = settings.auth_token\n",
        "token = generate_token()\n",
    ),
)
def test_should_allow_source_when_auth_fixture_is_explicitly_non_secret(
    tmp_path: Path, auth_fixture: str
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    (repo / "README.md").write_text(auth_fixture, encoding="utf-8")

    result = _run_preflight(
        home, "claude", repo, "README.md", is_source_only=True
    )

    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize(
    "secret_line",
    (
        'token = "QA_NIGHTMARE_SECRET_SENTINEL"\n',
        "api_key: ghp_1234567890abcdefghijklmn\n",
        'password = "P@ssw0rd!"\n',
        "token = SuperSecretPassword123\n",
        "token = superSecretPassword123\n",
        'password = "vR8!yN2@qL5#sD9$kP4%"\n',
    ),
)
def test_should_reject_without_exposure_when_secret_is_assigned(
    tmp_path: Path, secret_line: str
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    (repo / "README.md").write_text(secret_line, encoding="utf-8")

    result = _run_preflight(
        home, "claude", repo, "README.md", is_source_only=True
    )

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"]["code"] == "source_secret_content"
    assert "QA_NIGHTMARE_SECRET_SENTINEL" not in result.stdout
    assert "QA_NIGHTMARE_SECRET_SENTINEL" not in result.stderr


def test_should_reject_before_reading_when_sources_are_duplicated(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    (repo / "README.md").write_text(
        "Authorization: Bearer QA_NIGHTMARE_SECRET_SENTINEL\n",
        encoding="utf-8",
    )

    result = _run_preflight(
        home,
        "claude",
        repo,
        "README.md",
        "README.md",
        is_source_only=True,
    )

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"]["code"] == "source_duplicate"
    assert "QA_NIGHTMARE_SECRET_SENTINEL" not in result.stderr


def test_should_reject_before_lookup_when_source_count_exceeds_limit(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    sources = tuple(
        f"missing-{index}.md" for index in range(manifest["max_source_files"] + 1)
    )

    result = _run_preflight(
        home, "claude", repo, *sources, is_source_only=True
    )

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"]["code"] == "source_too_many"


def test_should_reject_before_scan_when_aggregate_source_size_exceeds_limit(
    tmp_path: Path,
) -> None:
    home = tmp_path / "home"
    repo = _create_target_repo(tmp_path)
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    file_count = manifest["max_total_source_bytes"] // manifest["max_source_bytes"] + 1
    file_size = manifest["max_total_source_bytes"] // file_count + 1
    assert file_count <= manifest["max_source_files"]
    assert file_size <= manifest["max_source_bytes"]
    sources = tuple(f"source-{index}.md" for index in range(file_count))
    for source in sources:
        with (repo / source).open("wb") as source_file:
            source_file.truncate(file_size)

    result = _run_preflight(
        home, "claude", repo, *sources, is_source_only=True
    )

    assert result.returncode == 2
    assert json.loads(result.stderr)["error"]["code"] == "source_total_too_large"


def test_should_reject_source_when_inode_changes_after_metadata_check(
    tmp_path: Path,
) -> None:
    source = tmp_path / "README.md"
    source.write_text("verified facts\n", encoding="utf-8")
    metadata = source.lstat()
    with source.open("a", encoding="utf-8") as changed:
        changed.write("QA_NIGHTMARE_SECRET_SENTINEL\n")
    namespace = runpy.run_path(str(PREFLIGHT))
    error_type = namespace["PreflightError"]

    with pytest.raises(error_type) as captured:
        namespace["reject_secret_content"](
            source,
            "README.md",
            metadata,
            json.loads(MANIFEST.read_text(encoding="utf-8"))["max_source_bytes"],
        )

    assert captured.value.code == "source_changed"
    assert "QA_NIGHTMARE_SECRET_SENTINEL" not in str(captured.value)


# Existing runtime revalidation already covers this race; keep it as a regression guard.
def test_should_reject_checklist_when_runtime_target_changes_after_read(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    canonical_source = tmp_path / "canonical.md"
    canonical_source.write_text("verified checklist\n", encoding="utf-8")
    changed_target = tmp_path / "changed.md"
    changed_target.write_text("untrusted checklist\n", encoding="utf-8")
    runtime_path = tmp_path / "runtime.md"
    namespace = runpy.run_path(str(PREFLIGHT))
    error_type = namespace["PreflightError"]
    original_resolve = Path.resolve
    runtime_resolve_calls = 0

    def resolve_with_runtime_change(
        path: Path, strict: bool = False
    ) -> Path:
        nonlocal runtime_resolve_calls
        if path == runtime_path:
            runtime_resolve_calls += 1
            if runtime_resolve_calls == 1:
                return canonical_source
            return changed_target
        return original_resolve(path, strict=strict)

    monkeypatch.setattr(Path, "resolve", resolve_with_runtime_change)

    with pytest.raises(error_type) as captured:
        namespace["read_trusted_checklist"](
            runtime_path,
            canonical_source,
            "auth-bypass.md",
            len(canonical_source.read_bytes()),
        )

    assert captured.value.code == "runtime_checklist_target"
    assert runtime_resolve_calls == 2


def test_should_reject_checklist_before_decode_when_size_exceeds_expected(
    tmp_path: Path,
) -> None:
    canonical_source = tmp_path / "canonical.md"
    with canonical_source.open("wb") as checklist_file:
        checklist_file.truncate(17)
    runtime_path = tmp_path / "runtime.md"
    runtime_path.symlink_to(canonical_source)
    namespace = runpy.run_path(str(PREFLIGHT))
    error_type = namespace["PreflightError"]

    with pytest.raises(error_type) as captured:
        namespace["read_trusted_checklist"](
            runtime_path,
            canonical_source,
            "auth-bypass.md",
            16,
        )

    assert captured.value.code == "canonical_checklist_size"


def test_should_reject_snapshot_before_read_when_checklist_total_exceeds_limit(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = tmp_path / "home"
    runtime_root = _install_runtime(home, "claude")
    manifest = replace(MANIFEST_SPEC, max_total_checklist_bytes=1)
    namespace = runpy.run_path(str(PREFLIGHT))
    error_type = namespace["PreflightError"]

    def unexpected_read(*_args: object) -> None:
        raise AssertionError("checklist body must not be read")

    monkeypatch.setitem(
        namespace["build_checklist_snapshot"].__globals__,
        "read_trusted_checklist",
        unexpected_read,
    )

    with pytest.raises(error_type) as captured:
        namespace["build_checklist_snapshot"](
            manifest,
            runtime_root / "checklists",
        )

    assert captured.value.code == "checklist_total_too_large"


def test_should_stop_enumeration_when_runtime_has_first_extra_entry(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    namespace = runpy.run_path(str(PREFLIGHT))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    expected_names = [entry["file"] for entry in manifest["checklists"]]
    yielded_names: list[str] = []

    class DirectoryEntry:
        def __init__(self, name: str) -> None:
            self.name = name

    class RuntimeEntries:
        def __enter__(self) -> "RuntimeEntries":
            return self

        def __exit__(self, *_args: object) -> None:
            return None

        def __iter__(self) -> "RuntimeEntries":
            return self

        def __next__(self) -> DirectoryEntry:
            index = len(yielded_names)
            if index < len(expected_names):
                name = expected_names[index]
            elif index == len(expected_names):
                name = "unexpected.md"
            else:
                raise AssertionError("runtime directory enumeration did not stop")
            yielded_names.append(name)
            return DirectoryEntry(name)

    monkeypatch.setattr(namespace["os"], "scandir", lambda _path: RuntimeEntries())
    error_type = namespace["PreflightError"]

    with pytest.raises(error_type) as captured:
        namespace["runtime_checklist_names"](
            tmp_path,
            expected_names,
        )

    assert captured.value.code == "runtime_checklist_extra"
    assert len(yielded_names) == len(expected_names) + 1


def test_should_assign_source_evidence_to_parent_when_help_is_requested() -> None:
    result = subprocess.run(
        [str(PREFLIGHT), "--help"], text=True, capture_output=True, check=False
    )

    assert result.returncode == 0
    assert "Runtime roots are derived only from HOME" in result.stdout
    assert "does not extract source_evidence or redact secret values" in result.stdout
    assert "parent workflow's responsibility" in result.stdout


def test_should_reject_runtime_root_when_user_supplies_it(tmp_path: Path) -> None:
    result = subprocess.run(
        [
            str(PREFLIGHT),
            "--runtime",
            "claude",
            "--repo",
            str(tmp_path),
            "--source",
            "README.md",
            "--runtime-root",
            str(tmp_path),
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 2
    assert "unrecognized arguments: --runtime-root" in result.stderr
