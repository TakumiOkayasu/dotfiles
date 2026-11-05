"""Shell startup must register mise completions without evaluating failed output."""

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.parametrize("shell,on_path", [("bash", True), ("zsh", True), ("zsh", False)])
@pytest.mark.parametrize("mode", ["success", "failed", "absent", "empty"])
def test_mise_completion_registration(tmp_path: Path, shell: str, mode: str, on_path: bool) -> None:
    executable = shutil.which(shell)
    if executable is None:
        pytest.skip(f"{shell} is not installed")
    home = tmp_path / "home"
    home.mkdir()
    (home / ".shell_common").write_text("")
    fake_bin = home / ".local/bin"
    fake_bin.mkdir(parents=True)
    log = tmp_path / "calls"
    if mode != "absent":
        mise = fake_bin / "mise"
        mise.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" >> "$MISE_TEST_LOG"\n'
            '[ "$1" = completion ] || exit 0\n'
            'case "$MISE_TEST_MODE" in\n'
            'failed) echo "MISE_FAILED_OUTPUT=executed"; exit 1 ;;\n'
            'empty) exit 0 ;;\n'
            'esac\n'
            'case "$2" in\n'
            'bash) echo "_mise_test() { :; }; complete -F _mise_test mise" ;;\n'
            'zsh) echo "_mise_test() { :; }; compdef _mise_test mise" ;;\n'
            'esac\n'
        )
        mise.chmod(0o755)
    check = 'complete -p mise 2>/dev/null || true' if shell == "bash" else 'print -r -- "${_comps[mise]-}"'
    source = ROOT / "config/shell" / shell / f"{shell}rc"
    command = f'source "{source}"; {check}; printf "failed=%s\\n" "${{MISE_FAILED_OUTPUT-unset}}"'
    args = [executable, "--noprofile", "--norc", "-ic", command] if shell == "bash" else [executable, "-df", "-ic", command]
    result = subprocess.run(
        args,
        env={"HOME": str(home), "DOTFILES_DIR": str(tmp_path / "no-dotfiles"),
             "PATH": f"{fake_bin}:/usr/bin:/bin" if on_path else "/usr/bin:/bin", "TERM": "xterm",
             "MISE_TEST_LOG": str(log), "MISE_TEST_MODE": mode},
        capture_output=True, text=True, timeout=15,
    )
    assert result.returncode == 0, result.stderr
    assert "failed=unset" in result.stdout
    assert ("_mise_test" in result.stdout) == (mode == "success"), result.stdout
    if mode != "absent":
        assert log.read_text().splitlines() == [f"activate {shell}", f"completion {shell}"]
    else:
        assert not log.exists()
