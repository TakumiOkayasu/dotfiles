#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from types import ModuleType

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from codex_asset_manifest import load_asset_manifest
from codex_rule_renderer import (
    RULE_BUNDLE_NAME,
    RULE_INDEX_NAME,
    load_rule_documents,
    render_rule_bundle,
    render_rule_index,
)

REQUIRED = [
    "plugins/dotfile-work-codex/.codex-plugin/plugin.json",
    "plugins/dotfile-work-codex/hooks/hooks.json",
    "plugins/dotfile-work-codex/hooks/rules-lib.sh",
    "plugins/dotfile-work-codex/hooks/rules-inject.sh",
    "plugins/dotfile-work-codex/hooks/rules-guard.sh",
    "plugins/dotfile-work-codex/skills/rules-required/SKILL.md",
    "plugins/dotfile-work-codex/skills/feat/SKILL.md",
    "plugins/dotfile-work-codex/skills/fix/SKILL.md",
    "plugins/dotfile-work-codex/rules/RULES_CORE.md",
    "plugins/dotfile-work-codex/rules/RULES_INDEX.md",
    "plugins/dotfile-work-codex/rules/RULES_BUNDLE.md",
    "plugins/dotfile-work-codex/rules/command-safety.rules",
    "plugins/dotfile-work-codex-extra/.codex-plugin/plugin.json",
    ".agents/plugins/marketplace.json",
]

FORBIDDEN = [
    "plugins/dotfile-work-codex/prompts",
    "plugins/dotfile-work-codex/hooks/prompt-command-expand.sh",
    "codex/prompts",
    "codex/hooks/prompt-command-expand.sh",
    "codex/bin/codex-prompt",
    "codex/bin/codex-cmd",
]

CORE_PLUGIN = "dotfile-work-codex"
EXTRA_PLUGIN = "dotfile-work-codex-extra"
PORT_SCRIPT = Path(__file__).with_name("port-claude-assets-to-codex.py")
ASSET_MANIFEST_PATH = Path(__file__).with_name("claude-command-map.json")
_PORTER_MODULE: ModuleType | None = None
AGGREGATED_RULE_FILES = frozenset({RULE_BUNDLE_NAME, RULE_INDEX_NAME})


ASSET_MANIFEST = load_asset_manifest(ASSET_MANIFEST_PATH)
CODEX_NATIVE_SKILLS = ASSET_MANIFEST.codex_native_skills
CORE_SKILLS = ASSET_MANIFEST.core_skills


def _load_porter() -> ModuleType:
    global _PORTER_MODULE
    if _PORTER_MODULE is not None:
        return _PORTER_MODULE
    spec = importlib.util.spec_from_file_location(
        "dotfile_work_asset_porter", PORT_SCRIPT
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {PORT_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    _PORTER_MODULE = module
    return module


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def check_required_paths(root: Path) -> int:
    missing = [p for p in REQUIRED if not (root / p).exists()]
    if missing:
        for p in missing:
            print(f"MISSING: {p}", file=sys.stderr)
        return 3
    return 0


def check_forbidden_paths(root: Path) -> int:
    forbidden = [p for p in FORBIDDEN if (root / p).exists()]
    if forbidden:
        for p in forbidden:
            print(f"FORBIDDEN_LEGACY: {p}", file=sys.stderr)
        return 7
    return 0


def check_core_manifest(root: Path) -> int:
    manifest = load(root / "plugins/dotfile-work-codex/.codex-plugin/plugin.json")
    if manifest.get("name") != CORE_PLUGIN:
        print("BAD core manifest name", file=sys.stderr)
        return 4
    if "hooks" not in manifest or "skills" not in manifest:
        print("BAD core manifest missing hooks/skills", file=sys.stderr)
        return 4
    blob = json.dumps(manifest).lower()
    if "prompt:" in blob or "codex-prompt" in blob:
        print("BAD core manifest contains legacy prompt compatibility", file=sys.stderr)
        return 4
    return 0


def check_extra_manifest(root: Path) -> int:
    extra = load(root / "plugins/dotfile-work-codex-extra/.codex-plugin/plugin.json")
    if extra.get("name") != EXTRA_PLUGIN or "hooks" in extra:
        print("BAD extra manifest", file=sys.stderr)
        return 5
    return 0


def check_marketplace(root: Path) -> int:
    marketplace = load(root / ".agents/plugins/marketplace.json")
    names = {p.get("name") for p in marketplace.get("plugins", [])}
    if CORE_PLUGIN not in names or EXTRA_PLUGIN not in names:
        print("BAD marketplace missing core/extra plugins", file=sys.stderr)
        return 5
    return 0


def check_hook_commands(root: Path) -> int:
    hooks = json.dumps(load(root / "plugins/dotfile-work-codex/hooks/hooks.json"))
    for needle in ["${PLUGIN_ROOT}/hooks/rules-inject.sh", "${PLUGIN_ROOT}/hooks/rules-guard.sh"]:
        if needle not in hooks:
            print(f"MISSING hook command: {needle}", file=sys.stderr)
            return 6
    return 0


def _skill_names(skills_dir: Path) -> set[str]:
    if not skills_dir.exists():
        return set()
    return {
        path.name
        for path in skills_dir.iterdir()
        if path.is_dir() and (path / "SKILL.md").is_file()
    }


def _skill_files(skill_dir: Path) -> dict[Path, bytes]:
    return {
        path.relative_to(skill_dir): path.read_bytes()
        for path in skill_dir.rglob("*")
        if path.is_file() and not path.name.endswith(".bak")
    }


def check_shared_skill_catalog(root: Path) -> int:
    shared_skills = _skill_names(root / "common" / "skills")
    codex_skills = _skill_names(root / "codex" / "skills")
    overlaps = shared_skills & CODEX_NATIVE_SKILLS
    expected = shared_skills | CODEX_NATIVE_SKILLS
    if overlaps or codex_skills != expected:
        print(
            f"SHARED_SKILL_SET_DRIFT: missing={sorted(expected - codex_skills)} "
            f"unexpected={sorted(codex_skills - expected)} "
            f"native_overlaps={sorted(overlaps)}",
            file=sys.stderr,
        )
        return 11
    return 0


def check_core_skill_catalog(root: Path) -> int:
    available_skills = (
        _skill_names(root / "common" / "skills") | CODEX_NATIVE_SKILLS
    )
    unknown_core_skills = CORE_SKILLS - available_skills
    if unknown_core_skills:
        print(
            f"CORE_SKILL_CATALOG_DRIFT: unknown={sorted(unknown_core_skills)}",
            file=sys.stderr,
        )
        return 13
    return 0


def _find_stale_shared_output(
    root: Path,
    source_roots: frozenset[tuple[str, str]],
) -> Path | None:
    porter = _load_porter()
    generated_roots = (root / "codex" / "rules", root / "codex" / "skills")
    generated_files = sorted(
        path
        for generated_root in generated_roots
        for path in generated_root.rglob("*")
        if path.is_file()
        and not path.name.endswith(".bak")
        and path.name not in AGGREGATED_RULE_FILES
    )
    for generated in generated_files:
        source = porter.managed_source(generated)
        if source is None or tuple(source.parts[:2]) not in source_roots:
            continue
        expected = porter.expected_managed_destination(root, source)
        if (root / source).is_file() and expected == generated:
            continue
        return generated
    return None


def _is_transformed_source_current(
    root: Path,
    porter: ModuleType,
    source: Path,
    kind: str,
) -> bool:
    relative_source = source.relative_to(root)
    generated = porter.expected_managed_destination(root, relative_source)
    if generated is None or not generated.is_file():
        return False
    expected, _role = porter.transform_source(source, repo=root, kind=kind)
    return generated.read_text(encoding="utf-8") == expected.rstrip() + "\n"


def _find_shared_skill_resource_drift(
    root: Path,
    porter: ModuleType,
    source: Path,
) -> Path | None:
    for resource in sorted(source.parent.rglob("*")):
        if not resource.is_file() or resource == source:
            continue
        relative_resource = resource.relative_to(source.parent)
        if not _is_transformed_source_current(
            root, porter, resource, "skill_resource"
        ):
            return Path(source.parent.name) / relative_resource
    return None


def _find_shared_skill_content_drift(
    root: Path,
    porter: ModuleType,
) -> Path | None:
    for source in porter.iter_skill_sources(root):
        if not _is_transformed_source_current(root, porter, source, "skill"):
            return Path(source.parent.name) / "SKILL.md"
        resource_drift = _find_shared_skill_resource_drift(root, porter, source)
        if resource_drift is not None:
            return resource_drift
    return None


def check_shared_skill_source_sync(root: Path) -> int:
    porter = _load_porter()
    shared_dir = root / "common" / "skills"
    if not shared_dir.is_dir():
        print("SHARED_SKILL_SOURCE_MISSING: common/skills", file=sys.stderr)
        return 10

    porter.validate_shared_skill_layout(root)
    porter.validate_skill_resources(root)
    content_drift = _find_shared_skill_content_drift(root, porter)
    if content_drift is not None:
        print(f"SHARED_SKILL_CONTENT_DRIFT: {content_drift}", file=sys.stderr)
        return 10
    stale_output = _find_stale_shared_output(
        root,
        frozenset({("common", "skills")}),
    )
    if stale_output is not None:
        print(
            f"SHARED_SKILL_STALE_OUTPUT: {stale_output.relative_to(root)}",
            file=sys.stderr,
        )
        return 10
    return 0


def _find_shared_rule_content_drift(
    root: Path,
    porter: ModuleType,
) -> Path | None:
    for source in porter.iter_rule_sources(root):
        if not _is_transformed_source_current(root, porter, source, "rule"):
            return Path(source.name)
    return None


def _find_shared_command_content_drift(
    root: Path,
    porter: ModuleType,
) -> Path | None:
    for source in porter.iter_command_sources(root):
        if not _is_transformed_source_current(root, porter, source, "command"):
            return Path(source.name)
    return None


def _missing_shared_asset_source(root: Path) -> str | None:
    source_dirs = (root / "common" / "rules", root / "common" / "commands")
    missing_dirs = [path.relative_to(root) for path in source_dirs if not path.is_dir()]
    if missing_dirs:
        return f"missing={','.join(str(path) for path in missing_dirs)}"
    return None


def check_shared_rule_and_command_source_sync(root: Path) -> int:
    porter = _load_porter()
    missing_source = _missing_shared_asset_source(root)
    if missing_source is not None:
        print(f"SHARED_ASSET_SOURCE_INVALID: {missing_source}", file=sys.stderr)
        return 12
    porter.validate_command_manifest(porter.iter_command_sources(root))
    rule_drift = _find_shared_rule_content_drift(root, porter)
    if rule_drift is not None:
        print(f"SHARED_RULE_CONTENT_DRIFT: {rule_drift}", file=sys.stderr)
        return 12
    command_drift = _find_shared_command_content_drift(root, porter)
    if command_drift is not None:
        print(f"SHARED_COMMAND_CONTENT_DRIFT: {command_drift}", file=sys.stderr)
        return 12
    stale_output = _find_stale_shared_output(
        root,
        frozenset({("common", "rules"), ("common", "commands")}),
    )
    if stale_output is not None:
        print(
            f"SHARED_ASSET_STALE_OUTPUT: {stale_output.relative_to(root)}",
            file=sys.stderr,
        )
        return 12
    return 0


def check_skill_sync(root: Path) -> int:
    source_dir = root / "codex" / "skills"
    core_dir = root / "plugins" / CORE_PLUGIN / "skills"
    extra_dir = root / "plugins" / EXTRA_PLUGIN / "skills"
    source_skills = _skill_names(source_dir)
    core_skills = _skill_names(core_dir)
    extra_skills = _skill_names(extra_dir)

    expected_core = source_skills & CORE_SKILLS
    expected_extra = source_skills - CORE_SKILLS
    if core_skills != expected_core or extra_skills != expected_extra:
        print(
            f"SKILL_TIER_DRIFT: "
            f"core_missing={sorted(expected_core - core_skills)} "
            f"core_unexpected={sorted(core_skills - expected_core)} "
            f"extra_missing={sorted(expected_extra - extra_skills)} "
            f"extra_unexpected={sorted(extra_skills - expected_extra)}",
            file=sys.stderr,
        )
        return 8

    for name in sorted(source_skills):
        plugin_dir = core_dir / name if name in expected_core else extra_dir / name
        if _skill_files(source_dir / name) != _skill_files(plugin_dir):
            print(f"SKILL_CONTENT_DRIFT: {name}", file=sys.stderr)
            return 8
    return 0


def _tree_files(root: Path) -> dict[Path, bytes]:
    if not root.exists():
        return {}
    return {
        path.relative_to(root): path.read_bytes()
        for path in root.rglob("*")
        if path.is_file() and not path.name.endswith(".bak")
    }


def check_rule_aggregate_sync(root: Path) -> int:
    rules_dir = root / "codex" / "rules"
    index_path = rules_dir / RULE_INDEX_NAME
    bundle_path = rules_dir / RULE_BUNDLE_NAME
    if not index_path.is_file() or not bundle_path.is_file():
        print("RULE_AGGREGATE_DRIFT: missing index or bundle", file=sys.stderr)
        return 9

    documents = load_rule_documents(root)
    actual_index = index_path.read_text(encoding="utf-8")
    actual_bundle = bundle_path.read_text(encoding="utf-8")

    changed = []
    if actual_index != render_rule_index(documents):
        changed.append(RULE_INDEX_NAME)
    if actual_bundle != render_rule_bundle(documents):
        changed.append(RULE_BUNDLE_NAME)
    if changed:
        print(f"RULE_AGGREGATE_DRIFT: changed={changed}", file=sys.stderr)
        return 9
    return 0


def check_rule_sync(root: Path) -> int:
    source_dir = root / "codex" / "rules"
    plugin_dir = root / "plugins" / CORE_PLUGIN / "rules"
    source_files = _tree_files(source_dir)
    plugin_files = _tree_files(plugin_dir)
    if source_files != plugin_files:
        source_paths = set(source_files)
        plugin_paths = set(plugin_files)
        changed = sorted(
            str(path)
            for path in source_paths & plugin_paths
            if source_files[path] != plugin_files[path]
        )
        print(
            f"RULE_CONTENT_DRIFT: missing={sorted(map(str, source_paths - plugin_paths))} "
            f"unexpected={sorted(map(str, plugin_paths - source_paths))} "
            f"changed={changed}",
            file=sys.stderr,
        )
        return 9
    return 0


def report_skill_counts(root: Path) -> None:
    shared_skills = _skill_names(root / "common" / "skills")
    core_skills = _skill_names(root / "plugins" / CORE_PLUGIN / "skills")
    extra_skills = _skill_names(root / "plugins" / EXTRA_PLUGIN / "skills")
    if len(core_skills) > 24:
        print(f"WARN: core skill count is high: {len(core_skills)}", file=sys.stderr)
    print(
        f"OK shared_skills={len(shared_skills)} "
        f"codex_native_skills={len(CODEX_NATIVE_SKILLS)} "
        f"core_skills={len(core_skills)} extra_skills={len(extra_skills)}"
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()
    root = Path(args.repo).resolve()

    for check in [
        check_required_paths,
        check_forbidden_paths,
        check_core_manifest,
        check_extra_manifest,
        check_marketplace,
        check_hook_commands,
        check_core_skill_catalog,
        check_shared_skill_catalog,
        check_shared_skill_source_sync,
        check_shared_rule_and_command_source_sync,
        check_skill_sync,
        check_rule_aggregate_sync,
        check_rule_sync,
    ]:
        result = check(root)
        if result != 0:
            return result

    report_skill_counts(root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
