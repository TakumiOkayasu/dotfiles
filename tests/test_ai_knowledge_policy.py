#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    gitignore = (ROOT / "config/git/.gitignore.common").read_text(encoding="utf-8")
    assert "\n.ai/\n" in gitignore

    policy = (ROOT / "common/rules/project-ai-knowledge.md").read_text(encoding="utf-8")
    assert "project-local `.ai/` directory is the only source" in policy
    assert (
        "Do not make the collector scrape `.claude/`, `.codex/`, `claude_tmp/`, or `codex_tmp/` directly"
        in policy
    )
    print("test_ai_knowledge_policy: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
