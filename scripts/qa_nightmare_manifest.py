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
        2934,
        "7870da1aa48be123e5d13719d1f75875e7576f9a8874f8a53bf55e9524169d06",
    ),
    ChecklistSpec(
        "boundary-hell.md",
        ("BH-01", "BH-02", "BH-03", "BH-04", "BH-05", "BH-06", "BH-07", "BH-08", "BH-09", "BH-10", "BH-11"),
        REQUIRED_FIELDS,
        3503,
        "c6e4b45f55c234f3dc863b62a11cddf62f97f32ae3c2f98e398585870c463d18",
    ),
    ChecklistSpec(
        "data-io.md",
        ("DI-01", "DI-02", "DI-03", "DI-04", "DI-05", "DI-06", "DI-07", "DI-08", "DI-09", "DI-10"),
        REQUIRED_FIELDS,
        3571,
        "87a1a25a8678ca132c25ab747c1f086fbfbef07a13ff3e2a8d6752b4677ed8ac",
    ),
    ChecklistSpec(
        "domain-specific.md",
        ("DS-01", "DS-02", "DS-03", "DS-04", "DS-05", "DS-06", "DS-07", "DS-08", "DS-09", "DS-10"),
        REQUIRED_FIELDS,
        4570,
        "50544ed310f096248be31cdd24717a68b845bdaa1a01f586d4815b259c85eebd",
    ),
    ChecklistSpec(
        "error-recovery.md",
        ("ER-01", "ER-02", "ER-03", "ER-04", "ER-05", "ER-06", "ER-07", "ER-08", "ER-09", "ER-10"),
        REQUIRED_FIELDS,
        3869,
        "406faf2fa6098e43e64d5910f3794322b585bdd8d6f9d03b75ad0e7794c7200a",
    ),
    ChecklistSpec(
        "silent-corruption.md",
        ("SC-01", "SC-02", "SC-03", "SC-04", "SC-05", "SC-06", "SC-07", "SC-08", "SC-09", "SC-10"),
        REQUIRED_FIELDS,
        3207,
        "b5ea253b798906a72db3d374b4244a64399f61e24a85082773a9a427c1fdbefa",
    ),
    ChecklistSpec(
        "state-transition.md",
        ("ST-01", "ST-02", "ST-03", "ST-04", "ST-05", "ST-06", "ST-07", "ST-08"),
        REQUIRED_FIELDS,
        2627,
        "7f32bb5f7d0c0f6379ac12621c91485d04092cf3eb6dcbffd54d53a9ba4e6cbe",
    ),
    ChecklistSpec(
        "timing-chaos.md",
        ("TC-01", "TC-02", "TC-03", "TC-04", "TC-05", "TC-06", "TC-07", "TC-08", "TC-09", "TC-10"),
        REQUIRED_FIELDS,
        2985,
        "cd315d28846854a1bb5bd852c292be47a4249193d224e507a8e1811d1a7ac810",
    ),
    ChecklistSpec(
        "ui-destruction.md",
        ("UD-01", "UD-02", "UD-03", "UD-04", "UD-05", "UD-06", "UD-07", "UD-08", "UD-09", "UD-10"),
        UI_REQUIRED_FIELDS,
        3932,
        "c6d722ebdbe65c7a5b6cb1de219c68f0193976ec702efb48561f13fcc219b753",
    ),
    ChecklistSpec(
        "ui-operation.md",
        ("UO-01", "UO-02", "UO-03", "UO-04", "UO-05", "UO-06", "UO-07", "UO-08", "UO-09", "UO-10"),
        UI_REQUIRED_FIELDS,
        3945,
        "9341b9399edd8302b5f81dca8a38c960d4a2a659d3a0cc604dbae34df86627fb",
    ),
    ChecklistSpec(
        "ui-state.md",
        ("US-01", "US-02", "US-03", "US-04", "US-05", "US-06", "US-07", "US-08", "US-09", "US-10"),
        UI_REQUIRED_FIELDS,
        3830,
        "783d29f9875988243d8a1d9552415fed9c9440ef151feaf457d0af2d5ddad9e5",
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
