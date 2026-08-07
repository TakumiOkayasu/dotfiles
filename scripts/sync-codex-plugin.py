#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import stat
import sys
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from codex_asset_manifest import load_asset_manifest

CORE_PLUGIN = "dotfile-work-codex"
EXTRA_PLUGIN = "dotfile-work-codex-extra"
VERSION = "0.3.0"
ASSET_MANIFEST_PATH = Path(__file__).with_name("claude-command-map.json")
CORE_SKILLS = load_asset_manifest(ASSET_MANIFEST_PATH).core_skills

def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def chmodx(path: Path) -> None:
    if path.exists() and path.is_file():
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def copy_file(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def copytree(src: Path, dst: Path) -> None:
    if not src.exists():
        return
    if dst.exists():
        shutil.rmtree(dst)

    def ignore(_dir: str, names: list[str]) -> set[str]:
        return {n for n in names if n.endswith(".bak") or n == "__pycache__"}

    shutil.copytree(src, dst, ignore=ignore)


def partition_skills(src_dir: Path) -> tuple[tuple[Path, ...], tuple[Path, ...]]:
    if not src_dir.exists():
        return (), ()
    core: list[Path] = []
    extra: list[Path] = []
    for skill in sorted(src_dir.iterdir()):
        if not skill.is_dir() or not (skill / "SKILL.md").is_file():
            continue
        destination = core if skill.name in CORE_SKILLS else extra
        destination.append(skill)
    return tuple(core), tuple(extra)


def copy_skills(skills: tuple[Path, ...], dst_dir: Path) -> list[str]:
    if dst_dir.exists():
        shutil.rmtree(dst_dir)
    dst_dir.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for skill in skills:
        shutil.copytree(skill, dst_dir / skill.name, ignore=shutil.ignore_patterns("*.bak", "__pycache__"))
        copied.append(skill.name)
    return copied


def core_manifest() -> dict:
    return {
        "name": CORE_PLUGIN,
        "version": VERSION,
        "description": "Performance-optimized core Codex workflows, skills, rules, and safety hooks for dotfile-work.",
        "author": {"name": "TakumiOkayasu"},
        "repository": "https://github.com/TakumiOkayasu/dotfile-work",
        "license": "MIT",
        "keywords": ["codex", "skills", "hooks", "rules", "tdd", "review"],
        "skills": "./skills/",
        "hooks": "./hooks/hooks.json",
        "interface": {
            "displayName": "dotfile-work Codex Core",
            "shortDescription": "Core @skills with mandatory rule enforcement.",
            "longDescription": "Performance profile: small core skill set, selective markdown rule loading, rules guard, and official command-safety .rules.",
            "developerName": "TakumiOkayasu",
            "category": "Productivity",
            "capabilities": ["Read", "Write"],
            "defaultPrompt": [
                "Use $feat to implement a feature with risk-gated TDD.",
                "Use $fix to repair a reproducible bug after root-cause analysis.",
                "Use $deep-review to review the current diff.",
                "Use $rules-required to select and apply task-applicable rules."
            ]
        }
    }


def extra_manifest() -> dict:
    return {
        "name": EXTRA_PLUGIN,
        "version": VERSION,
        "description": "Optional Codex skills ported from Claude Code for dotfile-work.",
        "author": {"name": "TakumiOkayasu"},
        "repository": "https://github.com/TakumiOkayasu/dotfile-work",
        "license": "MIT",
        "keywords": ["codex", "skills", "optional", "claude-port"],
        "skills": "./skills/",
        "interface": {
            "displayName": "dotfile-work Codex Extra Skills",
            "shortDescription": "Optional explicit-use skills. Enable only when needed.",
            "longDescription": "Optional Claude Code skill ports. Keep disabled unless you need the broader skill catalog to preserve Codex's initial skill budget.",
            "developerName": "TakumiOkayasu",
            "category": "Productivity",
            "capabilities": ["Read"],
            "defaultPrompt": [
                "Use an optional skill explicitly with $skill-name when a specialized workflow is needed."
            ]
        }
    }


def hooks() -> dict:
    return {
        "hooks": {
            "SessionStart": [
                {"hooks": [{"type": "command", "command": "${PLUGIN_ROOT}/hooks/rules-inject.sh --skip-if-inline", "timeout": 30, "statusMessage": "Activating core dotfile-work rules"}]}
            ],
            "UserPromptSubmit": [
                {"hooks": [{"type": "command", "command": "${PLUGIN_ROOT}/hooks/rules-inject.sh --skip-if-inline", "timeout": 30, "statusMessage": "Activating task rule scope"}]}
            ],
            "PreToolUse": [
                {"matcher": "Bash|Edit|Write|MultiEdit|apply_patch|ApplyPatch", "hooks": [{"type": "command", "command": "${PLUGIN_ROOT}/hooks/rules-guard.sh --skip-if-inline", "timeout": 30, "statusMessage": "Checking mandatory rules"}]}
            ]
        }
    }


def marketplace() -> dict:
    return {
        "name": "dotfile-work-local",
        "interface": {"displayName": "dotfile-work plugins"},
        "plugins": [
            {
                "name": CORE_PLUGIN,
                "source": {"source": "local", "path": f"./plugins/{CORE_PLUGIN}"},
                "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
                "category": "Productivity"
            },
            {
                "name": EXTRA_PLUGIN,
                "source": {"source": "local", "path": f"./plugins/{EXTRA_PLUGIN}"},
                "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
                "category": "Productivity"
            }
        ]
    }


def sync_core(root: Path, clean: bool, skills_to_copy: tuple[Path, ...]) -> None:
    codex = root / "codex"
    plugin = root / "plugins" / CORE_PLUGIN
    if clean and plugin.exists():
        shutil.rmtree(plugin)
    plugin.mkdir(parents=True, exist_ok=True)
    (plugin / ".codex-plugin").mkdir(parents=True, exist_ok=True)
    skills = copy_skills(skills_to_copy, plugin / "skills")
    copytree(codex / "rules", plugin / "rules")
    copytree(codex / "bin", plugin / "bin")
    hooks_dir = plugin / "hooks"
    if hooks_dir.exists():
        shutil.rmtree(hooks_dir)
    hooks_dir.mkdir(parents=True, exist_ok=True)
    for name in ["rules-lib.sh", "rules-inject.sh", "rules-guard.sh"]:
        src = codex / "hooks" / name
        if src.exists():
            copy_file(src, hooks_dir / name)
    write_json(plugin / ".codex-plugin" / "plugin.json", core_manifest())
    write_json(plugin / "hooks" / "hooks.json", hooks())
    for p in list((plugin / "hooks").glob("*.sh")) + list((plugin / "bin").glob("*")):
        chmodx(p)
    (plugin / "README.md").write_text(
        "# dotfile-work Codex Core\n\n"
        "Performance-optimized core plugin. Use `$feat`, `$fix`, `$deep-review`, `$rules-required`.\n\n"
        f"Core skills: {', '.join(skills)}\n\n"
        "Optional skills live in `dotfile-work-codex-extra`; keep that plugin disabled unless needed.\n",
        encoding="utf-8"
    )


def sync_extra(root: Path, clean: bool, skills_to_copy: tuple[Path, ...]) -> None:
    codex = root / "codex"
    plugin = root / "plugins" / EXTRA_PLUGIN
    if clean and plugin.exists():
        shutil.rmtree(plugin)
    plugin.mkdir(parents=True, exist_ok=True)
    (plugin / ".codex-plugin").mkdir(parents=True, exist_ok=True)
    skills = copy_skills(skills_to_copy, plugin / "skills")
    write_json(plugin / ".codex-plugin" / "plugin.json", extra_manifest())
    (plugin / "README.md").write_text(
        "# dotfile-work Codex Extra Skills\n\n"
        "Optional explicit-use skills ported from Claude Code. Enable only when needed.\n\n"
        f"Optional skills: {', '.join(skills) if skills else '(none)'}\n",
        encoding="utf-8"
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--clean", action="store_true")
    args = ap.parse_args()
    root = Path(args.repo).resolve()
    if not (root / "codex").is_dir():
        raise SystemExit(f"missing codex dir: {root / 'codex'}")
    core_skills, extra_skills = partition_skills(root / "codex" / "skills")
    sync_core(root, args.clean, core_skills)
    sync_extra(root, args.clean, extra_skills)
    write_json(root / ".agents" / "plugins" / "marketplace.json", marketplace())
    print(f"synced plugins: plugins/{CORE_PLUGIN}, plugins/{EXTRA_PLUGIN}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
