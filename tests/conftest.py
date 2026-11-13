from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent


@pytest.fixture(autouse=True)
def isolate_runtime_directories(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CLAUDE_CONFIG_DIR", raising=False)
    monkeypatch.delenv("CODEX_HOME", raising=False)


@pytest.fixture(scope="session")
def generate_install_time_ai_assets() -> None:
    result = subprocess.run(
        [
            "python3",
            str(REPO_ROOT / "scripts" / "generate-ai-assets.py"),
            "--repo",
            str(REPO_ROOT),
        ],
        cwd=REPO_ROOT,
        env={
            key: value for key, value in os.environ.items()
            if key not in {"CLAUDE_CONFIG_DIR", "CODEX_HOME"}
        },
        capture_output=True,
        text=True,
        timeout=60,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
