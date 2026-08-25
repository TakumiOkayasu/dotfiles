#!/usr/bin/env python3
"""Repository issue regressions that cross existing test-suite boundaries."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GENERATED_CODEX = REPO_ROOT / ".generated" / "ai-assets" / "codex"
INSTALL_SH = REPO_ROOT / "install.sh"
CLAUDE_SETTINGS = REPO_ROOT / "claude" / "settings.json"
CCSTATUSLINE_UPDATER = REPO_ROOT / ".github" / "workflows" / "update-ccstatusline.yml"
GH_REPO_AUTO_SETUP_HOOK = REPO_ROOT / "claude" / "hooks" / "gh-repo-auto-setup.sh"
COMMON_AUDIT_SKILL = (
    REPO_ROOT / "common" / "skills" / "instruction-surface-audit" / "SKILL.md"
)
CODEX_AUDIT_SKILL = (
    GENERATED_CODEX / "skills" / "instruction-surface-audit" / "SKILL.md"
)
CODEX_AUDIT_METADATA = (
    GENERATED_CODEX
    / "skills"
    / "instruction-surface-audit"
    / "agents"
    / "openai.yaml"
)
CLAUDE_CODE_REVIEWER = REPO_ROOT / "claude" / "agents" / "code-reviewer.md"
CODEX_CODE_REVIEWER = REPO_ROOT / "codex" / "agents" / "code_reviewer.toml"
AGENTS_MD = REPO_ROOT / "AGENTS.md"


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


def test_uninstall_preserves_unmanaged_symlinks(tmp_path: Path) -> None:
    """Uninstall may remove dotfiles-owned links, never unrelated HOME links."""
    home = tmp_path / "home"
    tier = home / ".claude" / "skills" / "1-core"
    tier.mkdir(parents=True)

    external_target = tmp_path / "external-skill"
    external_target.mkdir()
    unrelated_home_link = home / "unrelated-home-link"
    unrelated_tier_link = tier / "unrelated-tier-link"
    unrelated_home_link.symlink_to(external_target, target_is_directory=True)
    unrelated_tier_link.symlink_to(external_target, target_is_directory=True)

    managed_target = REPO_ROOT / "common" / "skills" / "tdd"
    managed_tier_link = tier / "managed-tier-link"
    managed_tier_link.symlink_to(managed_target, target_is_directory=True)

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
    assert unrelated_home_link.is_symlink()
    assert unrelated_tier_link.is_symlink()
    assert unrelated_home_link.resolve() == external_target.resolve()
    assert unrelated_tier_link.resolve() == external_target.resolve()
    assert not managed_tier_link.exists()
    assert not managed_tier_link.is_symlink()


def test_repository_setup_is_explicit_not_a_post_tool_side_effect() -> None:
    """GitHub repository mutations must go through the explicit gh-setup-repo CLI."""
    settings = json.loads(CLAUDE_SETTINGS.read_text(encoding="utf-8"))
    serialized_hooks = json.dumps(settings.get("hooks", {}), ensure_ascii=False)

    assert "gh-repo-auto-setup.sh" not in serialized_hooks
    assert not GH_REPO_AUTO_SETUP_HOOK.exists()
    assert (REPO_ROOT / "bin" / "gh-setup-repo").is_file()


def test_ccstatusline_tracks_latest_without_an_update_bot() -> None:
    """The explicit floating-version policy must not retain a pinned-version updater."""
    settings = json.loads(CLAUDE_SETTINGS.read_text(encoding="utf-8"))

    assert settings["statusLine"]["command"] == "bunx -y ccstatusline@latest"
    assert not CCSTATUSLINE_UPDATER.exists()


def test_instruction_surface_audit_is_explicit_and_ported() -> None:
    """The audit must remain read-only, explicit, and generated from common."""
    common = COMMON_AUDIT_SKILL.read_text(encoding="utf-8")
    codex = CODEX_AUDIT_SKILL.read_text(encoding="utf-8")
    metadata = CODEX_AUDIT_METADATA.read_text(encoding="utf-8")

    assert "name: instruction-surface-audit" in common
    assert "disable-model-invocation: true" in common
    assert "This audit is read-only." in common
    assert (
        "codex-port: managed; "
        "source=common/skills/instruction-surface-audit/SKILL.md"
    ) in codex
    assert "allow_implicit_invocation: false" in metadata


def test_code_review_requires_human_review_for_prohibited_operations() -> None:
    """AI review cannot approve prohibited or irreversible operations alone."""
    paths = (AGENTS_MD, CLAUDE_CODE_REVIEWER, CODEX_CODE_REVIEWER)

    for path in paths:
        content = path.read_text(encoding="utf-8")
        assert "HUMAN_REVIEW_REQUIRED" in content, path
        assert "人間" in content, path
        assert "rollback" in content, path
        assert "テスト" in content, path
