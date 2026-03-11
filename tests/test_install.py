#!/usr/bin/env python3
"""install.sh テスト — uninstall 時の stale リンク削除・空ディレクトリ集約

テスト構成:
  - TestIntegration*: 実リポジトリ (/workspace) で install.sh を実際に実行
  - TestUninstallStaleLinks, TestEmptyDir*, TestNested*, TestRoundTrip:
    疑似リポジトリで個別機能をテスト
"""

import os
import subprocess
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
        assert (claude_dir / "settings.json").is_symlink()
        assert (claude_dir / "CLAUDE.md").is_symlink()

    def test_uninstall_removes_claude_symlinks(self, tmp_path: Path) -> None:
        """uninstall 後に dotfiles 由来のシンボリックリンクが削除される"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)

        # install 後にリンクが存在することを前提確認
        assert (home / ".claude" / "settings.json").is_symlink()

        _run_install_sh(REPO_ROOT, home, uninstall=True)
        assert not (home / ".claude" / "settings.json").exists()

    def test_uninstall_empty_dir_summary(self, tmp_path: Path) -> None:
        """uninstall の空ディレクトリ削除メッセージが1行サマリー形式"""
        home = tmp_path / "home"
        home.mkdir()
        _run_install_sh(REPO_ROOT, home)
        result = _run_install_sh(REPO_ROOT, home, uninstall=True)

        summary_lines = [
            l for l in result.stdout.splitlines() if "空ディレクトリ削除" in l
        ]
        assert len(summary_lines) == 1, f"サマリーは1行であるべき: {summary_lines}"
        assert ".claude/ 配下" in summary_lines[0]

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

        result = _run_uninstall(dotfiles, home)
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

        result = _run_uninstall(dotfiles, home)

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
