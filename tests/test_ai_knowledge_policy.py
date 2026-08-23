from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_project_ai_knowledge_is_private_by_default() -> None:
    gitignore = (ROOT / "config/git/.gitignore.common").read_text(encoding="utf-8")
    assert "\n.ai/\n" in gitignore


def test_collector_boundary_is_documented() -> None:
    policy = (ROOT / "common/rules/project-ai-knowledge.md").read_text(encoding="utf-8")
    assert "project-local `.ai/` directory is the only source" in policy
    assert "Do not make the collector scrape `.claude/`, `.codex/`, `claude_tmp/`, or `codex_tmp/` directly" in policy
