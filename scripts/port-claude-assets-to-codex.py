#!/usr/bin/env python3
"""Port Claude skills, commands, and rules into Codex layout.

This script intentionally runs inside the user's dotfile-work checkout.
It reads every tracked or untracked `claude/skills/*/SKILL.md` and
`claude/rules/*.md`, plus the explicitly mapped `claude/commands/*.md`,
converts Claude-specific paths/phrasing to Codex conventions, and writes
the result under `codex/`.
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import json
from pathlib import Path
import re
import shutil

MANAGED_MARKER = "codex-port: managed"
RULE_BUNDLE_NAME = "RULES_BUNDLE.md"
RULE_INDEX_NAME = "RULES_INDEX.md"
ASSET_MANIFEST_PATH = Path(__file__).with_name("claude-command-map.json")
MANAGED_SOURCE_PATTERN = re.compile(
    rf"<!-- {re.escape(MANAGED_MARKER)}; source=([^;]+); "
    r"generated-by=scripts/port-claude-assets-to-codex\.py -->"
)


def load_asset_manifest() -> tuple[dict[str, str], dict[str, Path], frozenset[str]]:
    data = json.loads(ASSET_MANIFEST_PATH.read_text(encoding="utf-8"))
    commands = data.get("commands")
    allowed_skill_files = data.get("allowed_skill_files")
    if not isinstance(commands, list) or not isinstance(allowed_skill_files, list):
        raise ValueError(f"invalid asset manifest: {ASSET_MANIFEST_PATH}")

    destinations: dict[str, str] = {}
    references: dict[str, Path] = {}
    used_skills: set[str] = set()
    for entry in commands:
        if not isinstance(entry, dict):
            raise ValueError(f"invalid command entry: {entry!r}")
        source = Path(str(entry.get("source", "")))
        skill = str(entry.get("skill", ""))
        reference = Path(str(entry.get("reference", "")))
        if (
            len(source.parts) != 3
            or source.parts[:2] != ("claude", "commands")
            or source.suffix != ".md"
            or not re.fullmatch(r"[a-z0-9-]+", skill)
            or reference.is_absolute()
            or ".." in reference.parts
            or reference.name != "claude-command.md"
        ):
            raise ValueError(f"invalid command mapping: {entry!r}")
        if source.stem in destinations or skill in used_skills:
            raise ValueError(f"duplicate command mapping: {entry!r}")
        destinations[source.stem] = skill
        references[source.stem] = reference
        used_skills.add(skill)

    allowed = frozenset(str(path) for path in allowed_skill_files)
    if not allowed or any(Path(path).is_absolute() or ".." in Path(path).parts for path in allowed):
        raise ValueError(f"invalid allowed_skill_files: {allowed_skill_files!r}")
    return destinations, references, allowed


COMMAND_DESTINATIONS, COMMAND_REFERENCES, ALLOWED_SKILL_FILES = load_asset_manifest()


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
    parser.add_argument(
        "--prune",
        action="store_true",
        help="remove stale files with an exact managed-source marker and expected destination",
    )
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
    # Keep source provenance without adding an unsupported skill frontmatter key.
    fm = re.sub(
        r"^codex_port_source:",
        "# codex_port_source:",
        fm,
        flags=re.MULTILINE,
    )
    if "codex_port_source:" not in fm:
        source_str = str(source).replace("\\", "/")
        fm = fm.replace("---\n", f"---\n# codex_port_source: {source_str}\n", 1)
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
    ("qa-nightmare", "qa_nightmare"),
    ("global_CLAUDE.md", "global_AGENTS.md"),
    ("CLAUDE.md", "AGENTS.md"),
    ("Claude Code", "Codex"),
    ("Claude", "Codex"),
    ("claude", "codex"),
)

SKILL_RUNTIME_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    (
        "呼び出し側はレポートから自己申告部分を抽出し、`tool_uses` / `duration_ms` を Agent tool の usage メタから取得して評価軸表を埋める。",
        "呼び出し側はレポートから自己申告部分を抽出し、観測可能な tool call 数と経過時間を評価軸表へ記録する。",
    ),
    (
        "Task tool の戻り値に付く usage メタの `tool_uses` をそのまま使う。Read / Grep も含める、除外しない",
        "親が観測できる tool call 数を記録する。取得できない場合は未計測とする",
    ),
    (
        "Task tool の usage メタの `duration_ms`",
        "親が dispatch の開始から終了まで計測した経過時間。取得できない場合は未計測とする",
    ),
    ("実行者の duration_ms", "親が計測した経過時間"),
    ("Agent tool の usage メタから取得して", "親が観測できる範囲で記録して"),
    ("`tool_uses` / `duration_ms`", "`tool call 数` / `経過時間`"),
    ("tool_uses", "tool call 数"),
    ("duration_ms", "経過時間"),
    ("複数 Agent 呼び出し", "複数の `spawn_agent` 呼び出し"),
    ("Task / Agent tool", "`spawn_agent`"),
    ("Task tool", "`spawn_agent`"),
    ("Agent tool", "`spawn_agent`"),
    ("subagent_type:", "agent_type:"),
    ("$ARGUMENTS", "ユーザー指定の保存先"),
    (
        "上位 model に昇格して再 dispatch (Haiku→Sonnet→Opus)",
        "reasoning_effort を1段階上げて再 dispatch",
    ),
    ("Opus でも解けない場合", "最大の reasoning_effort でも解けない場合"),
    (
        "driver は最強 model (Opus)、worker は task 複雑度に応じて Haiku/Sonnet",
        "driver は高い reasoning_effort、worker は task 複雑度に応じた reasoning_effort",
    ),
    ("Haiku/Codex worker", "低い reasoning_effort の worker"),
    ("Sonnet に上げる", "reasoning_effort を上げる"),
)

UNSUPPORTED_SKILL_FRAGMENTS = tuple(old for old, _new in SKILL_RUNTIME_REPLACEMENTS)
COMMAND_RUNTIME_REPLACEMENTS = tuple(
    (old, "ユーザー指定の対象" if old == "$ARGUMENTS" else new)
    for old, new in SKILL_RUNTIME_REPLACEMENTS
)


def replace_runtime_fragments(body: str, *, source: Path, kind: str) -> str:
    out = body
    for old, new in COMMON_REPLACEMENTS:
        out = out.replace(old, new)
    out = out.replace("[[semantic-generation]]", "`$semantic-generation`")
    out = out.replace("[[referent-before-label]]", "`referent-before-label`")
    out = re.sub(r"\[\[([^\]]+)\]\]", r"`\1`", out)
    if kind in {"skill", "command"}:
        replacements = (
            SKILL_RUNTIME_REPLACEMENTS if kind == "skill" else COMMAND_RUNTIME_REPLACEMENTS
        )
        for old, new in replacements:
            out = out.replace(old, new)

        remaining = [fragment for fragment in UNSUPPORTED_SKILL_FRAGMENTS if fragment in out]
        if remaining:
            raise ValueError(f"{source}: unsupported Codex runtime fragments: {remaining}")
    return out


def replace_codex_paths(body: str) -> str:
    out = body
    out = re.sub(
        r"@\s+`?\$(?:\{HOME\}|HOME)/\.agents/skills/([^/]+)/SKILL\.md`?",
        r"`$\1`",
        out,
    )
    out = re.sub(
        r"`\$(?:\{HOME\}|HOME)/\.agents/skills/([^/]+)/SKILL\.md`",
        r"`$\1`",
        out,
    )
    out = re.sub(
        r"@\s+`?\$(?:\{HOME\}|HOME)/\.codex/AGENTS\.md`?",
        r"`${HOME}/.codex/AGENTS.md` を読む",
        out,
    )
    out = out.replace(
        "`${HOME}/.codex/rules/*` は @import 済みで既に context にある",
        "`${HOME}/.codex/rules/*` は rules-inject hook で既に context に注入済みである",
    )
    out = out.replace(
        "`${HOME}/.codex/rules/*` は @import 済みで context にある",
        "`${HOME}/.codex/rules/*` は rules-inject hook で context に注入済みである",
    )
    out = out.replace(
        "`code-reviewer` は読み取り専用・sonnet モデルで安定した出力形式を持つため、",
        "`code-reviewer` は読み取り専用で安定した出力形式を持つため、",
    )
    out = out.replace(
        "`code-reviewer` は読み取り専用・sonnet モデルで安定している。",
        "`code-reviewer` は読み取り専用で安定している。",
    )
    return out


def replace_command_invocations(body: str) -> str:
    out = re.sub(
        r"`/([a-zA-Z0-9_.-]+)`",
        lambda match: f"`@{COMMAND_DESTINATIONS.get(match.group(1), match.group(1))}`",
        body,
    )
    return re.sub(
        r"(?<![\w`])/(feat|fix|review|deep-review|commit|commit-msg|test|refactor|plan|explain)(?![\w`:-])",
        lambda match: f"@{COMMAND_DESTINATIONS.get(match.group(1), match.group(1))}",
        out,
    )


def add_portability_notes(body: str, *, source: Path, kind: str) -> str:
    out = body
    source_str = str(source).replace("\\", "/")
    note = f"""\n<!-- {MANAGED_MARKER}; source={source_str}; generated-by=scripts/port-claude-assets-to-codex.py -->\n\n## Codex portability notes\n\n- This file was ported from `{source_str}`.\n- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${{HOME}}/.agents/skills` in plugin-only mode.\n- Global and project rules live under `${{HOME}}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.\n- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.\n- Subagent usage must follow `${{HOME}}/.codex/SUBAGENTS.md` and the current Codex tool contract.\n"""
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


def transform_body(body: str, *, source: Path, kind: str) -> str:
    out = replace_runtime_fragments(body, source=source, kind=kind)
    out = replace_codex_paths(out)
    out = replace_command_invocations(out)
    return add_portability_notes(out, source=source, kind=kind)


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
    text = text.rstrip() + "\n"
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


def iter_command_sources(repo: Path) -> list[Path]:
    return sorted((repo / "claude" / "commands").glob("*.md"))


def validate_command_manifest(command_sources: list[Path]) -> None:
    command_names = {source.stem for source in command_sources}
    unknown_commands = [
        source.stem
        for source in command_sources
        if source.stem not in COMMAND_DESTINATIONS
    ]
    if unknown_commands:
        raise ValueError(f"unknown Claude command: {', '.join(unknown_commands)}")
    missing_commands = sorted(set(COMMAND_DESTINATIONS) - command_names)
    if missing_commands:
        raise ValueError(f"missing Claude command: {', '.join(missing_commands)}")


def validate_skill_resources(repo: Path) -> None:
    unexpected_skill_files = [
        f"{source.parent.name}/{path.relative_to(source.parent).as_posix()}"
        for source in iter_skill_sources(repo)
        for path in source.parent.rglob("*")
        if path.is_file()
        and path.relative_to(source.parent).as_posix() not in ALLOWED_SKILL_FILES
    ]
    if unexpected_skill_files:
        raise ValueError(
            "unsupported Claude skill resource: " + ", ".join(sorted(unexpected_skill_files))
        )


def validate_transformability(repo: Path, command_sources: list[Path]) -> None:
    for source in iter_skill_sources(repo):
        transform_text(
            source.read_text(encoding="utf-8"),
            source=source.relative_to(repo),
            kind="skill",
        )
    for source in iter_rule_sources(repo):
        transform_text(
            source.read_text(encoding="utf-8"),
            source=source.relative_to(repo),
            kind="rule",
        )
    for source in command_sources:
        skill_name = COMMAND_DESTINATIONS[source.stem]
        native_skill = repo / "codex" / "skills" / skill_name / "SKILL.md"
        if not native_skill.is_file():
            raise ValueError(
                f"{source.relative_to(repo)}: missing Codex-native entrypoint "
                f"codex/skills/{skill_name}/SKILL.md"
            )
        transform_text(
            source.read_text(encoding="utf-8"),
            source=source.relative_to(repo),
            kind="command",
        )


def validate_sources(repo: Path) -> None:
    command_sources = iter_command_sources(repo)
    validate_command_manifest(command_sources)
    validate_skill_resources(repo)
    validate_transformability(repo, command_sources)


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


def port_commands(repo: Path, args: argparse.Namespace) -> list[PortedFile]:
    result: list[PortedFile] = []
    for source in iter_command_sources(repo):
        skill_name = COMMAND_DESTINATIONS[source.stem]
        dest = repo / "codex" / "skills" / skill_name / COMMAND_REFERENCES[source.stem]
        text = source.read_text(encoding="utf-8")
        out = transform_text(text, source=source.relative_to(repo), kind="command")
        changed, backed_up = write_file(dest, out, args=args)
        result.append(PortedFile(source, dest, "command", changed, backed_up))
    return result


def managed_source(dest: Path) -> Path | None:
    if not dest.is_file():
        return None
    match = MANAGED_SOURCE_PATTERN.search(dest.read_text(encoding="utf-8"))
    if match is None:
        return None
    source = Path(match.group(1))
    if source.is_absolute() or ".." in source.parts:
        return None
    return source


def expected_managed_destination(repo: Path, source: Path) -> Path | None:
    parts = source.parts
    if len(parts) == 3 and parts[:2] == ("claude", "rules") and source.suffix == ".md":
        return repo / "codex" / "rules" / source.name
    if (
        len(parts) == 4
        and parts[:2] == ("claude", "skills")
        and parts[3] == "SKILL.md"
    ):
        return repo / "codex" / "skills" / parts[2] / "SKILL.md"
    if len(parts) == 3 and parts[:2] == ("claude", "commands") and source.suffix == ".md":
        skill_name = COMMAND_DESTINATIONS.get(source.stem)
        if skill_name is not None:
            return repo / "codex" / "skills" / skill_name / COMMAND_REFERENCES[source.stem]
    return None


def prune_stale_outputs(repo: Path, args: argparse.Namespace) -> list[Path]:
    candidates = list((repo / "codex" / "rules").glob("*.md"))
    candidates.extend((repo / "codex" / "skills").glob("*/SKILL.md"))
    candidates.extend(
        repo / "codex" / "skills" / skill_name / COMMAND_REFERENCES[command_name]
        for command_name, skill_name in COMMAND_DESTINATIONS.items()
    )

    pruned: list[Path] = []
    for dest in sorted(set(candidates)):
        source = managed_source(dest)
        if source is None:
            continue
        if expected_managed_destination(repo, source) != dest:
            continue
        if (repo / source).exists():
            continue
        pruned.append(dest)
        print(f"PRUNE stale managed file: {dest.relative_to(repo)}")
        if not args.dry_run:
            dest.unlink()
    return pruned


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
        parts.extend(["---", "", f"## Source: `{rel}`", "", rule.read_text(encoding="utf-8").rstrip(), ""])
    content = "\n".join(parts)
    if not args.dry_run:
        rules_dir.mkdir(parents=True, exist_ok=True)
        (rules_dir / RULE_BUNDLE_NAME).write_text(content.rstrip() + "\n", encoding="utf-8")


def generate_report(
    repo: Path,
    ported: list[PortedFile],
    pruned: list[Path],
    args: argparse.Namespace,
) -> None:
    report = repo / "codex" / "skills" / "CLAUDE_PORT_REPORT.md"
    lines = [
        "# Claude to Codex Port Report",
        "",
        "Generated by `scripts/port-claude-assets-to-codex.py`.",
        "",
        "## Summary",
        "",
        f"- Skills: {sum(1 for p in ported if p.kind == 'skill')}",
        f"- Commands: {sum(1 for p in ported if p.kind == 'command')}",
        f"- Rules: {sum(1 for p in ported if p.kind == 'rule')}",
        f"- Changed: {sum(1 for p in ported if p.changed)}",
        f"- Backups: {sum(1 for p in ported if p.backed_up)}",
        f"- Pruned: {len(pruned)}",
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
    if pruned:
        lines += ["", "## Pruned files", ""]
        lines.extend(f"- `{path.relative_to(repo).as_posix()}`" for path in pruned)
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

    validate_sources(repo)

    ported: list[PortedFile] = []
    ported.extend(port_skills(repo, args))
    ported.extend(port_commands(repo, args))
    ported.extend(port_rules(repo, args))
    pruned = prune_stale_outputs(repo, args) if args.prune else []
    generate_rule_index(repo, args)
    generate_rule_bundle(repo, args)
    generate_report(repo, ported, pruned, args)

    print("Claude -> Codex port complete")
    print(f"skills: {sum(1 for p in ported if p.kind == 'skill')}")
    print(f"commands: {sum(1 for p in ported if p.kind == 'command')}")
    print(f"rules:  {sum(1 for p in ported if p.kind == 'rule')}")
    print(f"changed:{sum(1 for p in ported if p.changed)}")
    print(f"pruned: {len(pruned)}")
    print("report: codex/skills/CLAUDE_PORT_REPORT.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
