#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

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


def check_skill_sync(root: Path) -> int:
    source_dir = root / "codex" / "skills"
    core_dir = root / "plugins" / CORE_PLUGIN / "skills"
    extra_dir = root / "plugins" / EXTRA_PLUGIN / "skills"
    source_skills = _skill_names(source_dir)
    core_skills = _skill_names(core_dir)
    extra_skills = _skill_names(extra_dir)

    duplicates = core_skills & extra_skills
    distributed = core_skills | extra_skills
    if duplicates or distributed != source_skills:
        print(
            f"SKILL_SET_DRIFT: missing={sorted(source_skills - distributed)} "
            f"unexpected={sorted(distributed - source_skills)} "
            f"duplicates={sorted(duplicates)}",
            file=sys.stderr,
        )
        return 8

    for name in sorted(source_skills):
        plugin_dir = core_dir / name if name in core_skills else extra_dir / name
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
    core_skills = [p.name for p in (root / "plugins/dotfile-work-codex/skills").iterdir() if p.is_dir()]
    extra_skills_dir = root / "plugins/dotfile-work-codex-extra/skills"
    extra_skills = [p.name for p in extra_skills_dir.iterdir() if p.is_dir()] if extra_skills_dir.exists() else []
    if len(core_skills) > 24:
        print(f"WARN: core skill count is high: {len(core_skills)}", file=sys.stderr)
    print(f"OK core_skills={len(core_skills)} extra_skills={len(extra_skills)}")


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
        check_skill_sync,
        check_rule_sync,
    ]:
        result = check(root)
        if result != 0:
            return result

    report_skill_counts(root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
