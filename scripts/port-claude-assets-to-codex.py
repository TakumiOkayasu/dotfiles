#!/usr/bin/env python3
"""Port shared skills, commands, and rules into Codex layout.

This script intentionally runs inside the user's dotfile-work checkout.
It reads every tracked or untracked `common/skills/*/SKILL.md` and
`common/rules/*.md`, plus the explicitly mapped `common/commands/*.md`,
converts Claude-specific paths/phrasing to Codex conventions, and writes
the result under `codex/`.
"""

from __future__ import annotations

import argparse
import dataclasses
import enum
import hashlib
from pathlib import Path
import re
import shutil
import sys

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

MANAGED_MARKER = "codex-port: managed"
SHARED_SKILLS_DIR = Path("common/skills")
SHARED_RULES_DIR = Path("common/rules")
SHARED_COMMANDS_DIR = Path("common/commands")
TDD_SKILL_SOURCE = SHARED_SKILLS_DIR / "tdd/SKILL.md"
CLAUDE_ONLY_SKILL_FRONTMATTER_KEYS = (
    "argument-hint",
    "disable-model-invocation",
    "effort",
)
QA_CONTINUATION_START = "<!-- qa-continuation:start -->"
QA_CONTINUATION_END = "<!-- qa-continuation:end -->"
CODEX_QA_CONTINUATION_OVERLAY = (
    "長大出力で継続が必要な場合、Codex parent は完全性索引、`snapshot_digest`、未返却rankを"
    "持つcompact continuation_ledgerを受け取る。\n"
    "未返却rankについてのみ、各代表ケースを"
    "再構成できるredacted事実 (事前条件/操作/期待結果/観測点/根拠/score) を保持し、"
    "表示済みrank本文を含めない。\n"
    "ledger全体を含む初回出力のUTF-8 byte数から保守的な"
    "`ledger_upper_bound_tokens`を算出し、埋込み後の"
    "再直列化が固定点に達して`ledger_upper_bound_tokens <= output_reserve_tokens`を満たす"
    "ことを検証する。\n"
    "超過時は対象絞り込みを要求して停止する。\n"
    "digest検証後、followup_taskでledger digestとrequested_rankだけを指定する。\n"
    "既存contextを使い、snapshotを再送しない。\n"
    "未返却 S を除外しない。"
)
CODEX_QA_DISPATCH_INSTRUCTION = "`spawn_agent` で `agent_type: qa_nightmare` を起動する。"
CODEX_QA_FAIL_CLOSED_INSTRUCTION = (
    "現行Codex custom-agentには構造的なempty tool surfaceがない。\n"
    "`sandbox_mode = \"read-only\"` はtoolを非公開化しないため、実運用では "
    "`agent_type: qa_nightmare` をdispatchしない。\n"
    "悪夢テストケース生成は未実行としてユーザーへ明示する。\n"
    "将来、実行surfaceが全toolを構造的に除外できることを"
    "一次情報と実tool eventで確認できた場合だけ、以下のpreflightとdispatchを有効化する。"
    "\n\n"
)
CODEX_QA_SURFACE_REPLACEMENTS = (
    (
        "| 機能単位 (画面 / API / エンドポイント / ジョブ) | ユーザー登録画面、決済 API、夜間バッチ | qa_nightmare subagent を起動する |",
        "| 機能単位 (画面 / API / エンドポイント / ジョブ) | ユーザー登録画面、決済 API、夜間バッチ | 現行Codex: 未実行を明示 (dispatch禁止) |",
    ),
    (
        "機能単位と判定したら、テストリスト作成に進む前に qa_nightmare subagent を起動して悪夢テストケースを先に列挙する。",
        "機能単位と判定しても、現行Codexではqa_nightmareをdispatchせず、悪夢テストケース生成が未実行であることを先に明示する。",
    ),
    (
        "機能単位の場合は `qa_nightmare` subagent の出力を反映する。",
        "機能単位の場合はqa_nightmare未実行を明示し、通常TDD候補を親が作る。\n"
        "将来有効化後だけ `qa_nightmare` subagent の出力を反映する。",
    ),
    ("### qa_nightmare 起動", "### qa_nightmare の将来有効化仕様"),
    ("### 結果の扱い", "### 将来有効化時の結果の扱い"),
)
ASSET_MANIFEST_PATH = Path(__file__).with_name("claude-command-map.json")
MANAGED_SOURCE_PATTERN = re.compile(
    rf"<!-- {re.escape(MANAGED_MARKER)}; source=([^;]+); "
    r"generated-by=scripts/port-claude-assets-to-codex\.py -->"
)


ASSET_MANIFEST = load_asset_manifest(ASSET_MANIFEST_PATH)
COMMAND_DESTINATIONS = {
    mapping.source.stem: mapping.skill for mapping in ASSET_MANIFEST.commands
}
COMMAND_REFERENCES = {
    mapping.source.stem: mapping.reference for mapping in ASSET_MANIFEST.commands
}
ALLOWED_SKILL_FILES = ASSET_MANIFEST.allowed_skill_files


class ArtifactRole(enum.Enum):
    GENERIC = "generic"
    TDD_SKILL = "tdd_skill"


def classify_artifact_role(source: Path, *, kind: str) -> ArtifactRole:
    if kind == "skill" and source == TDD_SKILL_SOURCE:
        return ArtifactRole.TDD_SKILL
    return ArtifactRole.GENERIC


def replace_marked_section(body: str, start: str, end: str, overlay: str) -> str:
    start_at = body.find(start)
    end_at = body.find(end)
    if start_at < 0 or end_at < 0 or end_at <= start_at:
        raise ValueError(f"missing or invalid marker section: {start} ... {end}")
    content_start = start_at + len(start)
    return body[:content_start] + "\n" + overlay + "\n" + body[end_at:]


@dataclasses.dataclass(frozen=True)
class PortedFile:
    source: Path
    dest: Path
    kind: str
    role: ArtifactRole
    changed: bool
    backed_up: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Port shared common/ assets into the Codex layout."
    )
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


def transform_frontmatter(
    frontmatter: str | None, source: Path, *, kind: str
) -> str | None:
    if frontmatter is None:
        return None
    fm = frontmatter
    # Keep the skill name stable. Adjust only Claude-specific wording/paths.
    for old, new in COMMON_REPLACEMENTS:
        fm = fm.replace(old, new)
    if kind == "skill":
        keys = "|".join(re.escape(key) for key in CLAUDE_ONLY_SKILL_FRONTMATTER_KEYS)
        fm = re.sub(rf"^(?:{keys}):[^\n]*(?:\n|$)", "", fm, flags=re.MULTILINE)
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
    if kind in {"skill", "skill_resource", "command"}:
        replacements = (
            COMMAND_RUNTIME_REPLACEMENTS
            if kind == "command"
            else SKILL_RUNTIME_REPLACEMENTS
        )
        for old, new in replacements:
            out = out.replace(old, new)

        remaining = [fragment for fragment in UNSUPPORTED_SKILL_FRAGMENTS if fragment in out]
        if remaining:
            raise ValueError(f"{source}: unsupported Codex runtime fragments: {remaining}")
    return out


def replace_rule_loading_paths(body: str) -> str:
    out = body.replace(
        "`${HOME}/.codex/rules/*` は @import 済みで既に context にある。"
        "読み直さず、今回の差分で違反しうる具体パターンを観点別に列挙する。",
        "`RULES_CORE.md`と`RULES_INDEX.md`を読み、taskに該当する詳細ruleを特定する。"
        "今回の差分で違反しうる具体パターンを観点別に列挙する。",
    )
    out = out.replace(
        "`${HOME}/.codex/rules/*` は @import 済みで既に context にある",
        "`RULES_CORE.md`と`RULES_INDEX.md`を読み、taskに該当する詳細ruleだけを明示的に読む",
    )
    out = out.replace(
        "`${HOME}/.codex/rules/*` は @import 済みで context にある",
        "`RULES_CORE.md`と`RULES_INDEX.md`を読み、taskに該当する詳細ruleだけを明示的に読む",
    )
    return out.replace(
        "| ロード済み rules | `RULES_CORE.md`と`RULES_INDEX.md`を読み、taskに該当する詳細ruleだけを明示的に読む |",
        "| 適用rules | `RULES_CORE.md`と`RULES_INDEX.md`を読み、taskに該当する詳細ruleだけを明示的に読む |",
    )


def replace_global_agents_contracts(body: str) -> str:
    out = body
    for agents_path in ("`${HOME}/.codex/AGENTS.md`", "`$HOME/.codex/AGENTS.md`"):
        out = out.replace(
            f"{agents_path} の「着手前の方針検証」発動条件",
            "taskのscope,risk,関連skill descriptionの発動条件",
        )
        out = out.replace(
            f"{agents_path} 「着手前の方針検証」と整合する。",
            "Taskのscopeとriskを確認し,該当するskill descriptionに従う。",
        )
    return out.replace(
        "「着手前の方針検証」と整合する。",
        "Taskのscopeとriskを確認し,該当するskill descriptionに従う。",
    )


def replace_codex_paths(body: str) -> str:
    out = re.sub(
        r"@\s+`?\$(?:\{HOME\}|HOME)/\.agents/skills/([^/]+)/SKILL\.md`?",
        r"`$\1`",
        body,
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
    out = replace_rule_loading_paths(out)
    out = out.replace(
        "`code-reviewer` は読み取り専用・sonnet モデルで安定した出力形式を持つため、",
        "`code-reviewer` は読み取り専用で安定した出力形式を持つため、",
    )
    out = out.replace(
        "`code-reviewer` は読み取り専用・sonnet モデルで安定している。",
        "`code-reviewer` は読み取り専用で安定している。",
    )
    return replace_global_agents_contracts(out)


def replace_codex_surface_contracts(body: str, *, role: ArtifactRole) -> str:
    if role is not ArtifactRole.TDD_SKILL:
        return body

    if CODEX_QA_DISPATCH_INSTRUCTION not in body:
        raise ValueError("TDD_SKILL: missing qa_nightmare dispatch instruction")
    out = body.replace(
        CODEX_QA_DISPATCH_INSTRUCTION,
        CODEX_QA_FAIL_CLOSED_INSTRUCTION,
        1,
    )
    for old, new in CODEX_QA_SURFACE_REPLACEMENTS:
        if old not in out:
            raise ValueError(f"TDD_SKILL: missing Codex qa_nightmare contract: {old}")
        out = out.replace(old, new, 1)
    future_heading = "### qa_nightmare の将来有効化仕様\n\n"
    out = out.replace(CODEX_QA_FAIL_CLOSED_INSTRUCTION, "", 1)
    out = out.replace(
        future_heading,
        future_heading + CODEX_QA_FAIL_CLOSED_INSTRUCTION,
        1,
    )
    out = out.replace("qa_nightmare-preflight", "qa-nightmare-preflight")
    out = re.sub(
        r"\n{3,}(?=(?:`qa-nightmare-preflight`|子agentへabsolute filesystem pathを渡さず))",
        "\n\n",
        out,
    )
    out = replace_marked_section(
        out,
        QA_CONTINUATION_START,
        QA_CONTINUATION_END,
        CODEX_QA_CONTINUATION_OVERLAY,
    )
    return out


def replace_command_invocations(body: str) -> str:
    out = re.sub(
        r"`/([a-zA-Z0-9_.-]+)`",
        lambda match: f"`${COMMAND_DESTINATIONS.get(match.group(1), match.group(1))}`",
        body,
    )
    return re.sub(
        r"(?<![\w`])/(feat|fix|review|deep-review|commit|commit-msg|test|refactor|plan|explain)(?![\w`:-])",
        lambda match: f"${COMMAND_DESTINATIONS.get(match.group(1), match.group(1))}",
        out,
    )


def add_portability_notes(body: str, *, source: Path, kind: str) -> str:
    out = body
    source_str = str(source).replace("\\", "/")
    note = f"""\n<!-- {MANAGED_MARKER}; source={source_str}; generated-by=scripts/port-claude-assets-to-codex.py -->\n\n## Codex portability notes\n\n- This file was ported from `{source_str}`.\n- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${{HOME}}/.agents/skills` in plugin-only mode.\n- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.\n- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.\n- Subagent usage must follow `${{HOME}}/.codex/SUBAGENTS.md` and the current Codex tool contract.\n"""
    if MANAGED_MARKER not in out:
        # Insert after first H1 when possible; otherwise prepend after frontmatter.
        match = re.search(r"(^# .+?\n)", out, re.MULTILINE)
        if match:
            insert_at = match.end()
            out = out[:insert_at] + note + out[insert_at:]
        else:
            out = note + "\n" + out

    if kind == "rule" and "## Codex rule loading" not in out:
        out = out.rstrip() + """\n\n## Codex rule loading\n\nThis rule applies when selected through `RULES_INDEX.md` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the runtime instruction hierarchy and report the conflict.\n"""

    return out


def transform_body(
    body: str, *, source: Path, kind: str, role: ArtifactRole
) -> str:
    out = replace_runtime_fragments(body, source=source, kind=kind)
    out = replace_codex_paths(out)
    out = replace_codex_surface_contracts(out, role=role)
    out = replace_command_invocations(out)
    return add_portability_notes(out, source=source, kind=kind)


def transform_text(
    text: str, *, source: Path, kind: str, role: ArtifactRole
) -> str:
    frontmatter, body = split_frontmatter(text)
    fm = transform_frontmatter(frontmatter, source, kind=kind)
    new_body = transform_body(body, source=source, kind=kind, role=role)
    return (fm or "") + new_body


def transform_source(
    source: Path, *, repo: Path, kind: str
) -> tuple[str, ArtifactRole]:
    relative_source = source.relative_to(repo)
    role = classify_artifact_role(relative_source, kind=kind)
    output = transform_text(
        source.read_text(encoding="utf-8"),
        source=relative_source,
        kind=kind,
        role=role,
    )
    return output, role


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


def iter_skill_sources(repo: Path) -> list[Path]:
    return sorted((repo / SHARED_SKILLS_DIR).glob("*/SKILL.md"))


def iter_skill_resource_sources(repo: Path) -> list[Path]:
    return sorted(
        path
        for skill in iter_skill_sources(repo)
        for path in skill.parent.rglob("*")
        if path.is_file() and path != skill
    )


def iter_rule_sources(repo: Path) -> list[Path]:
    return sorted((repo / SHARED_RULES_DIR).glob("*.md"))


def iter_command_sources(repo: Path) -> list[Path]:
    return sorted((repo / SHARED_COMMANDS_DIR).glob("*.md"))


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
        and not any(
            path.relative_to(source.parent).match(pattern)
            for pattern in ALLOWED_SKILL_FILES
        )
    ]
    if unexpected_skill_files:
        raise ValueError(
            "unsupported Claude skill resource: " + ", ".join(sorted(unexpected_skill_files))
        )


def validate_shared_skill_layout(repo: Path) -> None:
    skills_dir = repo / SHARED_SKILLS_DIR
    entries = tuple(skills_dir.iterdir())
    missing_entrypoints = sorted(
        path.name
        for path in entries
        if path.is_dir() and not (path / "SKILL.md").is_file()
    )
    root_files = sorted(path.name for path in entries if path.is_file())
    if missing_entrypoints or root_files:
        raise ValueError(
            "invalid shared skill layout: "
            f"missing_entrypoints={missing_entrypoints}, root_files={root_files}"
        )


def validate_transformability(repo: Path, command_sources: list[Path]) -> None:
    for source in iter_skill_sources(repo):
        transform_source(source, repo=repo, kind="skill")
    for source in iter_skill_resource_sources(repo):
        transform_source(source, repo=repo, kind="skill_resource")
    for source in iter_rule_sources(repo):
        transform_source(source, repo=repo, kind="rule")
    for source in command_sources:
        skill_name = COMMAND_DESTINATIONS[source.stem]
        native_skill = repo / "codex" / "skills" / skill_name / "SKILL.md"
        if not native_skill.is_file():
            raise ValueError(
                f"{source.relative_to(repo)}: missing Codex-native entrypoint "
                f"codex/skills/{skill_name}/SKILL.md"
            )
        transform_source(source, repo=repo, kind="command")


def validate_sources(repo: Path) -> None:
    command_sources = iter_command_sources(repo)
    validate_shared_skill_layout(repo)
    validate_command_manifest(command_sources)
    validate_skill_resources(repo)
    validate_transformability(repo, command_sources)


def port_skills(repo: Path, args: argparse.Namespace) -> list[PortedFile]:
    result: list[PortedFile] = []
    for source in iter_skill_sources(repo):
        skill_name = source.parent.name
        dest = repo / "codex" / "skills" / skill_name / "SKILL.md"
        out, role = transform_source(source, repo=repo, kind="skill")
        changed, backed_up = write_file(dest, out, args=args)
        result.append(
            PortedFile(source, dest, "skill", role, changed, backed_up)
        )
    for source in iter_skill_resource_sources(repo):
        relative_source = source.relative_to(repo / SHARED_SKILLS_DIR)
        dest = repo / "codex" / "skills" / relative_source
        out, role = transform_source(source, repo=repo, kind="skill_resource")
        changed, backed_up = write_file(dest, out, args=args)
        result.append(
            PortedFile(source, dest, "skill_resource", role, changed, backed_up)
        )
    return result


def port_rules(repo: Path, args: argparse.Namespace) -> list[PortedFile]:
    result: list[PortedFile] = []
    for source in iter_rule_sources(repo):
        dest = repo / "codex" / "rules" / source.name
        out, role = transform_source(source, repo=repo, kind="rule")
        changed, backed_up = write_file(dest, out, args=args)
        result.append(
            PortedFile(source, dest, "rule", role, changed, backed_up)
        )
    return result


def port_commands(repo: Path, args: argparse.Namespace) -> list[PortedFile]:
    result: list[PortedFile] = []
    for source in iter_command_sources(repo):
        skill_name = COMMAND_DESTINATIONS[source.stem]
        dest = repo / "codex" / "skills" / skill_name / COMMAND_REFERENCES[source.stem]
        out, role = transform_source(source, repo=repo, kind="command")
        changed, backed_up = write_file(dest, out, args=args)
        result.append(
            PortedFile(source, dest, "command", role, changed, backed_up)
        )
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
    if len(parts) == 3 and parts[:2] == ("common", "rules") and source.suffix == ".md":
        return repo / "codex" / "rules" / source.name
    if (
        len(parts) >= 4
        and parts[:2] == ("common", "skills")
        and source.suffix == ".md"
    ):
        return repo / "codex" / "skills" / parts[2] / Path(*parts[3:])
    if len(parts) == 3 and parts[:2] == ("common", "commands") and source.suffix == ".md":
        skill_name = COMMAND_DESTINATIONS.get(source.stem)
        if skill_name is not None:
            return repo / "codex" / "skills" / skill_name / COMMAND_REFERENCES[source.stem]
    return None


def prune_stale_outputs(repo: Path, args: argparse.Namespace) -> list[Path]:
    candidates = list((repo / "codex" / "rules").glob("*.md"))
    candidates.extend(
        path for path in (repo / "codex" / "skills").rglob("*") if path.is_file()
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


def generate_rule_aggregates(repo: Path, args: argparse.Namespace) -> None:
    rules_dir = repo / "codex" / "rules"
    documents = load_rule_documents(repo)
    if args.dry_run:
        return
    rules_dir.mkdir(parents=True, exist_ok=True)
    (rules_dir / RULE_INDEX_NAME).write_text(
        render_rule_index(documents), encoding="utf-8"
    )
    (rules_dir / RULE_BUNDLE_NAME).write_text(
        render_rule_bundle(documents), encoding="utf-8"
    )


def main() -> int:
    args = parse_args()
    repo = Path(args.repo).resolve()
    if not (repo / SHARED_SKILLS_DIR).is_dir():
        print(f"ERROR: missing common/skills under {repo}", file=sys.stderr)
        return 2
    if not (repo / SHARED_RULES_DIR).is_dir():
        print(f"ERROR: missing common/rules under {repo}", file=sys.stderr)
        return 2

    validate_sources(repo)

    ported: list[PortedFile] = []
    ported.extend(port_skills(repo, args))
    ported.extend(port_commands(repo, args))
    ported.extend(port_rules(repo, args))
    pruned = prune_stale_outputs(repo, args) if args.prune else []
    generate_rule_aggregates(repo, args)

    print("Shared assets -> Codex port complete")
    print(f"skills: {sum(1 for p in ported if p.kind == 'skill')}")
    print(f"commands: {sum(1 for p in ported if p.kind == 'command')}")
    print(f"rules:  {sum(1 for p in ported if p.kind == 'rule')}")
    print(f"changed:{sum(1 for p in ported if p.changed)}")
    print(f"pruned: {len(pruned)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
