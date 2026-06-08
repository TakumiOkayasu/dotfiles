#!/usr/bin/env python3
"""Port Claude skills/rules into Codex layout.

This script intentionally runs inside the user's dotfile-work checkout.
It reads every tracked or untracked `claude/skills/*/SKILL.md` and
`claude/rules/*.md`, converts Claude-specific paths/phrasing to Codex
conventions, and writes the result under `codex/`.
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import os
from pathlib import Path
import re
import shutil
import sys
from typing import Iterable

MANAGED_MARKER = "codex-port: managed"
RULE_BUNDLE_NAME = "RULES_BUNDLE.md"
RULE_INDEX_NAME = "RULES_INDEX.md"


@dataclasses.dataclass(frozen=True)
class PortedFile:
    source: Path
    dest: Path
    kind: str
    changed: bool
    backed_up: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Port claude/ skills and rules into codex/.")
    parser.add_argument("--repo", default=".", help="dotfile-work repository root")
    parser.add_argument("--overwrite", action="store_true", help="overwrite existing codex files")
    parser.add_argument("--skip-existing", action="store_true", help="skip files that already exist")
    parser.add_argument("--dry-run", action="store_true", help="print planned changes without writing")
    parser.add_argument("--no-backup", action="store_true", help="do not create .pre-claude-port.bak backups")
    return parser.parse_args()


def split_frontmatter(text: str) -> tuple[str | None, str]:
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return None, text
    return text[: end + 5], text[end + 5 :]


def transform_frontmatter(frontmatter: str | None, source: Path) -> str | None:
    if frontmatter is None:
        return None
    fm = frontmatter
    # Keep the skill name stable. Adjust only Claude-specific wording/paths.
    for old, new in COMMON_REPLACEMENTS:
        fm = fm.replace(old, new)
    # Add source metadata as a comment-like yaml field only if absent.
    if "codex_port_source:" not in fm:
        source_str = str(source).replace("\\", "/")
        fm = fm.replace("---\n", f"---\ncodex_port_source: {source_str}\n", 1)
    return fm


COMMON_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    ("${HOME}/.claude/skills", "${HOME}/.agents/skills"),
    ("${HOME}/.claude/rules", "${HOME}/.codex/rules"),
    ("${HOME}/.claude/commands", "${HOME}/.agents/skills"),
    ("${HOME}/.claude/hooks", "${HOME}/.codex/hooks"),
    ("${HOME}/.claude/CLAUDE.md", "${HOME}/.codex/AGENTS.md"),
    ("${HOME}/.claude", "${HOME}/.codex"),
    ("claude/skills", "codex/skills"),
    ("claude/rules", "codex/rules"),
    ("claude/commands", "codex/skills"),
    ("claude/hooks", "codex/hooks"),
    ("global_CLAUDE.md", "global_AGENTS.md"),
    ("CLAUDE.md", "AGENTS.md"),
    ("Claude Code", "Codex"),
    ("Claude", "Codex"),
    ("claude", "codex"),
)


def transform_body(body: str, *, source: Path, kind: str) -> str:
    out = body
    for old, new in COMMON_REPLACEMENTS:
        out = out.replace(old, new)

    # Convert common Claude slash command references to Codex plugin/local skill invocations.
    out = re.sub(r"`/([a-zA-Z0-9_.-]+)`", r"`@\1`", out)
    out = re.sub(r"(?<![\w`])/(feat|fix|review|deep-review|commit|commit-msg|test|refactor|plan|explain)(?![\w`:-])", r"@\1", out)

    source_str = str(source).replace("\\", "/")
    note = f"""\n<!-- {MANAGED_MARKER}; source={source_str}; generated-by=scripts/port-claude-assets-to-codex.py -->\n\n## Codex portability notes\n\n- This file was ported from `{source_str}`.\n- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.\n- Global and project rules live under `${HOME}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.\n- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.\n- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.\n"""
    if MANAGED_MARKER not in out:
        # Insert after first H1 when possible; otherwise prepend after frontmatter.
        match = re.search(r"(^# .+?\n)", out, re.MULTILINE)
        if match:
            insert_at = match.end()
            out = out[:insert_at] + note + out[insert_at:]
        else:
            out = note + "\n" + out

    if kind == "rule" and "## Codex rule loading" not in out:
        out += """\n\n## Codex rule loading\n\nThis rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.\n"""

    return out


def transform_text(text: str, *, source: Path, kind: str) -> str:
    frontmatter, body = split_frontmatter(text)
    fm = transform_frontmatter(frontmatter, source)
    new_body = transform_body(body, source=source, kind=kind)
    return (fm or "") + new_body


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def backup_existing(dest: Path) -> bool:
    if not dest.exists() and not dest.is_symlink():
        return False
    backup = dest.with_name(dest.name + ".pre-claude-port.bak")
    if backup.exists():
        return False
    shutil.copy2(dest, backup)
    return True


def write_file(dest: Path, text: str, *, args: argparse.Namespace) -> tuple[bool, bool]:
    existing = None
    if dest.exists():
        existing = dest.read_text(encoding="utf-8")
        if existing == text:
            return False, False
        if args.skip_existing:
            return False, False
        if not args.overwrite and MANAGED_MARKER not in existing:
            print(f"SKIP existing unmanaged file: {dest}")
            return False, False

    backed_up = False
    if not args.dry_run:
        dest.parent.mkdir(parents=True, exist_ok=True)
        if existing is not None and not args.no_backup:
            backed_up = backup_existing(dest)
        dest.write_text(text, encoding="utf-8")
    return True, backed_up


def first_heading(text: str) -> str:
    for line in text.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return "(no title)"


def first_description(text: str) -> str:
    match = re.search(r"^description:\s*(.+)$", text, re.MULTILINE)
    if match:
        return match.group(1).strip().strip('"')
    for line in text.splitlines():
        if line.strip() and not line.startswith("---") and not line.startswith("#") and not line.startswith("<!--"):
            return line.strip()[:160]
    return ""


def iter_skill_sources(repo: Path) -> list[Path]:
    return sorted((repo / "claude" / "skills").glob("*/SKILL.md"))


def iter_rule_sources(repo: Path) -> list[Path]:
    return sorted((repo / "claude" / "rules").glob("*.md"))


def port_skills(repo: Path, args: argparse.Namespace) -> list[PortedFile]:
    result: list[PortedFile] = []
    for source in iter_skill_sources(repo):
        skill_name = source.parent.name
        dest = repo / "codex" / "skills" / skill_name / "SKILL.md"
        text = source.read_text(encoding="utf-8")
        out = transform_text(text, source=source.relative_to(repo), kind="skill")
        changed, backed_up = write_file(dest, out, args=args)
        result.append(PortedFile(source, dest, "skill", changed, backed_up))
    return result


def port_rules(repo: Path, args: argparse.Namespace) -> list[PortedFile]:
    result: list[PortedFile] = []
    for source in iter_rule_sources(repo):
        dest = repo / "codex" / "rules" / source.name
        text = source.read_text(encoding="utf-8")
        out = transform_text(text, source=source.relative_to(repo), kind="rule")
        changed, backed_up = write_file(dest, out, args=args)
        result.append(PortedFile(source, dest, "rule", changed, backed_up))
    return result


def generate_rule_index(repo: Path, args: argparse.Namespace) -> None:
    rules_dir = repo / "codex" / "rules"
    rules = [p for p in sorted(rules_dir.glob("*.md")) if p.name not in {RULE_INDEX_NAME, RULE_BUNDLE_NAME}]
    lines = [
        "# Codex Rules Index",
        "",
        "このファイルは `scripts/port-claude-assets-to-codex.py` により生成される rules index です。",
        "Codex は作業前に該当 rule を読む必要があります。hook により full content が注入された場合は、それを読了済みとして扱います。",
        "",
        "| Rule | Title | Description |",
        "| --- | --- | --- |",
    ]
    for rule in rules:
        text = rule.read_text(encoding="utf-8")
        rel = rule.relative_to(repo).as_posix()
        lines.append(f"| `{rel}` | {first_heading(text)} | {first_description(text)} |")
    lines.append("")
    content = "\n".join(lines)
    if not args.dry_run:
        rules_dir.mkdir(parents=True, exist_ok=True)
        (rules_dir / RULE_INDEX_NAME).write_text(content, encoding="utf-8")


def generate_rule_bundle(repo: Path, args: argparse.Namespace) -> None:
    rules_dir = repo / "codex" / "rules"
    rules = [p for p in sorted(rules_dir.glob("*.md")) if p.name not in {RULE_INDEX_NAME, RULE_BUNDLE_NAME}]
    parts = [
        "# Codex Rules Bundle",
        "",
        "このファイルは hook/context injection 用の連結 rules bundle です。直接編集せず、元 rule を編集して再生成してください。",
        "",
    ]
    for rule in rules:
        rel = rule.relative_to(repo).as_posix()
        parts.append(f"\n---\n\n## Source: `{rel}`\n\n")
        parts.append(rule.read_text(encoding="utf-8"))
        parts.append("\n")
    content = "".join(parts)
    if not args.dry_run:
        rules_dir.mkdir(parents=True, exist_ok=True)
        (rules_dir / RULE_BUNDLE_NAME).write_text(content, encoding="utf-8")


def generate_report(repo: Path, ported: list[PortedFile], args: argparse.Namespace) -> None:
    report = repo / "codex" / "skills" / "CLAUDE_PORT_REPORT.md"
    lines = [
        "# Claude to Codex Port Report",
        "",
        "Generated by `scripts/port-claude-assets-to-codex.py`.",
        "",
        "## Summary",
        "",
        f"- Skills: {sum(1 for p in ported if p.kind == 'skill')}",
        f"- Rules: {sum(1 for p in ported if p.kind == 'rule')}",
        f"- Changed: {sum(1 for p in ported if p.changed)}",
        f"- Backups: {sum(1 for p in ported if p.backed_up)}",
        "",
        "## Files",
        "",
        "| Kind | Source | Destination | Changed | Backup |",
        "| --- | --- | --- | --- | --- |",
    ]
    for p in ported:
        lines.append(
            f"| {p.kind} | `{p.source.relative_to(repo).as_posix()}` | `{p.dest.relative_to(repo).as_posix()}` | {p.changed} | {p.backed_up} |"
        )
    lines += [
        "",
        "## Follow-up checks",
        "",
        "1. `git diff -- codex/skills codex/rules` を確認する。",
        "2. `grep -R \"~/.claude\\|CLAUDE.md\\|Claude Code\" codex/skills codex/rules` で残存参照を確認する。",
        "3. `./install.sh -n` で Codex install path を確認する。",
        "4. Codex で `/skills` を確認し、移植 skill が `~/.agents/skills` から認識されるか確認する。",
    ]
    if not args.dry_run:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    repo = Path(args.repo).resolve()
    if not (repo / "claude" / "skills").is_dir():
        print(f"ERROR: missing claude/skills under {repo}", file=sys.stderr)
        return 2
    if not (repo / "claude" / "rules").is_dir():
        print(f"ERROR: missing claude/rules under {repo}", file=sys.stderr)
        return 2

    ported: list[PortedFile] = []
    ported.extend(port_skills(repo, args))
    ported.extend(port_rules(repo, args))
    generate_rule_index(repo, args)
    generate_rule_bundle(repo, args)
    generate_report(repo, ported, args)

    print("Claude -> Codex port complete")
    print(f"skills: {sum(1 for p in ported if p.kind == 'skill')}")
    print(f"rules:  {sum(1 for p in ported if p.kind == 'rule')}")
    print(f"changed:{sum(1 for p in ported if p.changed)}")
    print("report: codex/skills/CLAUDE_PORT_REPORT.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
