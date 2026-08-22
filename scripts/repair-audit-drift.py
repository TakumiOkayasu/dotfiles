#!/usr/bin/env python3
"""One-shot repair for stale generated assets and expectations found by repo audit."""

from __future__ import annotations

from pathlib import Path

TEST_PATH = Path("tests/test_install.py")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"expected block not found: {label}")
    return text.replace(old, new, 1)


def main() -> int:
    text = TEST_PATH.read_text(encoding="utf-8")

    text = replace_once(
        text,
        '        assert "tests/test_port_claude_assets.py" in entrypoint\n',
        '        assert "tests/test_port_claude_assets.py" in entrypoint\n'
        '        assert "tests/test_issue_regressions.py" in entrypoint\n',
        "default installer entrypoint",
    )

    text = replace_once(
        text,
        '''    def test_config_template_uses_canonical_agent_thread_limit(self) -> None:
        """agent thread 上限に現行の正式キーを使う"""
        data = tomllib.loads(self.TEMPLATE.read_text(encoding="utf-8"))

        assert data["agents"]["max_concurrent_threads_per_session"] == 8
        assert "max_threads" not in data["agents"]
''',
        '''    def test_config_template_preserves_configured_agent_thread_limit(self) -> None:
        """agent thread 上限に正式キーと明示設定値を使う"""
        data = tomllib.loads(self.TEMPLATE.read_text(encoding="utf-8"))

        assert data["agents"]["max_concurrent_threads_per_session"] == 100
        assert "max_threads" not in data["agents"]
''',
        "agent thread limit",
    )

    text = replace_once(
        text,
        '''        claude_global = (REPO_ROOT / "claude" / "global_CLAUDE.md").read_text(
            encoding="utf-8"
        )
''',
        "",
        "stale Claude global setup",
    )
    text = replace_once(
        text,
        '''        assert "@'$HOME/.claude/rules/natural-japanese.md'" in claude_global
''',
        "",
        "stale Claude rule assertion",
    )

    TEST_PATH.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
