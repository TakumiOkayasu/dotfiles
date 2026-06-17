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
        claude_global = (REPO_ROOT / "claude" / "global_CLAUDE.md").read_text(
            encoding="utf-8"
        )
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


class TestIntegrationInstallUninstall:
    """実リポジトリ構造で install.sh -f / -u -f を実行するテスト"""

    def test_install_succeeds(self, tmp_path: Path) -> None:
        """install.sh -f が正常終了する"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)
        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"

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
        assert (claude_dir / "CLAUDE.md").is_symlink()
        assert (claude_dir / "rules" / "natural-japanese.md").is_symlink()
        checklist = (
            claude_dir / "skills" / "qa-nightmare" / "checklists" / "auth-bypass.md"
        )
        assert checklist.is_symlink()
        assert checklist.resolve() == (
            REPO_ROOT / "common" / "qa-nightmare" / "checklists" / "auth-bypass.md"
        )

    def test_install_creates_codex_symlinks(self, tmp_path: Path) -> None:
        """install 後に ~/.codex/ 配下にCodex設定とリンクが作られる"""
        home = tmp_path / "home"
        home.mkdir()
        result = _run_install_sh(REPO_ROOT, home)
        assert result.returncode == 0, f"install failed:\n{result.stdout}\n{result.stderr}"

        codex_dir = home / ".codex"
        assert codex_dir.is_dir()

        assert (codex_dir / "AGENTS.md").is_symlink()
        assert (codex_dir / "AGENTS.md").resolve() == REPO_ROOT / "codex" / "global_AGENTS.md"
        assert (codex_dir / "SUBAGENTS.md").is_symlink()
        assert (codex_dir / "SUBAGENTS.md").resolve() == REPO_ROOT / "codex" / "SUBAGENTS.md"
        assert (codex_dir / "agents" / "code_reviewer.toml").is_symlink()
        checklist = (
            codex_dir / "agents" / "qa-nightmare" / "checklists" / "auth-bypass.md"
        )
        assert checklist.is_symlink()
        assert checklist.resolve() == (
            REPO_ROOT / "common" / "qa-nightmare" / "checklists" / "auth-bypass.md"
        )
        config_toml = codex_dir / "config.toml"
        assert config_toml.is_file()
        assert not config_toml.is_symlink()
        assert config_toml.read_text(encoding="utf-8") == (
            REPO_ROOT / "codex" / "config.toml.template"
        ).read_text(encoding="utf-8")
        assert not (codex_dir / "hooks.json").exists()
        assert (codex_dir / "hooks").is_dir()
        destructive_hook = codex_dir / "hooks" / "destructive-command-block.sh"
        assert destructive_hook.is_symlink()
        assert destructive_hook.resolve() == (
            REPO_ROOT / "common" / "hooks" / "destructive-command-block.sh"
        )
        assert not (codex_dir / "README.md").exists()
        assert not (codex_dir / "settings.json").exists()
        assert not (codex_dir / "skills" / "tdd" / "SKILL.md").exists()
        assert not (codex_dir / "skills" / "natural-japanese" / "SKILL.md").exists()
        assert not (home / ".agents" / "skills" / "tdd" / "SKILL.md").exists()
        assert (codex_dir / "rules" / "coding-conventions.md").is_symlink()
        assert (codex_dir / "rules" / "natural-japanese.md").is_symlink()

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

        _run_install_sh(REPO_ROOT, home)

        assert not legacy_attr.is_symlink(), "ドット付き旧 gitattributes リンクが残存"
        assert not legacy_global.is_symlink(), "旧 gitignore_global リンクが残存"
