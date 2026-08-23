#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import stat
import sys
from pathlib import Path

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

ASSET_MANIFEST_PATH = Path(__file__).with_name("claude-command-map.json")
CORE_SKILLS = load_asset_manifest(ASSET_MANIFEST_PATH).core_skills

RULES_CORE = """# RULES_CORE

These are the short, always-on invariants for dotfile-work Codex.

## Priority

1. User instruction
2. Nearest project `AGENTS.md`
3. Plugin/project markdown rules
4. Active skill workflow
5. General best practice

When instructions conflict, follow the higher-priority source and report the conflict.

## Mandatory behavior

- Read and apply the full applicable rules before editing files, running mutating commands, reviewing code, or giving implementation conclusions.
- Do not edit unread files.
- Do not overwrite user changes or unrelated diffs.
- Do not run destructive commands, dependency changes, DB/API changes, `sudo`, commit, push, deploy, or external writes without explicit user approval.
- Prefer existing project conventions, pinned tool versions, and project-defined test/lint/build commands.
- Do not invent APIs, options, packages, paths, environment variables, schemas, or test results. Verify or mark `[要確認: reason]`.
- Report verification honestly: passed, failed, skipped with reason, and remaining risk.

## Routing

- Feature implementation -> `$feat` -> `tdd` and design skills only when needed.
- Bug/failing test -> `$fix` -> `systematic-debugging` before patching.
- Review -> `$review` or `$deep-review`.
- Rule uncertainty -> `$rules-required`.

## High-risk triggers

Treat as high-risk: DB schema, public API/SDK/CLI contract, auth/authorization, secrets, payments, dependency add/remove/update, data migration/destructive change, 100+ changed lines, multiple services, or unclear requirements.
"""

SAFETY_RULES = r'''# Codex command safety rules for dotfile-work.
# These are official Codex command execution rules, not markdown coding rules.
# Markdown coding/design rules remain in *.md and must be read explicitly when applicable.

prefix_rule(
    pattern = ["git", "commit"],
    decision = "forbidden",
    justification = "AI must not create commits. Ask the user to run git commit after reviewing the proposed message.",
    match = [["git", "commit", "-m", "msg"]],
)

prefix_rule(
    pattern = ["git", "push"],
    decision = "forbidden",
    justification = "AI must not push changes. Ask the user to push after review.",
    match = [["git", "push"]],
)

prefix_rule(
    pattern = ["git", "reset", "--hard"],
    decision = "forbidden",
    justification = "git reset --hard can destroy user changes. Use non-destructive inspection or ask the user.",
    match = [["git", "reset", "--hard"]],
)

prefix_rule(
    pattern = ["git", "clean"],
    decision = "prompt",
    justification = "git clean can delete untracked files. Require user approval.",
    match = [["git", "clean", "-fd"]],
)

prefix_rule(
    pattern = ["rm", "-rf"],
    decision = "forbidden",
    justification = "rm -rf is destructive. Ask the user or use targeted non-recursive deletion with approval.",
    match = [["rm", "-rf", "tmp"]],
)

prefix_rule(
    pattern = ["sudo"],
    decision = "forbidden",
    justification = "Do not run privileged commands from Codex. Ask the user to execute them manually.",
    match = [["sudo", "apt", "update"]],
)

prefix_rule(
    pattern = ["su"],
    decision = "forbidden",
    justification = "Do not switch users from Codex. Ask the user.",
    match = [["su", "-", "root"]],
)

prefix_rule(
    pattern = ["doas"],
    decision = "forbidden",
    justification = "Do not run privileged commands from Codex. Ask the user.",
    match = [["doas", "pkg", "install", "x"]],
)

prefix_rule(
    pattern = ["docker", "system", "prune"],
    decision = "forbidden",
    justification = "docker system prune can remove images, containers, networks, or cache. Ask the user.",
    match = [["docker", "system", "prune", "-af"]],
)

prefix_rule(
    pattern = ["docker", "volume", "rm"],
    decision = "forbidden",
    justification = "docker volume rm can delete persistent data. Ask the user.",
    match = [["docker", "volume", "rm", "db"]],
)

prefix_rule(
    pattern = ["gh", "repo", "delete"],
    decision = "forbidden",
    justification = "Repository deletion is destructive. Ask the user.",
    match = [["gh", "repo", "delete", "owner/repo"]],
)
'''

OPENAI_YAML_TEMPLATE = """interface:
  display_name: "{display}"
  short_description: "{short}"
  default_prompt: "{prompt}"
policy:
  allow_implicit_invocation: {implicit}
"""

CORE_SHORT = {
    "feat": "Risk-gated feature implementation with TDD.",
    "fix": "Root-cause bug fixing with regression tests.",
    "review": "Evidence-based code review with fix proposals.",
    "deep-review": "Security, performance, and maintainability review synthesis.",
    "security-review": "Security-only review for auth, input, secrets, injection, SSRF, XSS, traversal.",
    "test": "Add meaningful tests following existing project conventions.",
    "refactor": "Behavior-preserving structure improvement.",
    "tdd": "RED-GREEN-REFACTOR test-driven workflow.",
    "systematic-debugging": "Reproduce, trace, root cause, then patch.",
    "rules-required": "Read and apply mandatory markdown rules.",
    "consult": "Compare 2-3 implementation plans and create handoff.",
    "codex-handoff": "Create compact Codex continuation handoff.",
    "implementation-router": "Classify implementation risk and route skills.",
    "plan": "Planning-only, no file changes.",
    "explain": "Code explanation only, no file changes.",
    "commit-msg": "Generate commit message proposal without committing.",
    "plugin-sync": "Sync codex assets into plugin bundle.",
    "plugin-install": "Install local plugin marketplace for this user.",
    "semantic-generation": "Build a referent table before drafting or naming.",
}

DEFAULT_PROMPTS = {
    "semantic-generation": "Use $semantic-generation to create a referent table before drafting.",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def generate_rules(root: Path) -> None:
    rules_dir = root / "codex" / "rules"
    rules_dir.mkdir(parents=True, exist_ok=True)
    write_text(rules_dir / "RULES_CORE.md", RULES_CORE)
    write_text(rules_dir / "command-safety.rules", SAFETY_RULES)

    documents = load_rule_documents(root)
    write_text(rules_dir / RULE_INDEX_NAME, render_rule_index(documents))
    write_text(
        rules_dir / RULE_BUNDLE_NAME,
        render_rule_bundle(documents),
    )


def skill_directories(skills_dir: Path) -> tuple[Path, ...]:
    if not skills_dir.exists():
        return ()
    return tuple(
        sorted(
            path
            for path in skills_dir.iterdir()
            if path.is_dir() and (path / "SKILL.md").is_file()
        )
    )


def allows_implicit_invocation(root: Path, skill_name: str) -> bool:
    shared_skill = root / "common" / "skills" / skill_name / "SKILL.md"
    if not shared_skill.is_file():
        return skill_name in CORE_SKILLS
    frontmatter = read_text(shared_skill).split("\n---\n", 1)[0]
    return re.search(
        r"^disable-model-invocation:\s*(?:true|yes|on|1)\s*$",
        frontmatter,
        flags=re.MULTILINE | re.IGNORECASE,
    ) is None


def add_openai_yaml(root: Path, skills: tuple[Path, ...]) -> None:
    for skill in skills:
        name = skill.name
        implicit = "true" if allows_implicit_invocation(root, name) else "false"
        short = CORE_SHORT.get(name, "Optional workflow skill. Explicit invocation recommended.")
        display = name.replace("-", " ").title()
        prompt = DEFAULT_PROMPTS.get(name, f"Use ${name} for this task.")
        write_text(skill / "agents" / "openai.yaml", OPENAI_YAML_TEMPLATE.format(
            display=display,
            short=short.replace('"', "'"),
            prompt=prompt.replace('"', "'"),
            implicit=implicit,
        ))


def patch_install_mapping(root: Path) -> None:
    path = root / "install.sh"
    if not path.exists():
        return
    text = read_text(path)
    original = text
    # Include official *.rules in Codex install mapping, but do not symlink codex/skills into ~/.agents by default.
    text = text.replace("bin/*.sh|hooks/*.sh|prompts/commands/*.md|rules/*.md)", "bin/*|hooks/*|rules/*.md|rules/*.rules)")
    text = text.replace("bin/*|hooks/*.sh|rules/*.md)", "bin/*|hooks/*|rules/*.md|rules/*.rules)")
    text = text.replace("bin/*.sh|hooks/*.sh|rules/*.md)", "bin/*|hooks/*|rules/*.md|rules/*.rules)")
    text = text.replace("bin/*|hooks/*.sh|rules/*.md|rules/*.rules)", "bin/*|hooks/*|rules/*.md|rules/*.rules)")

    old = '''        skills/*/SKILL.md)
            _skill_name=${_cdf_relative#skills/}
            _skill_name=${_skill_name%%/*}
            printf '%s/.agents/skills/%s/SKILL.md\\n' "$HOME" "$_skill_name"
            ;;'''
    new = '''        skills/*/SKILL.md|skills/*/agents/openai.yaml)
            # Plugin-only mode: skills are distributed via plugins, not symlinked to ~/.agents/skills.
            # This keeps the initial skill list small and avoids duplicate plugin/local skills.
            return 1
            ;;'''
    if old in text:
        text = text.replace(old, new)
    else:
        # Fallback: inject an early case before catch-all if not already present.
        needle = "        *)\n            return 1\n            ;;"
        insert = '''        skills/*/SKILL.md|skills/*/agents/openai.yaml)
            return 1
            ;;
'''
        if "skills/*/agents/openai.yaml" not in text and needle in text:
            text = text.replace(needle, insert + needle)

    if text != original:
        write_text(path, text)


def chmod_tree(root: Path) -> None:
    for pattern in ["codex/hooks/*.sh", "codex/bin/*"]:
        for p in root.glob(pattern):
            if p.is_file():
                p.chmod(p.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()
    root = Path(args.repo).resolve()
    generate_rules(root)
    skills = skill_directories(root / "codex" / "skills")
    add_openai_yaml(root, skills)
    patch_install_mapping(root)
    chmod_tree(root)
    print("applied Codex performance profile")
    print(f"rules checksum={sha256(read_text(root / 'codex/rules/RULES_BUNDLE.md'))[:16]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
