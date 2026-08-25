from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

RULE_INDEX_NAME = "RULES_INDEX.md"
RULE_BUNDLE_NAME = "RULES_BUNDLE.md"
SUMMARY_BY_NAME = {
    "coding-conventions.md": "language-independent coding conventions, naming, testing, error handling, and logging",
    "contract-driven-object-collaboration.md": "ideal contracts, object collaboration, representation hiding, responsibility separation, and DI as composition result",
    "implementation-policy.md": "dependency, library, DB, validation, logging, crypto, and SQL policy",
    "hallucination-prevention.md": "source verification and uncertainty handling policy",
    "hierarchical-architecture.md": "architecture invariants, dependency direction, composition, interfaces, and layer naming",
    "simple-engineering.md": "root-cause-first fixes, evidence-based compatibility, reuse, YAGNI/KISS, and minimal-diff invariants",
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
        "Codex は作業前に `RULES_CORE.md`、`RULES_INDEX.md`、task に該当する詳細 rule を明示的に読む必要があります。",
        "",
        "| Rule | Title | Description |",
        "| --- | --- | --- |",
    ]
    lines.extend(
        f"| `{document.relative_path}` | {document.title} | {document.description} |"
        for document in documents
    )
    return "\n".join([*lines, ""])


def render_rule_bundle(documents: tuple[RuleDocument, ...]) -> str:
    parts = [
        "# Codex Rules Bundle",
        "",
        "このファイルは参照・検証用の連結 rules bundle です。直接編集せず、元 rule を編集して再生成してください。",
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
