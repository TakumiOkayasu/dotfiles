from __future__ import annotations

import json
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parent.parent
SKILLS = ("dig", "fix-ci", "decomposition", "deslop")


@pytest.mark.parametrize("name", SKILLS)
def test_kuu_skill_reaches_codex_extra_with_license_only(
    name: str, generate_install_time_ai_assets: None
) -> None:
    generated = ROOT / ".generated" / "ai-assets"
    source = ROOT / "codex" / "skills" / name
    plugin = generated / "plugins" / "dotfile-work-codex-extra" / "skills" / name

    assert (plugin / "SKILL.md").is_file()
    assert (plugin / "LICENSE").read_bytes() == (source / "LICENSE").read_bytes()
    assert b"GNU GENERAL PUBLIC LICENSE" in (plugin / "LICENSE").read_bytes()
    assert (plugin / "references" / "upstream.md").is_file()
    assert not (generated / "claude" / "skills" / name).exists()

    metadata = (plugin / "agents" / "openai.yaml").read_text()
    assert "allow_implicit_invocation: false" in metadata


def test_kuu_skills_are_native_optional_assets() -> None:
    manifest = json.loads((ROOT / "scripts" / "ai-assets-manifest.json").read_text())
    assert set(SKILLS) <= set(manifest["codex_native_skills"])
    assert not set(SKILLS) & set(manifest["core_skills"])
