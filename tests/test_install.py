#!/usr/bin/env python3
"""install.sh テスト — uninstall 時の stale リンク削除・空ディレクトリ集約

テスト構成:
  - TestIntegration*: 実リポジトリ (/workspace) で install.sh を実際に実行
  - TestUninstallStaleLinks, TestEmptyDir*, TestNested*, TestRoundTrip:
    疑似リポジトリで個別機能をテスト
"""

import os
import re
import subprocess
import tomllib
from pathlib import Path

INSTALL_SH = Path(__file__).resolve().parent.parent / "install.sh"
REPO_ROOT = INSTALL_SH.parent
STOW_INSTALL_SH = REPO_ROOT / "scripts" / "stow-install.sh"


def _run_install_sh(
    dotfiles: Path, home: Path, *, uninstall: bool = False
) -> subprocess.CompletedProcess[str]:
    """install.sh を指定 HOME で実行"""
    env = os.environ.copy()
    env["HOME"] = str(home)

    cmd = ["sh", str(dotfiles / "install.sh"), "-f"]
    if uninstall:
        cmd.insert(-1, "-u")  # -u -f の順

    return subprocess.run(
        cmd, cwd=str(dotfiles), env=env, capture_output=True, text=True, timeout=30
    )


def _create_fake_stow(tmp_path: Path) -> tuple[Path, Path]:
    fake_bin = tmp_path / "bin"
    log = tmp_path / "stow-args.log"
    fake_bin.mkdir()
    fake_stow = fake_bin / "stow"
    fake_stow.write_text(
        "#!/bin/sh\n"
        "printf '%s\\n' \"$*\" > \"$STOW_LOG\"\n",
        encoding="utf-8",
    )
    fake_stow.chmod(0o755)
    return fake_bin, log


def _run_stow_install_script(
    repo: Path, home: Path, package_name: str, env: dict[str, str], *extra_args: str
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            "/bin/sh",
            str(STOW_INSTALL_SH),
            "--repo",
            str(repo),
            "--target",
            str(home),
            "--package",
            package_name,
            *extra_args,
        ],
        cwd=str(REPO_ROOT),
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )


def _symlink_target_path(link: Path) -> Path:
    target = link.readlink()
    if target.is_absolute():
        return target
    return Path(os.path.abspath(link.parent / target))


def _has_generated_stow_ancestor(link: Path, generated: Path) -> bool:
    candidate = link
    while True:
        if candidate.is_symlink():
            tail = link.relative_to(candidate)
            expected = generated
            for _ in tail.parts:
                expected = expected.parent
            if _symlink_target_path(candidate) == expected:
                return True

        if candidate.parent == candidate:
            return False
        candidate = candidate.parent


def _assert_generated_stow_link(link: Path, generated: Path, source: Path) -> None:
    assert generated.is_symlink()
    assert generated.resolve() == source
    assert link.is_symlink()
    assert link.resolve() == source
    assert _has_generated_stow_ancestor(link, generated)


def _assert_codex_core_links(codex_dir: Path) -> None:
    assert (codex_dir / "AGENTS.md").is_symlink()
    assert _symlink_target_path(codex_dir / "AGENTS.md") == (
        REPO_ROOT / ".stow-work" / "codex" / ".codex" / "AGENTS.md"
    )
    assert (codex_dir / "SUBAGENTS.md").is_symlink()
    assert _symlink_target_path(codex_dir / "SUBAGENTS.md") == (
        REPO_ROOT / ".stow-work" / "codex" / ".codex" / "SUBAGENTS.md"
    )
    assert (codex_dir / "agents" / "code_reviewer.toml").is_symlink()


def _assert_codex_bin_links(codex_dir: Path) -> None:
    _assert_generated_stow_link(
        codex_dir / "bin" / "model-context.sh",
        REPO_ROOT / ".stow-work" / "codex" / ".codex" / "bin" / "model-context.sh",
        REPO_ROOT / "codex" / "bin" / "model-context.sh",
    )


def _assert_codex_common_links(codex_dir: Path) -> None:
    checklist = codex_dir / "agents" / "qa-nightmare" / "checklists" / "auth-bypass.md"
    _assert_generated_stow_link(
        checklist,
        REPO_ROOT
        / ".stow-work"
        / "codex"
        / ".codex"
        / "agents"
        / "qa-nightmare"
        / "checklists"
        / "auth-bypass.md",
        REPO_ROOT / "common" / "qa-nightmare" / "checklists" / "auth-bypass.md",
    )
    assert (codex_dir / "hooks").is_dir()
    destructive_hook = codex_dir / "hooks" / "destructive-command-block.sh"
    assert destructive_hook.is_symlink()
    assert destructive_hook.resolve() == (
        REPO_ROOT / "common" / "hooks" / "destructive-command-block.sh"
    )


def _assert_codex_rule_links(codex_dir: Path) -> None:
    assert (codex_dir / "rules" / "coding-conventions.md").is_symlink()
    assert (codex_dir / "rules" / "natural-japanese.md").is_symlink()


# ---------------------------------------------------------------------------
# 統合テスト: 実リポジトリで install.sh を実行
# ---------------------------------------------------------------------------


class TestCodexAgentDefinitions:
    """Codex custom agent 定義の基本 schema を検証するテスト"""

    REQUIRED_KEYS = ("name", "description", "developer_instructions")

    def _agent_names(self) -> set[str]:
        agent_files = sorted((REPO_ROOT / "codex" / "agents").glob("*.toml"))
        return {
            tomllib.loads(agent_file.read_text(encoding="utf-8"))["name"]
            for agent_file in agent_files
        }

    def test_agent_toml_files_are_valid(self) -> None:
        """codex/agents/*.toml が Codex custom agent の必須キーを満たす"""
        agent_files = sorted((REPO_ROOT / "codex" / "agents").glob("*.toml"))
        assert agent_files, "codex/agents should contain custom agent TOML files"

        for agent_file in agent_files:
            data = tomllib.loads(agent_file.read_text(encoding="utf-8"))
            for key in self.REQUIRED_KEYS:
                assert isinstance(data.get(key), str), (
                    f"{agent_file}: {key} must be a string"
                )
                assert data[key].strip(), f"{agent_file}: {key} must not be empty"
            assert data["name"] == agent_file.stem, (
                f"{agent_file}: name should match file stem"
            )

    def test_skill_subagent_type_references_existing_agents(self) -> None:
        """Codex skill 内の subagent_type 指定が実在する agent 名を参照する"""
        agent_names = self._agent_names()
        skill_files = [
            REPO_ROOT / "codex" / "skills" / "tdd" / "SKILL.md",
        ]

        for skill_file in skill_files:
            content = skill_file.read_text(encoding="utf-8")
            for subagent_type in re.findall(r"subagent_type:\s*([A-Za-z0-9_-]+)", content):
                assert subagent_type in agent_names, (
                    f"{skill_file}: subagent_type {subagent_type!r} must match a "
                    "codex/agents/*.toml name"
                )


class TestCodexConfigTemplate:
    """Codex config template が共有可能な内容だけを持つことを検証するテスト"""

    TEMPLATE = REPO_ROOT / "codex" / "config.toml.template"

    def test_config_template_is_valid_toml_with_inline_hooks(self) -> None:
        """config.toml.template が inline hook と plugin feature を含む"""
        content = self.TEMPLATE.read_text(encoding="utf-8")
        data = tomllib.loads(content)

        assert data["model"] == "gpt-5.5"
        assert "hooks = true" in content
        assert data["features"]["plugins"] is True
        assert "mcp_servers" not in data
        assert (
            data["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
            == "$HOME/.codex/hooks/hook-dispatcher.sh pre-tool-use"
        )

    def test_config_template_excludes_local_state_and_secrets(self) -> None:
        """config.toml.template に環境固有 state や secret 実値を含めない"""
        content = self.TEMPLATE.read_text(encoding="utf-8")

        forbidden_fragments = (
            "[hooks.state",
            'status = "trusted"',
            "trusted_hash",
            "bearer_token =",
            "/home/okayasu/",
        )
        for fragment in forbidden_fragments:
            assert fragment not in content


class TestRuleDistribution:
    """Claude/Codex の常時 rule 配布境界を検証するテスト"""

    def test_natural_japanese_is_rule_not_stale_codex_skill(self) -> None:
        """natural-japanese は skill ではなく Claude/Codex 両方の rule として配布される"""
        claude_global = (REPO_ROOT / "claude" / "CLAUDE.md").read_text(encoding="utf-8")
        codex_index = (REPO_ROOT / "codex" / "rules" / "RULES_INDEX.md").read_text(
            encoding="utf-8"
        )
        codex_bundle = (REPO_ROOT / "codex" / "rules" / "RULES_BUNDLE.md").read_text(
            encoding="utf-8"
        )

        assert (REPO_ROOT / "claude" / "rules" / "natural-japanese.md").is_file()
        assert "@'$HOME/.claude/rules/natural-japanese.md'" in claude_global
        assert (REPO_ROOT / "codex" / "rules" / "natural-japanese.md").is_file()
        assert "`codex/rules/natural-japanese.md`" in codex_index
        assert "## Source: `codex/rules/natural-japanese.md`" in codex_bundle
        assert not (
            REPO_ROOT / "codex" / "skills" / "natural-japanese" / "SKILL.md"
        ).exists()
        assert not (
            REPO_ROOT / "codex" / "skills" / "natural-japanese" / "agents" / "openai.yaml"
        ).exists()

    def test_plan_and_review_is_ported_to_codex_skill(self) -> None:
        """Claude に追加した plan-and-review は Codex skill としても port される"""
        skill_path = REPO_ROOT / "codex" / "skills" / "plan-and-review" / "SKILL.md"
        content = skill_path.read_text(encoding="utf-8")

        assert "name: plan-and-review" in content
        assert "codex_port_source: claude/skills/plan-and-review/SKILL.md" in content
        assert "Codex/Codex" not in content
        assert "| task 種別 / 役割 | 複雑度シグナル | Driver | Worker |" in content
        assert "task ごとの commit" not in content
        assert "Step 5: commit" not in content
        assert "subagent が TDD で実装・テスト・自己レビューする" in content

    def test_rule_bundle_header_has_separate_description_line(self) -> None:
        """RULES_BUNDLE の見出しと説明文は同一行に潰さない"""
        bundle = REPO_ROOT / "codex" / "rules" / "RULES_BUNDLE.md"
        lines = bundle.read_text(encoding="utf-8").splitlines()

        assert lines[0] == "# Codex Rules Bundle"
        assert lines[1] == ""
        assert lines[2].startswith("このファイルは hook/context injection 用")


class TestScriptCli:
    """scripts/*.py の CLI 基本動作を検証するテスト"""

    def test_patch_codex_rule_enforcement_help_exits_successfully(self) -> None:
        """patch-codex-rule-enforcement.py --help は repo path 扱いされず正常終了する"""
        result = subprocess.run(
            [
                "python3",
                str(REPO_ROOT / "scripts" / "patch-codex-rule-enforcement.py"),
                "--help",
            ],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, result.stderr
        assert "usage: patch-codex-rule-enforcement.py" in result.stdout
        assert "not a dotfile-work repo root" not in result.stderr

    def test_port_claude_assets_dry_run_keeps_home_literal(self) -> None:
        """port-claude-assets-to-codex.py は `${HOME}` を未定義変数として評価しない"""
        result = subprocess.run(
            [
                "python3",
                str(REPO_ROOT / "scripts" / "port-claude-assets-to-codex.py"),
                "--repo",
                str(REPO_ROOT),
                "--dry-run",
                "--overwrite",
            ],
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, result.stderr
        assert "NameError: name 'HOME' is not defined" not in result.stderr
        assert "Claude -> Codex port complete" in result.stdout


class TestStowInstallScript:
    """GNU stow 移行用の薄い入口を検証するテスト"""

    def test_script_is_executable(self) -> None:
        """stow install script は直接実行できる"""
        assert os.access(STOW_INSTALL_SH, os.X_OK)

    def test_missing_stow_exits_with_clear_error(self, tmp_path: Path) -> None:
        """stow が無い環境では fallback せず導入案内を出して終了する"""
        home = tmp_path / "home"
        home.mkdir()
        empty_bin = tmp_path / "empty-bin"
        empty_bin.mkdir()
        env = os.environ.copy()
        env["PATH"] = str(empty_bin)

        result = _run_stow_install_script(REPO_ROOT, home, "claude", env, "--dry-run")

        assert result.returncode == 127
        assert "GNU stow is required" in result.stderr
        assert "brew install stow" in result.stderr
        assert "apt install stow" in result.stderr

    def test_dry_run_invokes_stow_for_selected_package(self, tmp_path: Path) -> None:
        """dry-run は stow を変更なしモードで選択 package に対して呼び出す"""
        repo = tmp_path / "repo"
        home = tmp_path / "home"
        (repo / "stow" / "claude" / ".claude").mkdir(parents=True)
        home.mkdir()
        fake_bin, log = _create_fake_stow(tmp_path)
        env = os.environ.copy()
        env["PATH"] = f"{fake_bin}{os.pathsep}{env['PATH']}"
        env["STOW_LOG"] = str(log)

        result = _run_stow_install_script(repo, home, "claude", env, "--dry-run")

        assert result.returncode == 0, result.stderr
        args = log.read_text(encoding="utf-8").split()
        assert "--no" in args
        assert "--verbose" in args
        assert args[args.index("--dir") + 1] == str(repo / "stow")
        assert args[args.index("--target") + 1] == str(home)
        assert args[-1] == "claude"

    def test_link_materializes_generated_package(self, tmp_path: Path) -> None:
        """--link は install 時生成 package を作り、stow に渡す"""
        repo = tmp_path / "repo"
        home = tmp_path / "home"
        source = repo / "config" / "vim" / ".vimrc"
        source.parent.mkdir(parents=True)
        source.write_text("set number\n", encoding="utf-8")
        home.mkdir()
        fake_bin, log = _create_fake_stow(tmp_path)
        env = os.environ.copy()
        env["PATH"] = f"{fake_bin}{os.pathsep}{env['PATH']}"
        env["STOW_LOG"] = str(log)

        result = _run_stow_install_script(
            repo,
            home,
            "vim",
            env,
            "--dry-run",
            "--link",
            "config/vim/.vimrc:.vimrc",
        )

        generated = repo / ".stow-work" / "vim" / ".vimrc"
        assert result.returncode == 0, result.stderr
        assert generated.is_symlink()
        assert generated.resolve() == source
        args = log.read_text(encoding="utf-8").split()
        assert args[args.index("--dir") + 1] == str(repo / ".stow-work")
        assert args[-1] == "vim"

    def test_link_restows_existing_generated_package(self, tmp_path: Path) -> None:
        """生成 package の内容変更時は外部 symlink に触れず旧リンクを張り直す"""
        repo = tmp_path / "repo"
        home = tmp_path / "home"
        external = tmp_path / "external"
        old_source = repo / "config" / "old.conf"
        new_source = repo / "config" / "new.conf"
        old_source.parent.mkdir(parents=True)
        old_source.write_text("old\n", encoding="utf-8")
        new_source.write_text("new\n", encoding="utf-8")
        home.mkdir()
        external.mkdir()
        (home / ".aws").symlink_to(external)
        env = os.environ.copy()

        first = _run_stow_install_script(
            repo,
            home,
            "demo",
            env,
            "--link",
            "config/old.conf:.old-conf",
        )
        second = _run_stow_install_script(
            repo,
            home,
            "demo",
            env,
            "--link",
            "config/new.conf:.new-conf",
        )

        assert first.returncode == 0, first.stderr
        assert second.returncode == 0, second.stderr
        assert "BUG in find_stowed_path" not in second.stderr
        assert not (home / ".old-conf").is_symlink()
        assert (home / ".new-conf").is_symlink()

    def test_link_restows_existing_folded_generated_package(
        self, tmp_path: Path
    ) -> None:
        """stow が折りたたんだ directory symlink も package 再生成時に外す"""
        repo = tmp_path / "repo"
        home = tmp_path / "home"
        attrs_source = repo / "config" / "git" / ".gitattributes"
        prompt_source = repo / "config" / "git" / ".git-prompt.sh"
        attrs_source.parent.mkdir(parents=True)
        attrs_source.write_text("*.sh text eol=lf\n", encoding="utf-8")
        prompt_source.write_text("__git_ps1\n", encoding="utf-8")
        home.mkdir()
        env = os.environ.copy()

        first = _run_stow_install_script(
            repo,
            home,
            "git",
            env,
            "--link",
            "config/git/.gitattributes:.config/git/attributes",
        )
        second = _run_stow_install_script(
            repo,
            home,
            "git",
            env,
            "--link",
            "config/git/.git-prompt.sh:.git-prompt.sh",
        )

        assert first.returncode == 0, first.stderr
        assert second.returncode == 0, second.stderr
        assert "BUG in find_stowed_path" not in second.stderr
        assert not (home / ".config").is_symlink()
        assert not (home / ".config" / "git" / "attributes").exists()
        assert (home / ".git-prompt.sh").is_symlink()

    def test_link_regenerates_package_when_manifest_matches_but_entries_are_stale(
        self, tmp_path: Path
    ) -> None:
        """manifest 一致でも package に古い entry が残れば再生成する"""
        repo = tmp_path / "repo"
        home = tmp_path / "home"
        git_dir = repo / "config" / "git"
        package_dir = repo / ".stow-work" / "git"
        manifest = repo / ".stow-work" / ".manifests" / "git.links"
        git_dir.mkdir(parents=True)
        home_git = home / ".config" / "git"
        home_git.mkdir(parents=True)

        sources = {
            "config/git/.git-completion.bash": git_dir / ".git-completion.bash",
            "config/git/.git-prompt.sh": git_dir / ".git-prompt.sh",
            "config/git/.gitattributes": git_dir / ".gitattributes",
            "config/git/.gitignore.common": git_dir / ".gitignore.common",
        }
        for source in sources.values():
            source.write_text(f"{source.name}\n", encoding="utf-8")

        link_specs = (
            "config/git/.git-completion.bash:.git-completion.bash",
            "config/git/.git-prompt.sh:.git-prompt.sh",
            "config/git/.git-prompt.sh:.config/git/.git-prompt.sh",
            "config/git/.gitattributes:.config/git/attributes",
        )

        def write_package_link(source: Path, dest: str) -> None:
            entry = package_dir / dest
            entry.parent.mkdir(parents=True, exist_ok=True)
            entry.symlink_to(os.path.relpath(source, start=entry.parent))

        for spec in link_specs:
            source_name, dest = spec.split(":", 1)
            write_package_link(sources[source_name], dest)
        write_package_link(sources["config/git/.gitignore.common"], ".config/git/ignore")
        write_package_link(
            sources["config/git/.gitignore.common"], ".config/git/ignore.bak"
        )
        manifest.parent.mkdir(parents=True)
        manifest.write_text("\n".join(link_specs) + "\n", encoding="utf-8")
        (home_git / "ignore").write_text("local ignore\n", encoding="utf-8")
        (home_git / "ignore.bak").write_text("local backup\n", encoding="utf-8")

        args = []
        for spec in link_specs:
            args.extend(("--link", spec))
        result = _run_stow_install_script(repo, home, "git", os.environ.copy(), *args)

        assert result.returncode == 0, result.stderr
        assert "would cause conflicts" not in result.stderr
        assert not (package_dir / ".config" / "git" / "ignore").exists()
        assert not (package_dir / ".config" / "git" / "ignore").is_symlink()
        assert not (package_dir / ".config" / "git" / "ignore.bak").exists()
        assert not (package_dir / ".config" / "git" / "ignore.bak").is_symlink()
        assert (home_git / "ignore").is_file()
        assert not (home_git / "ignore").is_symlink()
        assert (home_git / "ignore.bak").is_file()
        assert not (home_git / "ignore.bak").is_symlink()
        _assert_generated_stow_link(
            home / ".config" / "git" / "attributes",
            package_dir / ".config" / "git" / "attributes",
            sources["config/git/.gitattributes"],
        )

    def test_link_adopts_legacy_direct_symlink_before_stow(
        self, tmp_path: Path
    ) -> None:
        """旧方式の直接リンクは stow 実行前に外し、GNU stow の BUG 表示を避ける"""
        repo = tmp_path / "repo"
        home = tmp_path / "home"
        source = repo / "config" / "git" / ".gitconfig.common"
        source.parent.mkdir(parents=True)
        source.write_text("[include]\n", encoding="utf-8")
        home.mkdir()
        legacy_link = home / ".gitconfig.common"
        legacy_link.symlink_to(source)
        env = os.environ.copy()

        result = _run_stow_install_script(
            repo,
            home,
            "gitconfig",
            env,
            "--link",
            "config/git/.gitconfig.common:.gitconfig.common",
        )

        assert result.returncode == 0, result.stderr
        assert "BUG in find_stowed_path" not in result.stderr
        _assert_generated_stow_link(
            legacy_link,
            repo / ".stow-work" / "gitconfig" / ".gitconfig.common",
            source,
        )

    def test_rejects_generated_link_path_traversal(self, tmp_path: Path) -> None:
        """生成 package の link dest は repo 外へ抜けられない"""
        repo = tmp_path / "repo"
        home = tmp_path / "home"
        source = repo / "config" / "vim" / ".vimrc"
        source.parent.mkdir(parents=True)
        source.write_text("set number\n", encoding="utf-8")
        home.mkdir()
        fake_bin, log = _create_fake_stow(tmp_path)
        env = os.environ.copy()
        env["PATH"] = f"{fake_bin}{os.pathsep}{env['PATH']}"
        env["STOW_LOG"] = str(log)

        result = _run_stow_install_script(
            repo,
            home,
            "vim",
            env,
            "--link",
            "config/vim/.vimrc:../.vimrc",
        )

        assert result.returncode == 2
        assert "invalid generated link dest" in result.stderr
        assert not log.exists()

    def test_rejects_package_path_traversal(self, tmp_path: Path) -> None:
        """package 名は stow/ 配下の名前だけを受け取り、パス横断を拒否する"""
        repo = tmp_path / "repo"
        home = tmp_path / "home"
        (repo / "claude").mkdir(parents=True)
        home.mkdir()
        fake_bin, log = _create_fake_stow(tmp_path)
        env = os.environ.copy()
        env["PATH"] = str(fake_bin)
        env["STOW_LOG"] = str(log)

        result = _run_stow_install_script(repo, home, "../claude", env, "--dry-run")

        assert result.returncode == 2
        assert "invalid stow package" in result.stderr
        assert not log.exists()


class TestIntegrationInstallUninstall:
    """実リポジトリ構造で install.sh -f / -u -f を実行するテスト"""

    def test_install_succeeds(self, tmp_path: Path) -> None:
        """install.sh -f が正常終了する"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)
        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"

    def test_install_creates_shell_symlinks_from_generated_stow_package(
        self, tmp_path: Path
    ) -> None:
        """Shell フルセットは install 時生成 package 経由で配置される"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)

        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"
        _assert_generated_stow_link(
            home / ".bashrc",
            REPO_ROOT / ".stow-work" / "shell" / ".bashrc",
            REPO_ROOT / "config" / "shell" / "bash" / "bashrc",
        )
        _assert_generated_stow_link(
            home / ".bash_profile",
            REPO_ROOT / ".stow-work" / "shell" / ".bash_profile",
            REPO_ROOT / "config" / "shell" / "bash" / "bash_profile",
        )

    def test_install_creates_git_symlinks_from_generated_stow_package(
        self, tmp_path: Path
    ) -> None:
        """Git の単純 symlink は install 時生成 package 経由で配置される"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)

        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"
        _assert_generated_stow_link(
            home / ".git-completion.bash",
            REPO_ROOT / ".stow-work" / "git" / ".git-completion.bash",
            REPO_ROOT / "config" / "git" / ".git-completion.bash",
        )
        _assert_generated_stow_link(
            home / ".config" / "git" / "attributes",
            REPO_ROOT / ".stow-work" / "git" / ".config" / "git" / "attributes",
            REPO_ROOT / "config" / "git" / ".gitattributes",
        )

    def test_install_creates_gitconfig_file_and_variant_symlink(
        self, tmp_path: Path
    ) -> None:
        """gitconfig common は実体ファイル、variant は stow link で配置される"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)

        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"
        common = home / ".gitconfig.common"
        assert common.is_file()
        assert not common.is_symlink()
        assert common.read_text() == (
            REPO_ROOT / "config" / "git" / ".gitconfig.common"
        ).read_text()
        _assert_generated_stow_link(
            home / ".gitconfig",
            REPO_ROOT / ".stow-work" / "gitconfig" / ".gitconfig",
            REPO_ROOT / "config" / "git" / ".gitconfig.work",
        )

    def test_install_creates_vim_symlink_from_stow_package(
        self, tmp_path: Path
    ) -> None:
        """Vim 設定は install 時生成 package 経由で ~/.vimrc に配置される"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)
        vimrc = home / ".vimrc"

        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"
        generated = REPO_ROOT / ".stow-work" / "vim" / ".vimrc"
        assert generated.is_symlink()
        assert generated.resolve() == REPO_ROOT / "config" / "vim" / ".vimrc"
        assert vimrc.is_symlink()
        assert _symlink_target_path(vimrc) == generated

    def test_install_adopts_legacy_vim_symlink_to_stow_package(
        self, tmp_path: Path
    ) -> None:
        """旧 Vim 直リンクは install 時生成 package のリンクへ張り替える"""
        home = tmp_path / "home"
        home.mkdir()
        vimrc = home / ".vimrc"
        vimrc.symlink_to(REPO_ROOT / "config" / "vim" / ".vimrc")

        result = _run_install_sh(REPO_ROOT, home)

        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"
        assert vimrc.is_symlink()
        assert _symlink_target_path(vimrc) == REPO_ROOT / ".stow-work" / "vim" / ".vimrc"

    def test_install_creates_bin_symlinks_from_generated_stow_package(
        self, tmp_path: Path
    ) -> None:
        """bin/ 配下の CLI は install 時生成 package 経由で配置される"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)

        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"
        _assert_generated_stow_link(
            home / ".local" / "bin" / "git-new-feature",
            REPO_ROOT / ".stow-work" / "bin" / ".local" / "bin" / "git-new-feature",
            REPO_ROOT / "bin" / "git-new-feature",
        )

    def test_uninstall_succeeds(self, tmp_path: Path) -> None:
        """install → uninstall が正常終了する"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)
        result = _run_install_sh(REPO_ROOT, home, uninstall=True)
        assert result.returncode == 0, f"uninstall failed:\n{result.stdout}"

    def test_install_creates_claude_symlinks(self, tmp_path: Path) -> None:
        """install 後に ~/.claude/ 配下にシンボリックリンクが作られる"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)

        claude_dir = home / ".claude"
        assert claude_dir.is_dir()

        # 代表的なファイルの存在確認
        assert (claude_dir / "hooks").is_dir()
        destructive_hook = claude_dir / "hooks" / "destructive-command-block.sh"
        assert destructive_hook.is_symlink()
        assert destructive_hook.resolve() == (
            REPO_ROOT / "common" / "hooks" / "destructive-command-block.sh"
        )
        assert (claude_dir / "settings.json").is_symlink()
        assert _symlink_target_path(claude_dir / "settings.json") == (
            REPO_ROOT / ".stow-work" / "claude" / ".claude" / "settings.json"
        )
        assert (claude_dir / "CLAUDE.md").is_symlink()
        assert _symlink_target_path(claude_dir / "CLAUDE.md") == (
            REPO_ROOT / ".stow-work" / "claude" / ".claude" / "CLAUDE.md"
        )
        assert (claude_dir / "rules" / "natural-japanese.md").is_symlink()
        checklist = (
            claude_dir / "skills" / "qa-nightmare" / "checklists" / "auth-bypass.md"
        )
        _assert_generated_stow_link(
            checklist,
            REPO_ROOT
            / ".stow-work"
            / "claude"
            / ".claude"
            / "skills"
            / "qa-nightmare"
            / "checklists"
            / "auth-bypass.md",
            REPO_ROOT / "common" / "qa-nightmare" / "checklists" / "auth-bypass.md",
        )

    def test_install_creates_codex_symlinks(self, tmp_path: Path) -> None:
        """install 後に ~/.codex/ 配下に stow 管理リンクが作られる"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)
        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"

        codex_dir = home / ".codex"
        assert codex_dir.is_dir()

        _assert_codex_core_links(codex_dir)
        _assert_codex_bin_links(codex_dir)
        _assert_codex_common_links(codex_dir)
        _assert_codex_rule_links(codex_dir)

    def test_install_creates_codex_config_and_excludes_non_targets(
        self, tmp_path: Path
    ) -> None:
        """Codex config は通常ファイル生成し、除外対象は配置しない"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)
        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"

        codex_dir = home / ".codex"
        config_toml = codex_dir / "config.toml"
        assert config_toml.is_file()
        assert not config_toml.is_symlink()
        assert config_toml.read_text(encoding="utf-8") == (
            REPO_ROOT / "codex" / "config.toml.template"
        ).read_text(encoding="utf-8")
        assert not (codex_dir / "hooks.json").exists()
        assert not (codex_dir / "README.md").exists()
        assert not (codex_dir / "settings.json").exists()
        assert not (codex_dir / "skills" / "tdd" / "SKILL.md").exists()
        assert not (codex_dir / "skills" / "natural-japanese" / "SKILL.md").exists()
        assert not (home / ".agents" / "skills" / "tdd" / "SKILL.md").exists()

    def test_install_preserves_existing_codex_config(self, tmp_path: Path) -> None:
        """既存 ~/.codex/config.toml は install で上書きされない"""
        home = tmp_path / "home"
        config_toml = home / ".codex" / "config.toml"
        config_toml.parent.mkdir(parents=True)
        config_toml.write_text("model = \"local-only\"\n", encoding="utf-8")

        first_result = _run_install_sh(REPO_ROOT, home)
        second_result = _run_install_sh(REPO_ROOT, home)

        assert first_result.returncode == 0
        assert second_result.returncode == 0
        assert config_toml.read_text(encoding="utf-8") == "model = \"local-only\"\n"
        assert "既存の ~/.codex/config.toml は上書きしません" in first_result.stdout
        assert "既存の ~/.codex/config.toml は上書きしません" in second_result.stdout

    def test_codex_install_excludes_untracked_files(self, tmp_path: Path) -> None:
        """codex/ 配下の untracked file はallowlist形状でも配置されない"""
        home = tmp_path / "home"
        home.mkdir()
        scratch = REPO_ROOT / "codex" / "scratch.tmp"
        scratch_hook = REPO_ROOT / "codex" / "hooks" / "scratch-hook.sh"
        scratch.write_text("temporary", encoding="utf-8")
        scratch_hook.write_text("#!/bin/sh\n", encoding="utf-8")
        try:
            result = _run_install_sh(REPO_ROOT, home)
        finally:
            scratch.unlink(missing_ok=True)
            scratch_hook.unlink(missing_ok=True)

        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"
        assert not (home / ".codex" / "scratch.tmp").exists()
        assert not (home / ".codex" / "hooks" / "scratch-hook.sh").exists()

    def test_uninstall_removes_claude_symlinks(self, tmp_path: Path) -> None:
        """uninstall 後に dotfiles 由来のシンボリックリンクが削除される"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)

        # install 後にリンクが存在することを前提確認
        assert (home / ".claude" / "settings.json").is_symlink()
        destructive_hook = home / ".claude" / "hooks" / "destructive-command-block.sh"
        assert destructive_hook.is_symlink()
        checklist = (
            home
            / ".claude"
            / "skills"
            / "qa-nightmare"
            / "checklists"
            / "auth-bypass.md"
        )
        assert checklist.is_symlink()

        _run_install_sh(REPO_ROOT, home, uninstall=True)
        assert not (home / ".claude" / "settings.json").exists()
        assert not destructive_hook.exists()
        assert not checklist.exists()

    def test_uninstall_removes_codex_symlinks(self, tmp_path: Path) -> None:
        """uninstall 後に dotfiles 由来のCodexリンクが削除される"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)

        config_toml = home / ".codex" / "config.toml"
        assert config_toml.is_file()
        assert not (home / ".codex" / "hooks.json").exists()
        assert (home / ".codex" / "agents" / "code_reviewer.toml").is_symlink()
        destructive_hook = home / ".codex" / "hooks" / "destructive-command-block.sh"
        assert destructive_hook.is_symlink()
        checklist = (
            home
            / ".codex"
            / "agents"
            / "qa-nightmare"
            / "checklists"
            / "auth-bypass.md"
        )
        assert checklist.is_symlink()
        assert not (home / ".agents" / "skills" / "tdd" / "SKILL.md").exists()

        _run_install_sh(REPO_ROOT, home, uninstall=True)
        assert config_toml.is_file()
        assert not (home / ".codex" / "agents" / "code_reviewer.toml").exists()
        assert not destructive_hook.exists()
        assert not checklist.exists()

    def test_uninstall_removes_legacy_common_hooks(self, tmp_path: Path) -> None:
        """common化前の hook リンクが uninstall で削除される"""
        home = tmp_path / "home"
        claude_hooks = home / ".claude" / "hooks"
        codex_hooks = home / ".codex" / "hooks"
        claude_hooks.mkdir(parents=True)
        codex_hooks.mkdir(parents=True)

        claude_legacy = claude_hooks / "destructive-command-block.sh"
        codex_legacy = codex_hooks / "destructive-command-block.sh"
        claude_legacy.symlink_to(
            REPO_ROOT / "claude" / "hooks" / "destructive-command-block.sh"
        )
        codex_legacy.symlink_to(
            REPO_ROOT / "codex" / "hooks" / "destructive-command-block.sh"
        )

        _run_install_sh(REPO_ROOT, home, uninstall=True)

        assert not claude_legacy.is_symlink()
        assert not codex_legacy.is_symlink()

    def test_uninstall_removes_legacy_qa_nightmare_checklists(
        self, tmp_path: Path
    ) -> None:
        """common化前の qa-nightmare checklist リンクが uninstall で削除される"""
        home = tmp_path / "home"
        claude_checklists = home / ".claude" / "skills" / "qa-nightmare" / "checklists"
        codex_checklists = home / ".codex" / "agents" / "qa-nightmare" / "checklists"
        claude_checklists.mkdir(parents=True)
        codex_checklists.mkdir(parents=True)

        claude_legacy = claude_checklists / "auth-bypass.md"
        codex_legacy = codex_checklists / "auth-bypass.md"
        claude_legacy.symlink_to(
            REPO_ROOT
            / "claude"
            / "skills"
            / "qa-nightmare"
            / "checklists"
            / "auth-bypass.md"
        )
        codex_legacy.symlink_to(
            REPO_ROOT
            / "codex"
            / "agents"
            / "qa-nightmare"
            / "checklists"
            / "auth-bypass.md"
        )

        _run_install_sh(REPO_ROOT, home, uninstall=True)

        assert not claude_legacy.is_symlink()
        assert not codex_legacy.is_symlink()

    def test_uninstall_empty_dir_summary(self, tmp_path: Path) -> None:
        """uninstall の空ディレクトリ削除メッセージがカテゴリごとの1行サマリー形式"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)
        result = _run_install_sh(REPO_ROOT, home, uninstall=True)

        summary_lines = [
            l for l in result.stdout.splitlines() if "空ディレクトリ削除" in l
        ]
        claude_lines = [l for l in summary_lines if ".claude/ 配下" in l]
        codex_lines = [l for l in summary_lines if ".codex/ 配下" in l]
        assert len(claude_lines) == 1, f"Claudeサマリーは1行であるべき: {summary_lines}"
        assert len(codex_lines) == 1, f"Codexサマリーは1行であるべき: {summary_lines}"

    def test_uninstall_without_prior_install(self, tmp_path: Path) -> None:
        """install していない状態で uninstall してもクラッシュしない

        既知: set -e + `[ $COUNT_ERROR -gt 0 ] && exit 1` で
        COUNT_ERROR=0 でも exit 1 になる (L1339)。
        ここではクラッシュ (stderr にトレース) がないことを検証。
        """
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home, uninstall=True)
        # set -e の既知問題で exit 1 になるが、エラーメッセージは出ない
        assert "エラー" not in result.stdout
        assert result.stderr == ""

    def test_uninstall_stale_then_reinstall_clean(self, tmp_path: Path) -> None:
        """install → stale作成 → uninstall → install で stale メッセージなし"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)

        # stale リンクを作成
        hooks_dir = home / ".claude" / "hooks"
        stale = hooks_dir / "old-hook-from-past.sh"
        stale.symlink_to(REPO_ROOT / "claude" / "hooks" / "nonexistent.sh")

        # uninstall で stale が消える
        _run_install_sh(REPO_ROOT, home, uninstall=True)
        assert not stale.is_symlink(), "stale link should be cleaned on uninstall"

        # reinstall で stale メッセージが出ない
        result = _run_install_sh(REPO_ROOT, home)
        assert result.returncode == 0
        assert "古い" not in result.stdout


# ---------------------------------------------------------------------------
# ヘルパー (疑似リポジトリ用)
# ---------------------------------------------------------------------------


def _setup_dotfiles_repo(tmp_path: Path) -> Path:
    """git管理された疑似 dotfiles リポジトリを作成"""
    dotfiles = tmp_path / "dotfiles"
    claude = dotfiles / "claude"

    # claude/ 配下のファイル構造
    files = {
        "hooks/hook-a.sh": "#!/bin/sh\n# hook-a",
        "hooks/hook-b.sh": "#!/bin/sh\n# hook-b",
        "skills/my-skill/SKILL.md": "# my-skill",
        "rules/my-rule.md": "# my-rule",
        "settings.json": "{}",
    }
    for rel, content in files.items():
        p = claude / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)

    # install.sh をコピー (DOTFILES_DIR がここを指すように)
    import shutil

    shutil.copy2(INSTALL_SH, dotfiles / "install.sh")
    scripts_dir = dotfiles / "scripts"
    scripts_dir.mkdir()
    shutil.copy2(STOW_INSTALL_SH, scripts_dir / "stow-install.sh")

    # git 初期化 + コミット
    subprocess.run(["git", "init", str(dotfiles)], check=True, capture_output=True)
    subprocess.run(
        ["git", "-C", str(dotfiles), "add", "."], check=True, capture_output=True
    )
    subprocess.run(
        ["git", "-C", str(dotfiles), "commit", "-m", "init"],
        check=True,
        capture_output=True,
    )
    return dotfiles


def _simulate_install(dotfiles: Path, home: Path) -> None:
    """install.sh が作る claude 用シンボリックリンク構造を再現"""
    claude_home = home / ".claude"

    # git ls-files でソースファイルを取得
    result = subprocess.run(
        ["git", "-C", str(dotfiles), "ls-files", "claude/"],
        capture_output=True,
        text=True,
        check=True,
    )

    for line in result.stdout.strip().splitlines():
        if not line:
            continue
        relative = line.removeprefix("claude/")
        src = dotfiles / line
        dest = claude_home / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists() or dest.is_symlink():
            dest.unlink()
        dest.symlink_to(src)


def _run_uninstall(dotfiles: Path, home: Path) -> subprocess.CompletedProcess[str]:
    """install.sh -u -f を実行 (Claude設定のuninstallのみテスト対象)"""
    env = os.environ.copy()
    env["HOME"] = str(home)

    return subprocess.run(
        ["sh", str(dotfiles / "install.sh"), "-u", "-f"],
        cwd=str(dotfiles),
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )


# ---------------------------------------------------------------------------
# テスト: stale リンクの uninstall 時クリーンアップ
# ---------------------------------------------------------------------------


class TestUninstallStaleLinks:
    """uninstall 時に git 管理外の旧リンクがクリーンアップされること"""

    def test_stale_hook_removed_on_uninstall(self, tmp_path: Path) -> None:
        """git 管理外の旧 hook リンクが uninstall で削除される"""
        dotfiles = _setup_dotfiles_repo(tmp_path)
        home = tmp_path / "home"
        home.mkdir()
        _simulate_install(dotfiles, home)

        hooks_dir = home / ".claude" / "hooks"
        assert hooks_dir.is_dir()

        # git 管理外の stale リンク (dotfiles 内の存在しないファイルを指す)
        stale = hooks_dir / "old-removed-hook.sh"
        stale.symlink_to(dotfiles / "claude" / "hooks" / "old-removed-hook.sh")
        assert stale.is_symlink()
        assert not stale.exists()  # dangling

        _run_uninstall(dotfiles, home)
        # uninstall は config/shell 等がなくてもエラー終了しないことを確認しないが
        # stale リンクが消えることだけ検証
        assert not stale.is_symlink(), "stale symlink should be removed on uninstall"

    def test_stale_skill_dir_removed_on_uninstall(self, tmp_path: Path) -> None:
        """git 管理外の旧 skill ディレクトリが uninstall で削除される"""
        dotfiles = _setup_dotfiles_repo(tmp_path)
        home = tmp_path / "home"
        home.mkdir()
        _simulate_install(dotfiles, home)

        skills_dir = home / ".claude" / "skills"
        old_skill = skills_dir / "old-skill"
        old_skill.mkdir(exist_ok=True)
        # dotfiles 内の存在しないファイルへの dangling リンク
        (old_skill / "SKILL.md").symlink_to(
            dotfiles / "claude" / "skills" / "old-skill" / "SKILL.md"
        )

        _run_uninstall(dotfiles, home)
        assert not old_skill.exists(), "stale skill dir should be removed on uninstall"

    def test_non_stale_link_preserved_on_uninstall(self, tmp_path: Path) -> None:
        """dotfiles 由来でないリンクは uninstall で削除されない"""
        dotfiles = _setup_dotfiles_repo(tmp_path)
        home = tmp_path / "home"
        home.mkdir()
        _simulate_install(dotfiles, home)

        hooks_dir = home / ".claude" / "hooks"
        # dotfiles 外を指すリンク (ユーザーが手動追加した想定)
        external_target = tmp_path / "external-hook.sh"
        external_target.write_text("#!/bin/sh\n")
        user_hook = hooks_dir / "user-custom-hook.sh"
        user_hook.symlink_to(external_target)

        _run_uninstall(dotfiles, home)
        assert user_hook.is_symlink(), "non-dotfiles link should be preserved"


# ---------------------------------------------------------------------------
# テスト: 空ディレクトリ削除のサマリー表示
# ---------------------------------------------------------------------------


class TestEmptyDirSummary:
    """空ディレクトリ削除が1行サマリーで表示されること"""

    def test_summary_message_format(self, tmp_path: Path) -> None:
        """削除メッセージが '空ディレクトリ削除: .claude/ 配下 N 件' 形式"""
        dotfiles = _setup_dotfiles_repo(tmp_path)
        home = tmp_path / "home"
        home.mkdir()
        _simulate_install(dotfiles, home)

        result = _run_uninstall(dotfiles, home)
        output = result.stdout

        assert "空ディレクトリ削除: .claude/ 配下" in output
        assert "件" in output

    def test_no_per_directory_message(self, tmp_path: Path) -> None:
        """個別ディレクトリパスのメッセージが出ないこと (旧形式の排除)"""
        dotfiles = _setup_dotfiles_repo(tmp_path)
        home = tmp_path / "home"
        home.mkdir()
        _simulate_install(dotfiles, home)

        result = _run_uninstall(dotfiles, home)
        for line in result.stdout.splitlines():
            if "空ディレクトリ削除" in line:
                assert ".claude/ 配下" in line, (
                    f"個別パス表示の旧形式が残っている: {line}"
                )

    def test_no_message_when_dirs_not_empty(self, tmp_path: Path) -> None:
        """空でないディレクトリのみの場合、サマリーメッセージが出ないこと"""
        dotfiles = _setup_dotfiles_repo(tmp_path)
        home = tmp_path / "home"
        home.mkdir()
        _simulate_install(dotfiles, home)

        # 全サブディレクトリにファイルを残す
        claude_dir = home / ".claude"
        for d in claude_dir.rglob("*"):
            if d.is_dir():
                keep = d / ".keep"
                if not keep.exists():
                    keep.write_text("")

        result = _run_uninstall(dotfiles, home)
        assert "空ディレクトリ削除" not in result.stdout


# ---------------------------------------------------------------------------
# テスト: ネストした空ディレクトリの正しい削除
# ---------------------------------------------------------------------------


class TestNestedEmptyDirs:
    """ネストした空ディレクトリが全て削除されること"""

    def test_nested_empty_dirs_all_removed(self, tmp_path: Path) -> None:
        """skills/my-skill/ → skills/ のように連鎖的に空ディレクトリが削除される"""
        dotfiles = _setup_dotfiles_repo(tmp_path)
        home = tmp_path / "home"
        home.mkdir()
        _simulate_install(dotfiles, home)

        skills_dir = home / ".claude" / "skills"
        assert skills_dir.is_dir()

        _run_uninstall(dotfiles, home)

        # skills/my-skill/ 内のリンクが消え、my-skill/ も skills/ も空になり削除
        assert not skills_dir.exists(), "empty skills dir should be removed"

    def test_mixed_empty_and_nonempty_sibling(self, tmp_path: Path) -> None:
        """空の兄弟ディレクトリのみ削除され、非空は保持"""
        dotfiles = _setup_dotfiles_repo(tmp_path)
        home = tmp_path / "home"
        home.mkdir()
        _simulate_install(dotfiles, home)

        skills_dir = home / ".claude" / "skills"
        # ユーザーが手動追加したスキル (非 dotfiles)
        user_skill = skills_dir / "user-skill"
        user_skill.mkdir(parents=True, exist_ok=True)
        (user_skill / "README.md").write_text("user content")

        _run_uninstall(dotfiles, home)

        assert user_skill.is_dir(), "user skill dir should be preserved"
        assert (user_skill / "README.md").exists()


# ---------------------------------------------------------------------------
# テスト: install → uninstall → install のラウンドトリップ
# ---------------------------------------------------------------------------


class TestRoundTrip:
    """simulate_install → uninstall → simulate_install で stale が出ないこと"""

    def test_no_stale_message_on_reinstall(self, tmp_path: Path) -> None:
        dotfiles = _setup_dotfiles_repo(tmp_path)
        home = tmp_path / "home"
        home.mkdir()

        # install → uninstall → install
        _simulate_install(dotfiles, home)
        _run_uninstall(dotfiles, home)
        _simulate_install(dotfiles, home)

        # 2回目の uninstall で古いリンクメッセージが出ないこと
        result = _run_uninstall(dotfiles, home)
        assert "古い" not in result.stdout, (
            "再 install 後に stale リンクメッセージが出るべきでない"
        )


# ---------------------------------------------------------------------------
# テスト: bin/ インストール
# ---------------------------------------------------------------------------


class TestBinInstall:
    """bin/ の CLIツールが ~/.local/bin/ にインストール/アンインストールされること"""

    def test_install_creates_bin_symlinks(self, tmp_path: Path) -> None:
        """install -f で bin/ 内のファイルが ~/.local/bin/ にリンクされる"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)
        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"

        local_bin = home / ".local" / "bin"
        assert local_bin.is_dir(), "~/.local/bin/ should be created"

        # bin/ 内の代表的なファイルがリンクされていること
        for bin_file in (REPO_ROOT / "bin").iterdir():
            if bin_file.is_file():
                link = local_bin / bin_file.name
                assert link.is_symlink(), f"{bin_file.name} should be symlinked"

    def test_uninstall_removes_bin_symlinks(self, tmp_path: Path) -> None:
        """uninstall で bin/ のシンボリックリンクが削除される"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)

        local_bin = home / ".local" / "bin"
        # install 後にリンクが存在することを前提確認
        bin_files = list((REPO_ROOT / "bin").iterdir())
        assert len(bin_files) > 0
        assert (local_bin / bin_files[0].name).is_symlink()

        _run_install_sh(REPO_ROOT, home, uninstall=True)
        for bin_file in bin_files:
            if bin_file.is_file():
                link = local_bin / bin_file.name
                assert not link.exists(), f"{bin_file.name} should be removed"

    def test_dryrun_shows_bin(self, tmp_path: Path) -> None:
        """ドライランで bin/ のインストールが表示される"""
        home = tmp_path / "home"
        home.mkdir()
        env = os.environ.copy()
        env["HOME"] = str(home)
        result = subprocess.run(
            ["sh", str(REPO_ROOT / "install.sh"), "-n", "-f"],
            cwd=str(REPO_ROOT),
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0
        assert ".local/bin" in result.stdout


# ---------------------------------------------------------------------------
# ヘルパー (vendor テスト用)
# ---------------------------------------------------------------------------


def _create_fake_vendor(home: Path) -> Path:
    """疑似 vendor/agent-skills リポジトリを ~/.claude/vendor/ に作成"""
    vendor_dir = home / ".claude" / "vendor" / "agent-skills"
    skills_dir = vendor_dir / "skills"

    for skill_name in ("composition-patterns", "react-best-practices", "web-design-guidelines"):
        skill_dir = skills_dir / skill_name
        skill_dir.mkdir(parents=True, exist_ok=True)
        (skill_dir / "SKILL.md").write_text(f"# {skill_name}")

    # git init して .git/ を作る (install.sh が .git の存在でクローン済み判定)
    subprocess.run(
        ["git", "init", str(vendor_dir)], check=True, capture_output=True
    )
    subprocess.run(
        ["git", "-C", str(vendor_dir), "add", "."], check=True, capture_output=True
    )
    subprocess.run(
        ["git", "-C", str(vendor_dir), "commit", "-m", "init"],
        check=True, capture_output=True,
    )
    return vendor_dir


# ---------------------------------------------------------------------------
# テスト: vendor スキルのインストール
# ---------------------------------------------------------------------------


class TestVendorInstall:
    """vendor スキルの clone + symlink 処理のテスト"""

    VENDOR_SKILLS = ("composition-patterns", "react-best-practices", "web-design-guidelines")

    def test_vendor_symlinks_created(self, tmp_path: Path) -> None:
        """vendor clone 済みの状態で install すると skills にシンボリックリンクが作成される"""
        home = tmp_path / "home"
        home.mkdir()
        _create_fake_vendor(home)

        _run_install_sh(REPO_ROOT, home)

        for skill in self.VENDOR_SKILLS:
            link = home / ".claude" / "skills" / skill
            assert link.is_symlink(), f"vendor skill {skill} should be symlinked"
            assert link.resolve().is_dir(), f"vendor skill {skill} link target should exist"

    def test_vendor_idempotent(self, tmp_path: Path) -> None:
        """2回 install しても vendor symlink が壊れない"""
        home = tmp_path / "home"
        home.mkdir()
        _create_fake_vendor(home)

        _run_install_sh(REPO_ROOT, home)
        result = _run_install_sh(REPO_ROOT, home)

        assert result.returncode == 0
        for skill in self.VENDOR_SKILLS:
            link = home / ".claude" / "skills" / skill
            assert link.is_symlink(), f"vendor skill {skill} should still be symlinked after 2nd install"

    def test_vendor_no_skills_dir(self, tmp_path: Path) -> None:
        """vendor clone はあるが skills/ がない場合にエラーにならない"""
        home = tmp_path / "home"
        home.mkdir()

        # .git だけある空の vendor を作成
        vendor_dir = home / ".claude" / "vendor" / "agent-skills"
        vendor_dir.mkdir(parents=True)
        result = subprocess.run(
            ["git", "init", str(vendor_dir)], check=True, capture_output=True
        )

        result = _run_install_sh(REPO_ROOT, home)
        assert result.returncode == 0

    def test_vendor_dryrun_no_symlinks(self, tmp_path: Path) -> None:
        """ドライランでは vendor symlink が実際に作成されない"""
        home = tmp_path / "home"
        home.mkdir()
        _create_fake_vendor(home)

        env = os.environ.copy()
        env["HOME"] = str(home)
        result = subprocess.run(
            ["sh", str(REPO_ROOT / "install.sh"), "-n", "-f"],
            cwd=str(REPO_ROOT),
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0

        # ドライランなので symlink は作られない (vendor はすでに存在するが skill リンクはまだ)
        for skill in self.VENDOR_SKILLS:
            link = home / ".claude" / "skills" / skill
            # vendor dir 直下にファイルがあるだけで symlink ではないはず
            assert not link.is_symlink(), f"dryrun should not create vendor symlink for {skill}"

    def test_vendor_broken_symlink_at_dest(self, tmp_path: Path) -> None:
        """destination に壊れた symlink がある場合でもクラッシュしない"""
        home = tmp_path / "home"
        home.mkdir()
        _create_fake_vendor(home)

        # 壊れた symlink を destination に配置
        skills_dir = home / ".claude" / "skills"
        skills_dir.mkdir(parents=True, exist_ok=True)
        broken = skills_dir / "composition-patterns"
        broken.symlink_to("/nonexistent/path")
        assert broken.is_symlink()
        assert not broken.exists()  # dangling

        result = _run_install_sh(REPO_ROOT, home)
        assert result.returncode == 0

        # 壊れた symlink が修復され、正しいリンクに置き換わっていること
        link = skills_dir / "composition-patterns"
        assert link.is_symlink(), "broken symlink should be replaced with valid one"
        assert link.resolve().is_dir(), "repaired symlink should point to valid target"


# ---------------------------------------------------------------------------
# テスト: vendor スキルのアンインストール
# ---------------------------------------------------------------------------


class TestVendorUninstall:
    """vendor スキルの symlink 削除 + vendor ディレクトリ削除のテスト"""

    VENDOR_SKILLS = ("composition-patterns", "react-best-practices", "web-design-guidelines")

    def test_uninstall_removes_vendor_symlinks(self, tmp_path: Path) -> None:
        """uninstall で vendor skill の symlink が削除される"""
        home = tmp_path / "home"
        home.mkdir()
        _create_fake_vendor(home)
        _run_install_sh(REPO_ROOT, home)

        # install 後に symlink が存在することを確認
        for skill in self.VENDOR_SKILLS:
            assert (home / ".claude" / "skills" / skill).is_symlink()

        _run_install_sh(REPO_ROOT, home, uninstall=True)

        for skill in self.VENDOR_SKILLS:
            link = home / ".claude" / "skills" / skill
            assert not link.exists(), f"vendor skill {skill} should be removed on uninstall"

    def test_uninstall_removes_vendor_dir(self, tmp_path: Path) -> None:
        """uninstall で ~/.claude/vendor/ ディレクトリが削除される"""
        home = tmp_path / "home"
        home.mkdir()
        _create_fake_vendor(home)
        _run_install_sh(REPO_ROOT, home)

        vendor_dir = home / ".claude" / "vendor"
        assert vendor_dir.is_dir()

        _run_install_sh(REPO_ROOT, home, uninstall=True)
        assert not vendor_dir.exists(), "vendor dir should be removed on uninstall"

    def test_uninstall_dryrun_preserves_vendor(self, tmp_path: Path) -> None:
        """ドライラン uninstall では vendor が実際に削除されない"""
        home = tmp_path / "home"
        home.mkdir()
        _create_fake_vendor(home)
        _run_install_sh(REPO_ROOT, home)

        env = os.environ.copy()
        env["HOME"] = str(home)
        subprocess.run(
            ["sh", str(REPO_ROOT / "install.sh"), "-u", "-n", "-f"],
            cwd=str(REPO_ROOT),
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )

        # ドライランなので vendor は残る
        for skill in self.VENDOR_SKILLS:
            link = home / ".claude" / "skills" / skill
            assert link.is_symlink(), f"dryrun uninstall should preserve vendor symlink for {skill}"
        assert (home / ".claude" / "vendor").is_dir(), "dryrun uninstall should preserve vendor dir"

    def test_uninstall_without_vendor(self, tmp_path: Path) -> None:
        """vendor 未導入状態で uninstall してもエラーにならない"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)

        result = _run_install_sh(REPO_ROOT, home, uninstall=True)
        # vendor がなくてもクラッシュしない
        assert "エラー" not in result.stdout


# ---------------------------------------------------------------------------
# テスト: vendor-skills-update.sh hook
# ---------------------------------------------------------------------------


class TestVendorSkillsUpdateHook:
    """vendor-skills-update.sh hook のテスト"""

    HOOK = REPO_ROOT / "claude" / "hooks" / "vendor-skills-update.sh"

    def _run_hook(self, home: Path) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["HOME"] = str(home)
        return subprocess.run(
            ["sh", str(self.HOOK)],
            env=env,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_exit_0_when_no_vendor(self, tmp_path: Path) -> None:
        """vendor 未導入時に exit 0 で正常終了する"""
        home = tmp_path / "home"
        home.mkdir()
        result = self._run_hook(home)
        assert result.returncode == 0

    def test_skip_when_stamp_recent(self, tmp_path: Path) -> None:
        """スタンプファイルが新しい場合に pull をスキップする"""
        home = tmp_path / "home"
        home.mkdir()
        vendor_dir = _create_fake_vendor(home)
        stamp = vendor_dir / ".last-update"

        # 現在時刻をスタンプに書き込み
        import time
        stamp.write_text(str(int(time.time())))

        result = self._run_hook(home)
        assert result.returncode == 0

    def test_pull_when_stamp_old(self, tmp_path: Path) -> None:
        """スタンプファイルが古い場合に pull を試行し、exit 0 で終了する"""
        home = tmp_path / "home"
        home.mkdir()
        vendor_dir = _create_fake_vendor(home)
        stamp = vendor_dir / ".last-update"

        # 2日前のタイムスタンプ
        import time
        old_stamp = str(int(time.time()) - 200000)
        stamp.write_text(old_stamp)

        result = self._run_hook(home)
        assert result.returncode == 0
        # リモートがないので pull 自体は失敗するが、hook は exit 0 で終了する
        # スタンプは更新されない (pull 失敗時はスタンプを書き込まない)

    def test_pull_succeeds_with_remote(self, tmp_path: Path) -> None:
        """リモートがある場合に pull 成功でスタンプが更新される"""
        home = tmp_path / "home"
        home.mkdir()

        # 初期コミット付きのリポジトリを作成して bare に push
        src = tmp_path / "src"
        src.mkdir()
        subprocess.run(["git", "init", str(src)], check=True, capture_output=True)
        (src / "README.md").write_text("# test")
        subprocess.run(["git", "-C", str(src), "add", "."], check=True, capture_output=True)
        subprocess.run(
            ["git", "-C", str(src), "commit", "-m", "init"],
            check=True, capture_output=True,
        )

        bare = tmp_path / "remote.git"
        subprocess.run(
            ["git", "clone", "--bare", str(src), str(bare)],
            check=True, capture_output=True,
        )

        # vendor を bare からクローン
        vendor_dir = home / ".claude" / "vendor" / "agent-skills"
        vendor_dir.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["git", "clone", str(bare), str(vendor_dir)],
            check=True, capture_output=True,
        )

        # スタンプを古い時刻で作成
        import time
        stamp = vendor_dir / ".last-update"
        stamp.write_text(str(int(time.time()) - 200000))

        result = self._run_hook(home)
        assert result.returncode == 0

        # pull 成功 → スタンプが更新される
        new_stamp = int(stamp.read_text().strip())
        assert new_stamp > int(time.time()) - 10, "stamp should be updated after successful pull"

    def test_pull_when_no_stamp(self, tmp_path: Path) -> None:
        """スタンプファイルがない場合に pull を試行する"""
        home = tmp_path / "home"
        home.mkdir()
        _create_fake_vendor(home)

        result = self._run_hook(home)
        assert result.returncode == 0

    def test_corrupted_stamp_file(self, tmp_path: Path) -> None:
        """スタンプファイルが破損していても exit 0 で終了する"""
        home = tmp_path / "home"
        home.mkdir()
        vendor_dir = _create_fake_vendor(home)
        stamp = vendor_dir / ".last-update"
        stamp.write_text("not-a-number\n")

        result = self._run_hook(home)
        assert result.returncode == 0


# ---------------------------------------------------------------------------
# git グローバル設定 (ignore / attributes) の XDG 配置
# ---------------------------------------------------------------------------


class TestGitInstall:
    """~/.config/git/ 配下への gitignore / gitattributes 配置テスト"""

    def test_install_creates_xdg_gitignore(self, tmp_path: Path) -> None:
        """install 後 ~/.config/git/ignore が base+variant マージの実体ファイル"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)

        ignore = home / ".config" / "git" / "ignore"
        assert ignore.is_file()
        assert not ignore.is_symlink()

        content = ignore.read_text()
        # base (.gitignore.common) 由来
        assert ".DS_Store" in content
        # variant (.gitignore.work / .private) が結合されていること
        assert ("**/.codex/" in content) or ("Private-specific" in content)

    def test_install_preserves_existing_gitignore_backup(
        self, tmp_path: Path
    ) -> None:
        """既存 ~/.config/git/ignore.bak は install 時に上書きしない"""
        home = tmp_path / "home"
        home_git = home / ".config" / "git"
        home_git.mkdir(parents=True)
        ignore = home_git / "ignore"
        backup = home_git / "ignore.bak"
        ignore.write_text("current local ignore\n", encoding="utf-8")
        backup.write_text("previous backup\n", encoding="utf-8")

        result = _run_install_sh(REPO_ROOT, home)

        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"
        assert backup.read_text(encoding="utf-8") == "previous backup\n"
        assert (home_git / "ignore.bak.1").read_text(encoding="utf-8") == (
            "current local ignore\n"
        )
        assert ".DS_Store" in ignore.read_text(encoding="utf-8")

    def test_install_creates_xdg_gitattributes_symlink(self, tmp_path: Path) -> None:
        """install 後 ~/.config/git/attributes が repo の .gitattributes へのリンク"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)

        attributes = home / ".config" / "git" / "attributes"
        assert attributes.is_symlink()
        assert attributes.resolve() == (REPO_ROOT / "config" / "git" / ".gitattributes").resolve()

    def test_uninstall_removes_xdg_git_files(self, tmp_path: Path) -> None:
        """uninstall 後 ~/.config/git/ignore と attributes が削除される"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)
        _run_install_sh(REPO_ROOT, home, uninstall=True)

        assert not (home / ".config" / "git" / "ignore").exists()
        attributes = home / ".config" / "git" / "attributes"
        assert not attributes.exists()
        assert not attributes.is_symlink()

    def test_install_removes_legacy_git_artifacts(self, tmp_path: Path) -> None:
        """install 時に旧配置 (ドット付き attributes / gitignore_global) の残骸リンクが除去される"""
        home = tmp_path / "home"
        home.mkdir()
        cfg_git = home / ".config" / "git"
        cfg_git.mkdir(parents=True)

        # 旧 dotfiles 由来リンク (DOTFILES_DIR=REPO_ROOT 配下を指す) を事前作成
        legacy_attr = cfg_git / ".gitattributes"
        legacy_attr.symlink_to(REPO_ROOT / "config" / "git" / ".gitattributes")
        legacy_global = home / ".gitignore_global"
        legacy_global.symlink_to(REPO_ROOT / "config" / "git" / ".gitignore.common")
        legacy_common = home / ".gitignore.common"
        legacy_common.symlink_to(REPO_ROOT / "config" / "git" / ".gitignore.common")

        _run_install_sh(REPO_ROOT, home)

        assert not legacy_attr.is_symlink(), "ドット付き旧 gitattributes リンクが残存"
        assert not legacy_global.is_symlink(), "旧 gitignore_global リンクが残存"
        assert not legacy_common.is_symlink(), "旧 gitignore.common リンクが残存"
