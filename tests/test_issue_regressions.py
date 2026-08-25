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
CODEX_HOOK_DISPATCHER = REPO_ROOT / "codex" / "hooks" / "hook-dispatcher.sh"
CLAUDE_METHODOLOGY_HOOK = (
    REPO_ROOT / "claude" / "hooks" / "methodology-skill-reminder.sh"
)
CODEX_METHODOLOGY_HOOK = (
    REPO_ROOT / "codex" / "hooks" / "methodology-skill-reminder.sh"
)
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

EXPLICIT_ONLY_SKILLS = (
    "consult",
    "measure",
    "orchestrate",
    "probe",
    "refactoring",
    "semantic-generation",
    "systematic-debugging",
)


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


def test_methodology_skills_are_not_keyword_injected() -> None:
    """Modern models choose methodology from task evidence, not broad keyword hooks."""
    settings = json.loads(CLAUDE_SETTINGS.read_text(encoding="utf-8"))
    dispatcher = CODEX_HOOK_DISPATCHER.read_text(encoding="utf-8")
    serialized_hooks = json.dumps(settings.get("hooks", {}), ensure_ascii=False)

    assert "methodology-skill-reminder.sh" not in serialized_hooks
    assert "methodology-skill-reminder.sh" not in dispatcher
    assert not CLAUDE_METHODOLOGY_HOOK.exists()
    assert not CODEX_METHODOLOGY_HOOK.exists()


def test_advisory_methodology_skills_are_explicit_only() -> None:
    """Advisory workflows must not override normal model reasoning implicitly."""
    for skill_name in EXPLICIT_ONLY_SKILLS:
        skill = REPO_ROOT / "common" / "skills" / skill_name / "SKILL.md"
        content = skill.read_text(encoding="utf-8")
        assert "disable-model-invocation: true" in content, skill


def test_orchestration_is_only_an_explicit_compatibility_workflow() -> None:
    """Runtime catalog compatibility must not make orchestration implicit."""
    skill = REPO_ROOT / "common" / "skills" / "orchestrate" / "SKILL.md"
    content = skill.read_text(encoding="utf-8")

    assert "disable-model-invocation: true" in content
    assert "通常のtask分解" in content
    assert "人数やround数を固定しない" in content


def test_referent_rule_does_not_require_generation_ceremony() -> None:
    """Referent clarity remains a principle without a mandatory two-stage artifact flow."""
    rule = (REPO_ROOT / "common" / "rules" / "referent-before-label.md").read_text(
        encoding="utf-8"
    )

    assert "IMPORTANT:" not in rule
    assert "対応表なしの本文提出は禁止" not in rule
    assert "本文を破棄" not in rule
