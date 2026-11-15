"""Exercise installer functions without running unrelated installation categories."""

import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def copy_installer(destination: Path) -> None:
    """Copy the entry point and its definition modules into a fixture repo."""
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "install.sh", destination / "install.sh")
    shutil.copytree(
        ROOT / "scripts/install", destination / "scripts/install", dirs_exist_ok=True,
    )


def run_installer_functions(
    tmp_path: Path,
    commands: str,
    *,
    input_text: str = "",
    shell: str = "/bin/bash",
    interpreter: str = "sh",
) -> subprocess.CompletedProcess[str]:
    home = tmp_path / "home"
    home.mkdir(exist_ok=True)
    runner = tmp_path / "install.sh"
    runner.write_text(
        'set -eu\n'
        'INSTALLER_LIB_DIR="$1/scripts/install"\n'
        '. "$INSTALLER_LIB_DIR/library.sh"\n'
        'initialize_installer "$1"\n'
        'shift\n'
        + commands + "\n"
    )
    return subprocess.run(
        [interpreter, str(runner), str(ROOT)],
        input=input_text,
        capture_output=True,
        text=True,
        env={
            **{key: value for key, value in os.environ.items()
               if key not in {"CLAUDE_CONFIG_DIR", "CODEX_HOME"}},
            "HOME": str(home), "SHELL": shell,
        },
        check=False,
        timeout=30,
    )
