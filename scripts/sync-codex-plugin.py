#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import stat
from datetime import datetime, timezone
from pathlib import Path

CORE_PLUGIN = "dotfile-work-codex"
EXTRA_PLUGIN = "dotfile-work-codex-extra"
VERSION = "0.3.0"

CORE_SKILLS = {
    "feat",
    "fix",
    "review",
    "deep-review",
    "security-review",
    "test",
    "refactor",
    "tdd",
    "systematic-debugging",
    "rules-required",
    "consultation",
    "codex-handoff",
    "implementation-router",
    "plan",
    "explain",
    "commit-msg",
    "plugin-sync",
    "plugin-install",
}

EXCLUDE_DOCS = {"RECOMMENDATIONS.md", "CLAUDE_PORT_REPORT.md", "PLUGIN_ONLY_WORKFLOWS.md", "SKILL_POLICY.md"}


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def chmodx(path: Path) -> None:
    if path.exists() and path.is_file():
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def copy_file(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def copytree(src: Path, dst: Path, ignore_names: set[str] | None = None) -> None:
    ignore_names = ignore_names or set()
    if not src.exists():
        return
    if dst.exists():
        shutil.rmtree(dst)

    def ignore(_dir: str, names: list[str]) -> set[str]:
        return {n for n in names if n in ignore_names or n.endswith(".bak") or n == "__pycache__"}

    shutil.copytree(src, dst, ignore=ignore)


def copy_skills(src_dir: Path, dst_dir: Path, mode: str) -> list[str]:
    if dst_dir.exists():
        shutil.rmtree(dst_dir)
    dst_dir.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    if not src_dir.exists():
        return copied
    for skill in sorted(p for p in src_dir.iterdir() if p.is_dir() and (p / "SKILL.md").exists()):
        is_core = skill.name in CORE_SKILLS
        if mode == "core" and not is_core:
            continue
        if mode == "extra" and is_core:
            continue
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
            "longDescription": "Performance profile: small core skill set, markdown rule injection, rules guard, and official command-safety .rules.",
            "developerName": "TakumiOkayasu",
            "category": "Productivity",
            "capabilities": ["Read", "Write"],
            "defaultPrompt": [
                "Use $feat to implement a feature with risk-gated TDD.",
                "Use $fix to repair a reproducible bug after root-cause analysis.",
                "Use $deep-review to review the current diff.",
                "Use $rules-required to load and apply mandatory rules."
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
                {"hooks": [{"type": "command", "command": "${PLUGIN_ROOT}/hooks/rules-inject.sh", "timeout": 30, "statusMessage": "Loading core dotfile-work rules"}]}
            ],
            "UserPromptSubmit": [
                {"hooks": [{"type": "command", "command": "${PLUGIN_ROOT}/hooks/rules-inject.sh", "timeout": 30, "statusMessage": "Checking rule scope"}]}
            ],
            "PreToolUse": [
                {"matcher": "Bash|Edit|Write|MultiEdit|apply_patch|ApplyPatch", "hooks": [{"type": "command", "command": "${PLUGIN_ROOT}/hooks/rules-guard.sh", "timeout": 30, "statusMessage": "Checking mandatory rules"}]}
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


def sync_core(root: Path, clean: bool) -> None:
    codex = root / "codex"
    plugin = root / "plugins" / CORE_PLUGIN
    if clean and plugin.exists():
        shutil.rmtree(plugin)
    plugin.mkdir(parents=True, exist_ok=True)
    (plugin / ".codex-plugin").mkdir(parents=True, exist_ok=True)
    skills = copy_skills(codex / "skills", plugin / "skills", "core")
    copytree(codex / "rules", plugin / "rules")
    copytree(codex / "bin", plugin / "bin")
    hooks_dir = plugin / "hooks"
    if hooks_dir.exists():
        shutil.rmtree(hooks_dir)
    hooks_dir.mkdir(parents=True, exist_ok=True)
    for name in ["rules-inject.sh", "rules-guard.sh"]:
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
        "Optional skills live in `dotfile-work-codex-extra`; keep that plugin disabled unless needed.\n"
        f"Generated at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n",
        encoding="utf-8"
    )


def sync_extra(root: Path, clean: bool) -> None:
    codex = root / "codex"
    plugin = root / "plugins" / EXTRA_PLUGIN
    if clean and plugin.exists():
        shutil.rmtree(plugin)
    plugin.mkdir(parents=True, exist_ok=True)
    (plugin / ".codex-plugin").mkdir(parents=True, exist_ok=True)
    skills = copy_skills(codex / "skills", plugin / "skills", "extra")
    write_json(plugin / ".codex-plugin" / "plugin.json", extra_manifest())
    (plugin / "README.md").write_text(
        "# dotfile-work Codex Extra Skills\n\n"
        "Optional explicit-use skills ported from Claude Code. Enable only when needed.\n\n"
        f"Optional skills: {', '.join(skills) if skills else '(none)'}\n\n"
        f"Generated at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n",
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
    sync_core(root, args.clean)
    sync_extra(root, args.clean)
    write_json(root / ".agents" / "plugins" / "marketplace.json", marketplace())
    print(f"synced plugins: plugins/{CORE_PLUGIN}, plugins/{EXTRA_PLUGIN}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
