"""Exercise installer functions without running unrelated installation categories."""

import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


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
    library = (ROOT / "install.sh").read_text().rsplit('\nmain "$@"', 1)[0]
    runner = tmp_path / "install.sh"
    runner.write_text(library + f'\nDOTFILES_DIR="{ROOT}"\n' + commands + "\n")
    return subprocess.run(
        [interpreter, str(runner)],
        input=input_text,
        capture_output=True,
        text=True,
        env={**os.environ, "HOME": str(home), "SHELL": shell},
        check=False,
        timeout=30,
    )
