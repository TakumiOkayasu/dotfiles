#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import stat
from datetime import datetime, timezone
from pathlib import Path

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

GENERATED_RULES = {
    "RULES_CORE.md",
    "RULES_INDEX.md",
    "RULES_BUNDLE.md",
}

SUMMARY_BY_NAME = {
    "coding-conventions.md": "language-independent coding conventions, naming, testing, error handling, and logging",
    "implementation-policy.md": "dependency, library, DB, validation, logging, crypto, and SQL policy",
    "hallucination-prevention.md": "source verification and uncertainty handling policy",
    "hierarchical-architecture.md": "architecture invariants, dependency direction, composition, interfaces, and layer naming",
}

AGENTS_BLOCK_START = "<!-- codex-performance-profile:start -->"
AGENTS_BLOCK_END = "<!-- codex-performance-profile:end -->"

AGENTS_BLOCK = f"""{AGENTS_BLOCK_START}

## Performance profile

Keep the default context small and route details through skills.

Priority order:

1. User instruction
2. Project-local `AGENTS.md`
3. Active plugin rules and project rules
4. Active skill workflow
5. General best practice

Before mutating files or running mutating commands:

- Apply `RULES_CORE.md` and `RULES_INDEX.md` immediately.
- Ensure full rules were injected for implementation, review, test, refactor, fix, or any write operation.
- If `rules-guard.sh` blocks a tool, re-read rules instead of bypassing the guard.
- Do not overwrite user changes. Check `git status --short` when editing is involved.
- Never report unrun checks as passed. Report unverified risks explicitly.

Skill routing:

- Use `$feat` for feature implementation.
- Use `$fix` for bugs, failing tests, runtime errors, or unexpected behavior.
- Use `$review` or `$deep-review` for code review.
- Use `$rules-required` when the applicable rules are unclear.
- Use high-effort strategy skills (`premise-questioning`, `feature-pruning`, `deep-review`) only for high-risk tasks.

{AGENTS_BLOCK_END}
"""

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
# Markdown coding/design rules remain in *.md and are injected by rules-inject.sh.

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
    "consultation": "Compare 2-3 implementation plans and create handoff.",
    "codex-handoff": "Create compact Codex continuation handoff.",
    "implementation-router": "Classify implementation risk and route skills.",
    "plan": "Planning-only, no file changes.",
    "explain": "Code explanation only, no file changes.",
    "commit-msg": "Generate commit message proposal without committing.",
    "plugin-sync": "Sync codex assets into plugin bundle.",
    "plugin-install": "Install local plugin marketplace for this user.",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def backup_once(path: Path, suffix: str = ".pre-performance-profile.bak") -> None:
    if path.exists() and not path.with_name(path.name + suffix).exists():
        shutil.copy2(path, path.with_name(path.name + suffix))


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def list_markdown_rules(rules_dir: Path) -> list[Path]:
    if not rules_dir.exists():
        return []
    return sorted(
        p for p in rules_dir.glob("*.md")
        if p.name not in GENERATED_RULES and not p.name.endswith(".bak")
    )


def summarize_rule(path: Path) -> str:
    if path.name in SUMMARY_BY_NAME:
        return SUMMARY_BY_NAME[path.name]
    text = read_text(path)
    for line in text.splitlines():
        stripped = line.strip("# ").strip()
        if stripped and not stripped.startswith("---"):
            return stripped[:160]
    return "project rule"


def generate_rules(root: Path) -> None:
    rules_dir = root / "codex" / "rules"
    rules_dir.mkdir(parents=True, exist_ok=True)
    write_text(rules_dir / "RULES_CORE.md", RULES_CORE)
    write_text(rules_dir / "command-safety.rules", SAFETY_RULES)

    rule_files = list_markdown_rules(rules_dir)
    index_lines = [
        "# RULES_INDEX",
        "",
        "Use this index to choose which detailed rule files are relevant. `RULES_CORE.md` is always mandatory.",
        "",
        "| Rule file | Applies when |",
        "| --- | --- |",
    ]
    for path in rule_files:
        index_lines.append(f"| `{path.name}` | {summarize_rule(path)} |")
    index_lines.append("")
    write_text(rules_dir / "RULES_INDEX.md", "\n".join(index_lines))

    bundle_parts = [
        "# RULES_BUNDLE",
        "",
        f"Generated at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}",
        "",
        "This file is generated from `codex/rules/*.md`. Do not edit it directly.",
        "",
        "---",
        "",
        read_text(rules_dir / "RULES_CORE.md"),
    ]
    for path in rule_files:
        bundle_parts.extend(["\n---\n", f"# RULE FILE: {path.name}\n", read_text(path)])
    write_text(rules_dir / "RULES_BUNDLE.md", "\n".join(bundle_parts))


def patch_agents(root: Path) -> None:
    path = root / "codex" / "global_AGENTS.md"
    if not path.exists():
        write_text(path, "# Codex Global Instructions\n\n" + AGENTS_BLOCK)
        return
    text = read_text(path)
    backup_once(path)
    if AGENTS_BLOCK_START in text and AGENTS_BLOCK_END in text:
        text = re.sub(
            re.escape(AGENTS_BLOCK_START) + r".*?" + re.escape(AGENTS_BLOCK_END),
            AGENTS_BLOCK.strip(),
            text,
            flags=re.S,
        )
    else:
        text = text.rstrip() + "\n\n" + AGENTS_BLOCK
    write_text(path, text)


def skill_name(skill_dir: Path) -> str:
    return skill_dir.name


def add_openai_yaml(root: Path) -> None:
    skills_dir = root / "codex" / "skills"
    if not skills_dir.exists():
        return
    for skill in sorted(p for p in skills_dir.iterdir() if p.is_dir() and (p / "SKILL.md").exists()):
        name = skill_name(skill)
        implicit = "true" if name in CORE_SKILLS else "false"
        short = CORE_SHORT.get(name, "Optional workflow skill. Explicit invocation recommended.")
        display = name.replace("-", " ").title()
        prompt = f"Use ${name} for this task."
        write_text(skill / "agents" / "openai.yaml", OPENAI_YAML_TEMPLATE.format(
            display=display,
            short=short.replace('"', "'"),
            prompt=prompt.replace('"', "'"),
            implicit=implicit,
        ))


def write_skill_policy(root: Path) -> None:
    skills_dir = root / "codex" / "skills"
    skills_dir.mkdir(parents=True, exist_ok=True)
    all_skills = sorted(p.name for p in skills_dir.iterdir() if p.is_dir() and (p / "SKILL.md").exists())
    optional = [s for s in all_skills if s not in CORE_SKILLS]
    lines = [
        "# Codex Skill Policy",
        "",
        "Core skills are packaged in `dotfile-work-codex` and may be implicitly invoked.",
        "Optional skills are packaged in `dotfile-work-codex-extra` and should usually be explicitly invoked.",
        "",
        "## Core skills",
        "",
    ]
    lines += [f"- `{s}`" for s in sorted(CORE_SKILLS & set(all_skills))]
    lines += ["", "## Optional skills", ""]
    lines += [f"- `{s}`" for s in optional]
    lines.append("")
    write_text(skills_dir / "SKILL_POLICY.md", "\n".join(lines))


def patch_install_mapping(root: Path) -> None:
    path = root / "install.sh"
    if not path.exists():
        return
    text = read_text(path)
    original = text
    backup_once(path)

    # Include official *.rules in Codex install mapping, but do not symlink codex/skills into ~/.agents by default.
    text = text.replace("bin/*.sh|hooks/*.sh|prompts/commands/*.md|rules/*.md)", "bin/*|hooks/*.sh|rules/*.md|rules/*.rules)")
    text = text.replace("bin/*|hooks/*.sh|rules/*.md)", "bin/*|hooks/*.sh|rules/*.md|rules/*.rules)")
    text = text.replace("bin/*.sh|hooks/*.sh|rules/*.md)", "bin/*|hooks/*.sh|rules/*.md|rules/*.rules)")

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
    for pattern in ["codex/hooks/*.sh", "codex/bin/*", "scripts/*.py"]:
        for p in root.glob(pattern):
            if p.is_file():
                p.chmod(p.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()
    root = Path(args.repo).resolve()
    generate_rules(root)
    patch_agents(root)
    add_openai_yaml(root)
    write_skill_policy(root)
    patch_install_mapping(root)
    chmod_tree(root)
    print("applied Codex performance profile")
    print(f"rules checksum={sha256(read_text(root / 'codex/rules/RULES_BUNDLE.md'))[:16]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
