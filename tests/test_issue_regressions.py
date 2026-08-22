#!/usr/bin/env python3
"""Repository issue regressions that cross existing test-suite boundaries."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
INSTALL_SH = REPO_ROOT / "install.sh"
CLAUDE_SETTINGS = REPO_ROOT / "claude" / "settings.json"
GH_REPO_AUTO_SETUP_HOOK = REPO_ROOT / "claude" / "hooks" / "gh-repo-auto-setup.sh"


def test_uninstall_before_install_returns_zero(tmp_path: Path) -> None:
    """A clean HOME is already in the desired uninstalled state."""
    home = tmp_path / "home"
    home.mkdir()
    env = {**os.environ, "HOME": str(home)}

    result = subprocess.run(
        ["sh", str(INSTALL_SH), "-u", "-f"],
        cwd=REPO_ROOT,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )

    assert result.returncode == 0, result.stdout + result.stderr


def test_repository_setup_is_explicit_not_a_post_tool_side_effect() -> None:
    """GitHub repository mutations must go through the explicit gh-setup-repo CLI."""
    settings = json.loads(CLAUDE_SETTINGS.read_text(encoding="utf-8"))
    serialized_hooks = json.dumps(settings.get("hooks", {}), ensure_ascii=False)

    assert "gh-repo-auto-setup.sh" not in serialized_hooks
    assert not GH_REPO_AUTO_SETUP_HOOK.exists()
    assert (REPO_ROOT / "bin" / "gh-setup-repo").is_file()
