from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

SKILL_NAME_PATTERN = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")


@dataclass(frozen=True)
class CommandMapping:
    source: Path
    skill: str
    reference: Path


@dataclass(frozen=True)
class AssetManifest:
    commands: tuple[CommandMapping, ...]
    allowed_skill_files: frozenset[str]
    codex_native_skills: frozenset[str]
    core_skills: frozenset[str]


def _skill_names(data: object, key: str, manifest_path: Path) -> frozenset[str]:
    if not isinstance(data, list) or any(
        not isinstance(name, str) or SKILL_NAME_PATTERN.fullmatch(name) is None
        for name in data
    ):
        raise ValueError(f"invalid {key}: {manifest_path}")
    if len(data) != len(set(data)):
        raise ValueError(f"duplicate {key}: {manifest_path}")
    return frozenset(data)


def _command_fields(entry: object) -> tuple[Path, str, Path]:
    if not isinstance(entry, dict):
        raise ValueError(f"invalid command entry: {entry!r}")
    source_value = entry.get("source")
    skill = entry.get("skill")
    reference_value = entry.get("reference")
    if (
        not isinstance(source_value, str)
        or not isinstance(skill, str)
        or not isinstance(reference_value, str)
    ):
        raise ValueError(f"invalid command entry: {entry!r}")
    return Path(source_value), skill, Path(reference_value)


def _command_mappings(data: object, manifest_path: Path) -> tuple[CommandMapping, ...]:
    if not isinstance(data, list):
        raise ValueError(f"invalid commands: {manifest_path}")

    mappings: list[CommandMapping] = []
    source_names: set[str] = set()
    skill_names: set[str] = set()
    for entry in data:
        source, skill, reference = _command_fields(entry)
        if (
            source.parent != Path("common/commands")
            or source.suffix != ".md"
            or SKILL_NAME_PATTERN.fullmatch(skill) is None
            or reference.is_absolute()
            or not reference.parts
            or ".." in reference.parts
            or reference.name != "claude-command.md"
        ):
            raise ValueError(f"invalid command entry: {entry!r}")
        if source.stem in source_names or skill in skill_names:
            raise ValueError(f"duplicate command entry: {entry!r}")
        mappings.append(CommandMapping(source, skill, reference))
        source_names.add(source.stem)
        skill_names.add(skill)
    return tuple(mappings)


def _allowed_skill_files(data: object, manifest_path: Path) -> frozenset[str]:
    if not isinstance(data, list) or any(not isinstance(path, str) for path in data):
        raise ValueError(f"invalid allowed_skill_files: {manifest_path}")
    allowed = frozenset(data)
    if not allowed or any(
        not path or Path(path).is_absolute() or ".." in Path(path).parts
        for path in allowed
    ):
        raise ValueError(f"invalid allowed_skill_files: {manifest_path}")
    return allowed


def load_asset_manifest(manifest_path: Path) -> AssetManifest:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"invalid asset manifest: {manifest_path}")
    return AssetManifest(
        commands=_command_mappings(data.get("commands"), manifest_path),
        allowed_skill_files=_allowed_skill_files(
            data.get("allowed_skill_files"), manifest_path
        ),
        codex_native_skills=_skill_names(
            data.get("codex_native_skills"), "codex_native_skills", manifest_path
        ),
        core_skills=_skill_names(data.get("core_skills"), "core_skills", manifest_path),
    )
