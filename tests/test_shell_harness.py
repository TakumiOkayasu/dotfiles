"""A successful probe must never hide shell startup failures."""

from pathlib import Path

import pytest

from tests.shell_helpers import run_shell


class TestShellHarness:
    @pytest.mark.parametrize(
        "startup,diagnostic",
        [
            ("return 17\n", "status 17"),
            ("printf unexpected >&2\n", "Unexpected stderr"),
        ],
    )
    def test_rejects_failed_or_noisy_source_before_successful_probe(
        self,
        tmp_path: Path,
        startup: str,
        diagnostic: str,
    ) -> None:
        source = tmp_path / "startup.sh"
        source.write_text(startup)
        with pytest.raises(AssertionError, match=diagnostic):
            run_shell(tmp_path, "bash", "printf masked", source=source)
