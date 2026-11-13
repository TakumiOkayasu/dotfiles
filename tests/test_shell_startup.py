"""Shell startup stays quiet, composable, and safe to source again."""

import shutil
from pathlib import Path

import pytest

from tests.shell_helpers import SHELL_CONFIG, run_shell, write_command


class TestShellStartup:
    @pytest.mark.parametrize("shell", ["bash", "zsh"])
    def test_noninteractive_source_skips_interactive_setup(
        self,
        tmp_path: Path,
        shell: str,
    ) -> None:
        result = run_shell(
            tmp_path,
            shell,
            "typeset -f __bashrc_eval_output __zshrc_eval_output mkcd; printf 'done\\n'",
            interactive=False,
        )
        assert result.stdout == "done\n"
        assert not (tmp_path / "home/.zcompdump").exists()

    @pytest.mark.parametrize(
        "initial,expected",
        [
            ("unset PROMPT_COMMAND", []),
            ("PROMPT_COMMAND='printf existing'", ["printf existing"]),
            (
                "PROMPT_COMMAND=('printf existing' 'printf another')",
                ["printf existing", "printf another"],
            ),
        ],
    )
    def test_bash_history_hook_is_registered_once_without_losing_hooks(
        self,
        tmp_path: Path,
        initial: str,
        expected: list[str],
    ) -> None:
        result = run_shell(
            tmp_path,
            "bash",
            'printf "%s\\n" "${PROMPT_COMMAND[@]}"',
            before=initial,
            source_count=2,
        )
        assert result.stdout.splitlines() == expected + ["history -a; history -n"]

    def test_bash_detects_repository_through_relative_symlinks_without_readlink_f(
        self,
        tmp_path: Path,
    ) -> None:
        repo = tmp_path / "checkout"
        bash_dir = repo / "config/shell/bash"
        bash_dir.mkdir(parents=True)
        shutil.copy2(SHELL_CONFIG / "bash/bashrc", bash_dir / "bashrc")
        (repo / "config/shell/ssh-agent.sh").write_text(":\n")
        home = tmp_path / "home"
        (home / "links").mkdir(parents=True)
        (home / ".bashrc").symlink_to("links/bashrc")
        (home / "links/bashrc").symlink_to("../../checkout/config/shell/bash/bashrc")
        write_command(
            tmp_path,
            "readlink",
            '[ "$1" != -f ] || exit 1\nexec /usr/bin/readlink "$@"',
        )
        result = run_shell(
            tmp_path,
            "bash",
            'printf "%s\\n" "$DOTFILES_DIR"',
            before="unset DOTFILES_DIR",
            source=home / ".bashrc",
        )
        assert result.stdout.strip() == str(repo)

    @pytest.mark.parametrize("shell", ["bash", "zsh"])
    @pytest.mark.parametrize("program", ["mise", "fzf", "zoxide", "oh-my-posh"])
    def test_failed_initialization_is_attempted_without_evaluating_its_output(
        self,
        tmp_path: Path,
        shell: str,
        program: str,
    ) -> None:
        log = tmp_path / "calls"
        write_command(
            tmp_path,
            program,
            'printf "%s\\n" "$*" >> "$TEST_CALLS"\n'
            "echo DOTFILES_FAILED_OUTPUT=evaluated; exit 1",
        )
        themes = tmp_path / "home/.poshthemes"
        themes.mkdir(parents=True)
        (themes / "sim-web.omp.json").write_text("{}")
        result = run_shell(
            tmp_path,
            shell,
            'printf "failed=%s\\n" "${DOTFILES_FAILED_OUTPUT-unset}"',
            environment={"TEST_CALLS": str(log)},
        )
        assert result.stdout == "failed=unset\n"
        if program == "mise":
            expected = [f"activate {shell}", f"completion {shell}"]
        elif program == "fzf":
            expected = [f"--{shell}"]
        elif program == "zoxide":
            expected = [f"init {shell}"]
        else:
            config = themes / "sim-web.omp.json"
            expected = [f"init {shell} --config {config}"]
            if shell == "bash":
                expected.insert(0, f"init bash --strict --config {config}")
        assert log.read_text().splitlines() == expected

    @pytest.mark.parametrize("program", ["mise", "fzf", "zoxide", "oh-my-posh"])
    def test_zsh_evaluates_successful_initialization_without_leaking_loop_variables(
        self,
        tmp_path: Path,
        program: str,
    ) -> None:
        write_command(tmp_path, program, "echo DOTFILES_INITIALIZED=yes")
        themes = tmp_path / "home/.poshthemes"
        themes.mkdir(parents=True)
        (themes / "sim-web.omp.json").write_text("{}")
        result = run_shell(
            tmp_path,
            "zsh",
            'printf "%s %s\\n" "$DOTFILES_INITIALIZED" "$dir"',
            before="dir=existing",
        )
        assert result.stdout == "yes existing\n"

    @pytest.mark.parametrize("strict_supported", [True, False])
    def test_bash_prompt_config_and_strict_fallback_preserve_argument_boundaries(
        self,
        tmp_path: Path,
        strict_supported: bool,
    ) -> None:
        log = tmp_path / "arguments"
        write_command(
            tmp_path,
            "oh-my-posh",
            'printf "%s\\n" "$@" >> "$TEST_ARGUMENTS"\n'
            'if [ "$3" = --strict ] && [ "$STRICT_SUPPORTED" = no ]; then\n'
            "  echo DOTFILES_FAILED_OUTPUT=evaluated; exit 1\n"
            "fi\necho DOTFILES_INITIALIZED=yes",
        )
        config = str(tmp_path / "custom theme.omp.json")
        result = run_shell(
            tmp_path,
            "bash",
            'printf "%s %s\\n" "$DOTFILES_INITIALIZED" "${DOTFILES_FAILED_OUTPUT-unset}"',
            environment={
                "OH_MY_POSH_CONFIG": config,
                "TEST_ARGUMENTS": str(log),
                "STRICT_SUPPORTED": "yes" if strict_supported else "no",
            },
        )
        assert result.stdout == "yes unset\n"
        expected = ["init", "bash", "--strict", "--config", config]
        if not strict_supported:
            expected += ["init", "bash", "--config", config]
        assert log.read_text().splitlines() == expected

    def test_zsh_fallback_prompt_preserves_existing_precmd(
        self,
        tmp_path: Path,
    ) -> None:
        result = run_shell(
            tmp_path,
            "zsh",
            'precmd; printf "hooks=%s\\n" "${precmd_functions[*]}"; '
            'printf "prompt=%s\\n" "$PROMPT"',
            before="precmd() { printf 'existing\\n'; }",
            source_count=2,
        )
        assert result.stdout.startswith("existing\nhooks=vcs_info\n")
        assert "${vcs_info_msg_0_}" in result.stdout

    @pytest.mark.parametrize("initial", ["", "setopt INC_APPEND_HISTORY"])
    def test_zsh_shared_history_does_not_enable_conflicting_append_mode(
        self,
        tmp_path: Path,
        initial: str,
    ) -> None:
        result = run_shell(
            tmp_path,
            "zsh",
            'printf "%s %s\\n" "$options[sharehistory]" "$options[incappendhistory]"',
            before=initial,
        )
        assert result.stdout == "on off\n"

    @pytest.mark.parametrize("shell", ["bash", "zsh"])
    @pytest.mark.parametrize("arguments", ["", "one two", "''"])
    def test_mkcd_rejects_invalid_arguments_without_changing_directory(
        self,
        tmp_path: Path,
        shell: str,
        arguments: str,
    ) -> None:
        result = run_shell(
            tmp_path,
            shell,
            f'mkcd {arguments}; printf "status=%s pwd=%s\\n" "$?" "$PWD"',
            expected_stderr="usage: mkcd DIR\n",
        )
        assert result.stdout == f"status=2 pwd={tmp_path / 'home'}\n"
        assert not (tmp_path / "home/one").exists()

    @pytest.mark.parametrize("shell", ["bash", "zsh"])
    def test_mkcd_accepts_directory_names_starting_with_a_dash(
        self,
        tmp_path: Path,
        shell: str,
    ) -> None:
        result = run_shell(tmp_path, shell, 'mkcd -nested; printf "%s\\n" "$PWD"')
        assert result.stdout == f"{tmp_path / 'home/-nested'}\n"


class TestShellLocale:
    @pytest.mark.parametrize("shell", ["bash", "zsh"])
    def test_common_settings_preserve_locale_precedence(
        self,
        tmp_path: Path,
        shell: str,
    ) -> None:
        result = run_shell(
            tmp_path,
            shell,
            'printf "%s|%s|%s|%s\\n" "$LANG" "${LC_ALL-unset}" '
            '"$LC_CTYPE" "${LC_MESSAGES-unset}"',
            source=SHELL_CONFIG / "common.sh",
            interactive=False,
            environment={"LANG": "C", "LC_CTYPE": "C"},
        )
        assert result.stdout == "C|unset|C|unset\n"

    @pytest.mark.parametrize(
        "available,expected",
        [
            ("C\nC.utf8\nja_JP.utf8", "ja_JP.UTF-8"),
            ("C\nC.utf8", "C.UTF-8"),
            ("C\nPOSIX", "C"),
        ],
    )
    def test_default_locale_is_available_on_the_host(
        self,
        tmp_path: Path,
        available: str,
        expected: str,
    ) -> None:
        write_command(tmp_path, "locale", f"printf '%s\\n' '{available}'")
        result = run_shell(
            tmp_path,
            "bash",
            'printf "%s\\n" "$LANG"',
            before="unset LANG",
            source=SHELL_CONFIG / "common.sh",
            interactive=False,
        )
        assert result.stdout == f"{expected}\n"
