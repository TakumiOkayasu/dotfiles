#!/usr/bin/env python3
"""Canonical typed definition for the qa-nightmare distribution manifest."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_ARTIFACT = (
    REPOSITORY_ROOT / "common" / "qa-nightmare" / "manifest.json"
)
REQUIRED_FIELDS = ("攻撃", "検証", "壊れ方", "嫌度")
UI_REQUIRED_FIELDS = ("攻撃", "検証", "壊れ方", "スクショ箇所", "嫌度")


@dataclass(frozen=True, slots=True)
class RuntimeSpec:
    name: str
    home_relative_root: str
    manifest_file: str
    checklist_directory: str


@dataclass(frozen=True, slots=True)
class ChecklistSpec:
    file: str
    ids: tuple[str, ...]
    required_fields: tuple[str, ...]
    size_bytes: int
    sha256: str


@dataclass(frozen=True, slots=True)
class ManifestSpec:
    schema_version: int
    digest_algorithm: str
    max_source_files: int
    max_source_bytes: int
    max_total_source_bytes: int
    max_total_checklist_bytes: int
    canonical_checklist_root: str
    runtimes: tuple[RuntimeSpec, ...]
    checklists: tuple[ChecklistSpec, ...]


RUNTIMES = (
    RuntimeSpec(
        "claude",
        ".claude/skills/qa-nightmare",
        "manifest.json",
        "checklists",
    ),
    RuntimeSpec(
        "codex",
        ".codex/agents/qa-nightmare",
        "manifest.json",
        "checklists",
    ),
)

CHECKLISTS = (
    ChecklistSpec(
        "auth-bypass.md",
        ("AB-01", "AB-02", "AB-03", "AB-04", "AB-05", "AB-06", "AB-07", "AB-08", "AB-09", "AB-10"),
        REQUIRED_FIELDS,
        2944,
        "e67f38e2b84907216d9b1071047e0918a7ae5cbe606709739cebc3c37a20828d",
    ),
    ChecklistSpec(
        "boundary-hell.md",
        ("BH-01", "BH-02", "BH-03", "BH-04", "BH-05", "BH-06", "BH-07", "BH-08", "BH-09", "BH-10", "BH-11"),
        REQUIRED_FIELDS,
        3514,
        "21af0a7b6b4bf4e2071425c1f836ff3f298130578b4ef1b48eaa7fde9cfdfee8",
    ),
    ChecklistSpec(
        "data-io.md",
        ("DI-01", "DI-02", "DI-03", "DI-04", "DI-05", "DI-06", "DI-07", "DI-08", "DI-09", "DI-10"),
        REQUIRED_FIELDS,
        3581,
        "e7ec3aafe173e4170b3e8d91477b94b9999444b207a64ef62c0f7d5af00a53c8",
    ),
    ChecklistSpec(
        "domain-specific.md",
        ("DS-01", "DS-02", "DS-03", "DS-04", "DS-05", "DS-06", "DS-07", "DS-08", "DS-09", "DS-10"),
        REQUIRED_FIELDS,
        4580,
        "08143c8b8f792de335e610d2f0df2dbe914bbe4f6c6baf35be53a69f63c4e1e7",
    ),
    ChecklistSpec(
        "error-recovery.md",
        ("ER-01", "ER-02", "ER-03", "ER-04", "ER-05", "ER-06", "ER-07", "ER-08", "ER-09", "ER-10"),
        REQUIRED_FIELDS,
        3879,
        "9c322cd244a1709c49a7f8a97b4bdab3ea0b2b03bdf8c96aad1e09db6bf3c9c5",
    ),
    ChecklistSpec(
        "silent-corruption.md",
        ("SC-01", "SC-02", "SC-03", "SC-04", "SC-05", "SC-06", "SC-07", "SC-08", "SC-09", "SC-10"),
        REQUIRED_FIELDS,
        3217,
        "0dc65f453d003681d845222b29e40a0178594b06f658b71dce27d7035c90e2ac",
    ),
    ChecklistSpec(
        "state-transition.md",
        ("ST-01", "ST-02", "ST-03", "ST-04", "ST-05", "ST-06", "ST-07", "ST-08"),
        REQUIRED_FIELDS,
        2635,
        "080edf7d37d7d92a32e304f4a2919439a579db563d956735f7a11cff75f6b939",
    ),
    ChecklistSpec(
        "timing-chaos.md",
        ("TC-01", "TC-02", "TC-03", "TC-04", "TC-05", "TC-06", "TC-07", "TC-08", "TC-09", "TC-10"),
        REQUIRED_FIELDS,
        2995,
        "e415753ad14066b380a5f798e606b128869d801239f701b8f6b99c2a66c53e92",
    ),
    ChecklistSpec(
        "ui-destruction.md",
        ("UD-01", "UD-02", "UD-03", "UD-04", "UD-05", "UD-06", "UD-07", "UD-08", "UD-09", "UD-10"),
        UI_REQUIRED_FIELDS,
        3942,
        "5035a82b2a51675dbe099ebfebef56bdad10162b6b3791686d6671c2b9e18f65",
    ),
    ChecklistSpec(
        "ui-operation.md",
        ("UO-01", "UO-02", "UO-03", "UO-04", "UO-05", "UO-06", "UO-07", "UO-08", "UO-09", "UO-10"),
        UI_REQUIRED_FIELDS,
        3955,
        "86d596dcd2835b87121945b873abdee4743d82e241d4e70395f0f680d48806cd",
    ),
    ChecklistSpec(
        "ui-state.md",
        ("US-01", "US-02", "US-03", "US-04", "US-05", "US-06", "US-07", "US-08", "US-09", "US-10"),
        UI_REQUIRED_FIELDS,
        3840,
        "f0713271eae4c7a95dc9e8db2e422d399be2bb7a7fe181bc8ae9aedfd988dd6b",
    ),
)

MANIFEST_SPEC = ManifestSpec(
    schema_version=1,
    digest_algorithm="sha256",
    max_source_files=64,
    max_source_bytes=1024 * 1024,
    max_total_source_bytes=8 * 1024 * 1024,
    max_total_checklist_bytes=64 * 1024,
    canonical_checklist_root="common/qa-nightmare/checklists",
    runtimes=RUNTIMES,
    checklists=CHECKLISTS,
)


def manifest_document(spec: ManifestSpec = MANIFEST_SPEC) -> dict[str, object]:
    runtimes = {
        runtime.name: {
            "home_relative_root": runtime.home_relative_root,
            "manifest_file": runtime.manifest_file,
            "checklist_directory": runtime.checklist_directory,
        }
        for runtime in spec.runtimes
    }
    checklists = [
        {
            "file": checklist.file,
            "ids": list(checklist.ids),
            "required_fields": list(checklist.required_fields),
            "size_bytes": checklist.size_bytes,
            "sha256": checklist.sha256,
        }
        for checklist in spec.checklists
    ]
    return {
        "schema_version": spec.schema_version,
        "digest_algorithm": spec.digest_algorithm,
        "max_source_files": spec.max_source_files,
        "max_source_bytes": spec.max_source_bytes,
        "max_total_source_bytes": spec.max_total_source_bytes,
        "max_total_checklist_bytes": spec.max_total_checklist_bytes,
        "canonical_checklist_root": spec.canonical_checklist_root,
        "runtimes": runtimes,
        "checklists": checklists,
    }


def serialized_manifest(spec: ManifestSpec = MANIFEST_SPEC) -> bytes:
    text = json.dumps(
        manifest_document(spec),
        ensure_ascii=False,
        indent=2,
    )
    return f"{text}\n".encode("utf-8")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--check", action="store_true", dest="is_check")
    action.add_argument("--write", action="store_true", dest="is_write")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    expected = serialized_manifest()
    if arguments.is_write:
        MANIFEST_ARTIFACT.write_bytes(expected)
        return 0
    if MANIFEST_ARTIFACT.read_bytes() == expected:
        return 0
    sys.stderr.write("qa-nightmare manifest artifact is stale\n")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
