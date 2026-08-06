from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

RULE_INDEX_NAME = "RULES_INDEX.md"
RULE_BUNDLE_NAME = "RULES_BUNDLE.md"
JST = timezone(timedelta(hours=9), "JST")
SUMMARY_BY_NAME = {
    "coding-conventions.md": "language-independent coding conventions, naming, testing, error handling, and logging",
    "implementation-policy.md": "dependency, library, DB, validation, logging, crypto, and SQL policy",
    "hallucination-prevention.md": "source verification and uncertainty handling policy",
    "hierarchical-architecture.md": "architecture invariants, dependency direction, composition, interfaces, and layer naming",
}


@dataclass(frozen=True)
class RuleDocument:
    relative_path: str
    filename: str
    text: str

    @property
    def title(self) -> str:
        for line in self.text.splitlines():
            if line.startswith("# "):
                return line[2:].strip()
        return "(no title)"

    @property
    def description(self) -> str:
        summary = SUMMARY_BY_NAME.get(self.filename)
        if summary is not None:
            return summary
        for line in self.text.splitlines():
            stripped = line.strip("# ").strip()
            if stripped and not stripped.startswith("---"):
                return stripped[:160]
        return "project rule"


def generated_at_jst() -> str:
    return f"{datetime.now(JST).isoformat(timespec='seconds')} JST"


def load_rule_documents(root: Path) -> tuple[RuleDocument, ...]:
    rules_dir = root / "codex" / "rules"
    if not rules_dir.exists():
        return ()
    paths = sorted(
        path
        for path in rules_dir.glob("*.md")
        if path.name not in {RULE_INDEX_NAME, RULE_BUNDLE_NAME}
    )
    return tuple(
        RuleDocument(
            relative_path=path.relative_to(root).as_posix(),
            filename=path.name,
            text=path.read_text(encoding="utf-8"),
        )
        for path in paths
    )


def render_rule_index(documents: tuple[RuleDocument, ...]) -> str:
    lines = [
        "# Codex Rules Index",
        "",
        "このファイルは Codex asset pipeline により生成される rules index です。",
        "Codex は作業前に該当 rule を読む必要があります。hook により full content が注入された場合は、それを読了済みとして扱います。",
        "",
        "| Rule | Title | Description |",
        "| --- | --- | --- |",
    ]
    lines.extend(
        f"| `{document.relative_path}` | {document.title} | {document.description} |"
        for document in documents
    )
    return "\n".join([*lines, ""])


def render_rule_bundle(documents: tuple[RuleDocument, ...], generated_at: str) -> str:
    parts = [
        "# Codex Rules Bundle",
        "",
        "このファイルは hook/context injection 用の連結 rules bundle です。直接編集せず、元 rule を編集して再生成してください。",
        "",
        f"Generated at: {generated_at}",
        "",
    ]
    for document in documents:
        parts.extend(
            [
                "---",
                "",
                f"## Source: `{document.relative_path}`",
                "",
                document.text.rstrip(),
                "",
            ]
        )
    return "\n".join(parts).rstrip() + "\n"


def read_generated_at(bundle: str) -> str | None:
    prefix = "Generated at: "
    for line in bundle.splitlines():
        if line.startswith(prefix):
            return line.removeprefix(prefix)
    return None
