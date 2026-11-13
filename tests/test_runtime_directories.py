"""Official runtime directory overrides select installed assets, not project state."""

from __future__ import annotations

import json
import os
import runpy
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


def _runtime_env(home: Path, runtime: str, config: Path) -> dict[str, str]:
    env = {
        key: value for key, value in os.environ.items()
        if key not in {"CLAUDE_CONFIG_DIR", "CODEX_HOME"}
    }
    env.update(HOME=str(home))
    env["CLAUDE_CONFIG_DIR" if runtime == "claude" else "CODEX_HOME"] = str(config)
    return env


@pytest.mark.parametrize("runtime", ("claude", "codex"))
def test_config_info_reads_selected_root(tmp_path: Path, runtime: str) -> None:
    home = tmp_path / "home"
    config = tmp_path / f"{runtime} account"
    (config / "skills" / "selected").mkdir(parents=True)
    (config / "skills" / "selected" / "SKILL.md").write_text("# selected\n")
    default = home / f".{runtime}" / "skills" / "wrong"
    default.mkdir(parents=True)
    (default / "SKILL.md").write_text("# wrong\n")
    result = subprocess.run(
        ["sh", str(ROOT / runtime / "bin" / f"{runtime}-config-info.sh"), "--skills", "--json"],
        env=_runtime_env(home, runtime, config), capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["skills"] == {"count": 1, "skills": ["selected"]}


@pytest.mark.parametrize("runtime", ("claude", "codex"))
def test_registered_hook_runs_from_selected_root(tmp_path: Path, runtime: str) -> None:
    home = tmp_path / "home"
    config = tmp_path / f"{runtime} account"
    (config / "hooks").mkdir(parents=True)
    hook = config / "hooks" / ("destructive-command-block.sh" if runtime == "claude" else "hook-dispatcher.sh")
    hook.write_text('#!/bin/sh\nprintf "selected:%s\\n" "$*"\n')
    hook.chmod(0o755)
    if runtime == "claude":
        settings = json.loads((ROOT / "claude/settings.json").read_text())
    else:
        import tomllib
        settings = tomllib.loads((ROOT / "codex/config.toml.template").read_text())
    command = settings["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
    result = subprocess.run(
        ["sh", "-c", command], env=_runtime_env(home, runtime, config),
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == ("selected:\n" if runtime == "claude" else "selected:pre-tool-use\n")


def test_rules_discovery_uses_codex_home_and_keeps_project_priority(tmp_path: Path) -> None:
    home = tmp_path / "home"
    config = tmp_path / "codex account"
    project = tmp_path / "project"
    for directory, content in ((config / "rules", "selected"), (home / ".codex/rules", "wrong"), (project / ".codex/rules", "project")):
        directory.mkdir(parents=True)
        (directory / "sample.md").write_text(content)
    command = '. "$1"; rules_collect_rule_files "$2" "$3"; cat "$3"'
    output = tmp_path / "rules.txt"
    result = subprocess.run(
        ["sh", "-c", command, "sh", str(ROOT / "codex/hooks/rules-lib.sh"), str(project), str(output)],
        env=_runtime_env(home, "codex", config), capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [str(project / ".codex/rules/sample.md")]
    (project / ".codex/rules/sample.md").unlink()
    result = subprocess.run(
        ["sh", "-c", command, "sh", str(ROOT / "codex/hooks/rules-lib.sh"), str(project), str(output)],
        env=_runtime_env(home, "codex", config), capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == [str(config / "rules/sample.md")]


@pytest.mark.parametrize("runtime,relative", (("claude", "skills/qa-nightmare"), ("codex", "agents/qa-nightmare")))
def test_preflight_locates_selected_runtime(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, runtime: str, relative: str) -> None:
    config = tmp_path / "selected runtime"
    monkeypatch.setenv("CLAUDE_CONFIG_DIR" if runtime == "claude" else "CODEX_HOME", str(config))
    module = runpy.run_path(str(ROOT / "bin/qa-nightmare-preflight"))
    spec, _ = module["load_trusted_manifest"]()
    root, manifest, checklists = module["runtime_paths"](spec, runtime)
    assert root == config / relative
    assert manifest == root / "manifest.json"
    assert checklists == root / "checklists"


def test_installer_round_trip_keeps_runtime_overrides_outside_home(tmp_path: Path) -> None:
    import shutil
    from tests.test_install import _run_install_sh

    repo = tmp_path / "repo"
    shutil.copytree(ROOT, repo, ignore=shutil.ignore_patterns(".git", ".generated", ".stow-work", ".pytest_cache", "__pycache__", ".venv"))
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
    home = tmp_path / "home"
    home.mkdir()
    claude = tmp_path / "claude account"
    codex = tmp_path / "codex account"
    overrides = {"CLAUDE_CONFIG_DIR": str(claude), "CODEX_HOME": str(codex)}
    preview = _run_install_sh(repo, home, dry_run=True, env_overrides=overrides, use_fake_vendor=False)
    assert str(claude) in preview.stdout
    assert str(codex) in preview.stdout
    assert not claude.exists()
    assert not codex.exists()
    (claude / "vendor/agent-skills/.git").mkdir(parents=True)
    for _ in range(2):
        _run_install_sh(repo, home, env_overrides=overrides, use_fake_vendor=False)
        assert (claude / "rules/coding-conventions.md").is_file()
        assert (claude / "hooks/destructive-command-block.sh").is_file()
        settings = json.loads((claude / "settings.json").read_text())
        assert settings["sandbox"]["filesystem"]["allowWrite"] == [str(claude / "plugins/data"), str(codex)]
        expected_import = "@" + str(codex / "AGENTS.md").replace(" ", "\\ ")
        assert expected_import in (claude / "CLAUDE.md").read_text()
        assert (codex / "agents/code_reviewer.toml").is_file()
        assert (codex / "plugins/dotfile-work-codex/skills/tdd/SKILL.md").is_file()
        assert (codex / "config.toml").is_file()
        marketplace = json.loads((home / ".agents/plugins/marketplace.json").read_text())
        assert marketplace["plugins"][0]["source"]["path"] == str(codex / "plugins/dotfile-work-codex")
        assert not (home / ".claude").exists()
        assert not (home / ".codex").exists()
    original_assets = {
        path: path.read_bytes()
        for path in (claude / "settings.json", claude / "CLAUDE.md", home / ".agents/plugins/marketplace.json")
    }
    second_home = tmp_path / "second home"
    second_home.mkdir()
    second_claude = tmp_path / "second claude"
    second_codex = tmp_path / "second codex"
    (second_claude / "vendor/agent-skills/.git").mkdir(parents=True)
    _run_install_sh(repo, second_home, env_overrides={"CLAUDE_CONFIG_DIR": str(second_claude), "CODEX_HOME": str(second_codex)}, use_fake_vendor=False)
    for path, content in original_assets.items():
        assert path.read_bytes() == content, path
    (claude / "personal.txt").write_text("retain\n")
    original_config = (codex / "config.toml").read_text()
    _run_install_sh(repo, home, uninstall=True, env_overrides=overrides, use_fake_vendor=False)
    assert (claude / "personal.txt").read_text() == "retain\n"
    assert (codex / "config.toml").read_text() == original_config
    for path in (claude / "rules/coding-conventions.md", claude / "hooks/destructive-command-block.sh", codex / "agents/code_reviewer.toml", codex / "plugins/dotfile-work-codex/skills/tdd/SKILL.md", home / ".agents/plugins/marketplace.json"):
        assert not os.path.lexists(path)


def test_inline_dispatcher_registration_accepts_quoted_config_template(tmp_path: Path) -> None:
    config = tmp_path / "codex account"
    config.mkdir()
    (config / "config.toml").write_bytes((ROOT / "codex/config.toml.template").read_bytes())
    result = subprocess.run(
        ["sh", "-c", '. "$1"; rules_inline_dispatcher_registered pre-tool-use', "sh", str(ROOT / "codex/hooks/rules-lib.sh")],
        env=_runtime_env(tmp_path / "home", "codex", config), capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize("is_selected,expected", ((True, 0), (False, 2)))
def test_companion_exception_is_limited_to_selected_claude_root(tmp_path: Path, is_selected: bool, expected: int) -> None:
    home = tmp_path / "home"
    config = tmp_path / "claude account"
    root = config if is_selected else home / ".claude"
    command = f'node "{root}/plugins/cache/openai-codex/codex/1.0.6/scripts/codex-companion.mjs" setup'
    result = subprocess.run(
        ["sh", str(ROOT / "claude/hooks/local-command-block.sh")],
        env={**_runtime_env(home, "claude", config), "CLAUDE_HOOK_TEST_MODE": "1"},
        input=json.dumps({"tool_name": "Bash", "tool_input": {"command": command}}),
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == expected, result.stdout + result.stderr


def test_vendor_update_throttle_is_scoped_to_selected_root(tmp_path: Path) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    docker = fake_bin / "docker"
    docker.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$DOCKER_LOG"\ncase "$*" in *symbolic-ref*) echo refs/remotes/origin/main ;; esac\n')
    docker.chmod(0o755)
    log = tmp_path / "docker.log"
    shared_tmp = tmp_path / "tmp"
    shared_tmp.mkdir()
    configurations = (tmp_path / "first account", tmp_path / "second account")
    for config in configurations:
        (config / "vendor/example/.git").mkdir(parents=True)
        result = subprocess.run(
            ["bash", str(ROOT / "claude/bin/skills-update.sh")],
            env={**_runtime_env(tmp_path / "home", "claude", config), "PATH": f"{fake_bin}:{os.environ['PATH']}", "DOCKER_LOG": str(log), "TMPDIR": str(shared_tmp)},
            capture_output=True, text=True, check=False,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        assert "Skipped" not in result.stdout
    calls = log.read_text()
    assert calls.count("fetch origin") == 2
    result = subprocess.run(
        ["bash", str(ROOT / "claude/bin/skills-update.sh")],
        env={**_runtime_env(tmp_path / "home", "claude", configurations[0]), "PATH": f"{fake_bin}:{os.environ['PATH']}", "DOCKER_LOG": str(log), "TMPDIR": str(shared_tmp)},
        capture_output=True, text=True, check=False,
    )
    assert result.returncode == 0, result.stderr
    assert "Skipped" in result.stdout
    assert log.read_text() == calls


@pytest.mark.parametrize("has_override", (False, True))
def test_marketplace_root_rewrite_preserves_remote_subdirectory(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, has_override: bool) -> None:
    selected = tmp_path / "codex account"
    if has_override:
        monkeypatch.setenv("CODEX_HOME", str(selected))
    else:
        monkeypatch.delenv("CODEX_HOME", raising=False)
    marketplace = tmp_path / ".agents/plugins/marketplace.json"
    marketplace.parent.mkdir(parents=True)
    remote = {"source": "git-subdir", "url": "https://github.com/anthropics/claude-plugins-official.git", "path": "./plugins/security-guidance"}
    marketplace.write_text(json.dumps({"plugins": [
        {"name": "local", "source": {"source": "local", "path": "./plugins/local"}},
        {"name": "remote", "source": remote},
    ]}))
    module = runpy.run_path(str(ROOT / "scripts/generate-ai-assets.py"))
    module["rewrite_personal_marketplace"](tmp_path)
    entries = json.loads(marketplace.read_text())["plugins"]
    assert entries[0]["source"]["path"] == (str(selected / "plugins/local") if has_override else "./.codex/plugins/local")
    assert entries[1]["source"] == remote
