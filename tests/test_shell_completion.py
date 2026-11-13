"""Shell startup registers mise completion only after successful initialization."""

from pathlib import Path

import pytest

from tests.shell_helpers import run_shell


@pytest.mark.parametrize(
    "shell,on_path", [("bash", True), ("zsh", True), ("zsh", False)]
)
@pytest.mark.parametrize("mode", ["success", "failed", "absent", "empty"])
def test_mise_completion_registration(
    tmp_path: Path, shell: str, mode: str, on_path: bool
) -> None:
    fake_bin = tmp_path / "home/.local/bin"
    fake_bin.mkdir(parents=True)
    log = tmp_path / "calls"
    if mode != "absent":
        mise = fake_bin / "mise"
        mise.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$*" >> "$MISE_TEST_LOG"\n'
            '[ "$1" = completion ] || exit 0\n'
            'case "$MISE_TEST_MODE" in\n'
            'failed) echo "MISE_FAILED_OUTPUT=executed"; exit 1 ;;\n'
            "empty) exit 0 ;;\n"
            "esac\n"
            'case "$2" in\n'
            'bash) echo "_mise_test() { :; }; complete -F _mise_test mise" ;;\n'
            'zsh) echo "_mise_test() { :; }; compdef _mise_test mise" ;;\n'
            "esac\n"
        )
        mise.chmod(0o755)
    check = (
        "complete -p mise 2>/dev/null || true"
        if shell == "bash"
        else 'print -r -- "${_comps[mise]-}"'
    )
    result = run_shell(
        tmp_path,
        shell,
        check + '; printf "failed=%s\\n" "${MISE_FAILED_OUTPUT-unset}"',
        path_prefix=fake_bin if on_path else None,
        environment={"MISE_TEST_LOG": str(log), "MISE_TEST_MODE": mode},
    )
    completion = (
        ("complete -F _mise_test mise" if shell == "bash" else "_mise_test")
        if mode == "success"
        else ""
    )
    prefix = completion + "\n" if shell == "zsh" or completion else ""
    assert result.stdout == prefix + "failed=unset\n"
    if mode != "absent":
        assert log.read_text().splitlines() == [
            f"activate {shell}",
            f"completion {shell}",
        ]
    else:
        assert not log.exists()
