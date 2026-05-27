#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REQUIRED = [
    "plugins/dotfile-work-codex/.codex-plugin/plugin.json",
    "plugins/dotfile-work-codex/hooks/hooks.json",
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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()
    root = Path(args.repo).resolve()

    missing = [p for p in REQUIRED if not (root / p).exists()]
    if missing:
        for p in missing:
            print(f"MISSING: {p}", file=sys.stderr)
        return 3

    forbidden = [p for p in FORBIDDEN if (root / p).exists()]
    if forbidden:
        for p in forbidden:
            print(f"FORBIDDEN_LEGACY: {p}", file=sys.stderr)
        return 7

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

    extra = load(root / "plugins/dotfile-work-codex-extra/.codex-plugin/plugin.json")
    if extra.get("name") != EXTRA_PLUGIN or "hooks" in extra:
        print("BAD extra manifest", file=sys.stderr)
        return 5

    marketplace = load(root / ".agents/plugins/marketplace.json")
    names = {p.get("name") for p in marketplace.get("plugins", [])}
    if CORE_PLUGIN not in names or EXTRA_PLUGIN not in names:
        print("BAD marketplace missing core/extra plugins", file=sys.stderr)
        return 5

    hooks = json.dumps(load(root / "plugins/dotfile-work-codex/hooks/hooks.json"))
    for needle in ["${PLUGIN_ROOT}/hooks/rules-inject.sh", "${PLUGIN_ROOT}/hooks/rules-guard.sh"]:
        if needle not in hooks:
            print(f"MISSING hook command: {needle}", file=sys.stderr)
            return 6

    core_skills = [p.name for p in (root / "plugins/dotfile-work-codex/skills").iterdir() if p.is_dir()]
    extra_skills_dir = root / "plugins/dotfile-work-codex-extra/skills"
    extra_skills = [p.name for p in extra_skills_dir.iterdir() if p.is_dir()] if extra_skills_dir.exists() else []
    if len(core_skills) > 24:
        print(f"WARN: core skill count is high: {len(core_skills)}", file=sys.stderr)
    print(f"OK core_skills={len(core_skills)} extra_skills={len(extra_skills)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
