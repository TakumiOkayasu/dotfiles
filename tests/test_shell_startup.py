"""Shell startup stays quiet, composable, and safe to source again."""

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

from tests.shell_helpers import SHELL_CONFIG, run_shell, write_command


class TestShellPathMigration:
    @pytest.mark.parametrize("startup, shell", [
        (".bashrc", "bash"), (".profile", "bash"), (".zshrc", "zsh"),
    ])
    def test_patch_keeps_path_order_and_omits_unrelated_lines(
        self, tmp_path: Path, startup: str, shell: str,
    ) -> None:
        rc = tmp_path / startup
        snippet = tmp_path / ".config/shell/path" / f"{startup[1:]}.sh"
        assignments = 'export PATH="$HOME/bin:$PATH"\nPATH="${PATH}:$HOME/Tool bin"\n'
        show_path = 'printf "%s\\n" "$PATH"\n'
        original = show_path + assignments + "# private-neighbor\n" + show_path
        rc.write_text(original)
        executable = shutil.which(shell)
        if executable is None:
            pytest.skip(f"{shell} is not installed")
        environment = {"HOME": str(tmp_path), "PATH": "/usr/bin:/bin"}
        before = subprocess.check_output([executable, str(rc)], env=environment,
                                         text=True, timeout=10)

        preview = self._preview(tmp_path, startup, "2:3")

        assert preview.returncode == 0, preview.stderr
        assert "private-neighbor" not in preview.stdout
        assert rc.read_text() == original
        assert not snippet.exists()
        subprocess.run(["git", "apply", "--unidiff-zero"], cwd=tmp_path,
                       input=preview.stdout, text=True, check=True, timeout=10)
        assert snippet.read_text() == assignments
        after = subprocess.check_output([executable, str(rc)], env=environment,
                                        text=True, timeout=10)
        assert after == before

    @pytest.mark.parametrize("prefix, assignment", [
        ("", 'export PATH="$(printf /bin):$PATH"'),
        ("if true; then\n", 'export PATH="$HOME/bin:$PATH"\nfi'),
        ("cat <<'END'\n", 'export PATH="$HOME/bin:$PATH"\nEND'),
    ])
    def test_patch_rejects_dynamic_or_nested_assignments(
        self, tmp_path: Path, prefix: str, assignment: str,
    ) -> None:
        (tmp_path / ".bashrc").write_text(prefix + assignment + "\n")

        preview = self._preview(tmp_path, ".bashrc", "2" if prefix else "1")

        assert preview.returncode != 0
        assert preview.stdout == ""

    def test_preview_does_not_run_the_startup_file(self, tmp_path: Path) -> None:
        (tmp_path / ".zshrc").write_text(
            'touch "$HOME/executed"\nexport PATH="$HOME/bin:$PATH"\n',
        )

        preview = self._preview(tmp_path, ".zshrc", "2")

        assert preview.returncode == 0, preview.stderr
        assert not (tmp_path / "executed").exists()

    @pytest.mark.parametrize("existing", ["linked-startup", "existing-destination", "linked-parent"])
    def test_patch_refuses_to_replace_links_or_existing_destination(
        self, tmp_path: Path, existing: str,
    ) -> None:
        rc = tmp_path / ".zshrc"
        if existing == "linked-startup":
            original = tmp_path / "managed-zshrc"
            original.write_text('export PATH="$HOME/bin:$PATH"\n')
            rc.symlink_to(original)
        elif existing == "existing-destination":
            rc.write_text('export PATH="$HOME/bin:$PATH"\n')
            target = tmp_path / ".config/shell/path/zshrc.sh"
            target.parent.mkdir(parents=True)
            target.write_text("# existing\n")
        else:
            rc.write_text('export PATH="$HOME/bin:$PATH"\n')
            (tmp_path / ".config").symlink_to(tmp_path)

        preview = self._preview(tmp_path, ".zshrc", "1")

        assert preview.returncode != 0
        assert preview.stdout == ""

    def _preview(self, home: Path, startup: str, lines: str) -> subprocess.CompletedProcess[str]:
        script = SHELL_CONFIG.parents[1] / "scripts/migrate-shell-path.py"
        return subprocess.run(
            [sys.executable, str(script), startup, lines],
            env={"HOME": str(home), "PATH": "/usr/bin:/bin"},
            capture_output=True, text=True, check=False, timeout=10,
        )


class TestShellStartup:
    def test_zsh_loads_shell_common_once(self, tmp_path: Path) -> None:
        result = run_shell(
            tmp_path,
            "zsh",
            'printf "%s\\n" "$common_loads"',
            before="printf '%s\\n' '(( ++common_loads ))' > \"$HOME/.shell_common\"",
        )
        assert result.stdout == "1\n"

    @pytest.mark.parametrize("startup", ["zprofile", "zshrc"])
    @pytest.mark.parametrize("kiri_entry", ["missing", "directory", "executable"])
    def test_zsh_adds_kiri_as_a_fallback_when_installed(
        self, tmp_path: Path, startup: str, kiri_entry: str,
    ) -> None:
        home = tmp_path / "home"
        kiri_bin = home / ".kiri/bin"
        kiri_bin.mkdir(parents=True)
        if kiri_entry == "directory":
            (kiri_bin / "kiri").mkdir()
        elif kiri_entry == "executable":
            write_command(tmp_path, "kiri-stub", "exit 0")
            (kiri_bin / "kiri").symlink_to(tmp_path / "bin/kiri-stub")

        write_command(tmp_path, "docker", "exit 0")
        rc = home / f".{startup}"
        rc.symlink_to(SHELL_CONFIG / "zsh" / startup)
        result = run_shell(
            tmp_path,
            "zsh",
            'command -v docker; printf "%s\\n" "${path[@]}"',
            interactive=startup == "zshrc",
            source=rc,
            source_count=2,
        )
        expected = [tmp_path / "bin/docker", tmp_path / "bin", tmp_path / "system-bin"]
        if kiri_entry == "executable":
            expected.append(kiri_bin)
        assert result.stdout.splitlines() == [str(path) for path in expected]

    def test_zsh_login_preserves_docker_added_by_interactive_local_config(
        self, tmp_path: Path,
    ) -> None:
        home = tmp_path / "home"
        kiri_bin = home / ".kiri/bin"
        kiri_bin.mkdir(parents=True)
        write_command(tmp_path, "kiri-stub", "exit 0")
        stub = tmp_path / "bin/kiri-stub"
        (kiri_bin / "kiri").symlink_to(stub)
        (kiri_bin / "docker").symlink_to(stub)
        local_bin = tmp_path / "local-bin"
        local_bin.mkdir()
        local_docker = local_bin / "docker"
        local_docker.symlink_to(stub)
        (home / ".zprofile").symlink_to(SHELL_CONFIG / "zsh/zprofile")
        (home / ".zshrc.local").write_text('export PATH="$PATH:$LOCAL_BIN"\n')

        result = run_shell(
            tmp_path,
            "zsh",
            'command -v docker; printf "%s\\n" "${path[-1]}"',
            before='source "$HOME/.zprofile" || exit $?',
            environment={"LOCAL_BIN": str(local_bin)},
        )
        assert result.stdout.splitlines() == [str(local_docker), str(kiri_bin)]

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

    @pytest.mark.parametrize(
        ("shell", "strict_supported"),
        [
            pytest.param("bash", True, id="bash-strict"),
            pytest.param("bash", False, id="bash-retry"),
            pytest.param("zsh", True, id="zsh"),
        ],
    )
    def test_prompt_config_precedes_named_theme_and_preserves_argument_boundaries(
        self,
        tmp_path: Path,
        shell: str,
        strict_supported: bool,
    ) -> None:
        local_themes = tmp_path / "home/.poshthemes"
        local_themes.mkdir(parents=True)
        (local_themes / "local.omp.json").write_text("{}")
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
            shell,
            'printf "%s %s\\n" "$DOTFILES_INITIALIZED" "${DOTFILES_FAILED_OUTPUT-unset}"',
            environment={
                "OH_MY_POSH_CONFIG": config,
                "OH_MY_POSH_THEME": "local.omp.json",
                "TEST_ARGUMENTS": str(log),
                "STRICT_SUPPORTED": "yes" if strict_supported else "no",
            },
        )
        assert result.stdout == "yes unset\n"
        expected = ["init", shell, "--config", config]
        if shell == "bash":
            strict = ["init", shell, "--strict", "--config", config]
            expected = strict if strict_supported else strict + expected
        assert log.read_text().splitlines() == expected

    def test_zsh_keeps_the_prezto_prompt_with_an_explicit_posh_config(self, tmp_path: Path) -> None:
        prezto = tmp_path / "home/.zprezto"
        prezto.mkdir(parents=True)
        (prezto / "init.zsh").write_text("PROMPT='prezto> '\n")
        write_command(tmp_path, "oh-my-posh", "echo DOTFILES_INITIALIZED=yes")

        result = run_shell(
            tmp_path,
            "zsh",
            'printf "%s\\n%s\\n" "$PROMPT" "${DOTFILES_INITIALIZED-unset}"',
            environment={"OH_MY_POSH_CONFIG": str(tmp_path / "shared theme.omp.json")},
        )
        assert result.stdout == "prezto> \nunset\n"

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
