#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
PORT_SCRIPT = REPO_ROOT / "scripts" / "port-claude-assets-to-codex.py"
GENERATOR_SCRIPT = REPO_ROOT / "scripts" / "generate-standard-workflow-skills.py"
VERIFY_SCRIPT = REPO_ROOT / "scripts" / "verify-codex-plugin.py"


def load_script(path: Path, module_name: str):
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


class PortClaudeAssetsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp_dir.name)
        (self.repo / "claude" / "skills").mkdir(parents=True)
        (self.repo / "claude" / "rules").mkdir(parents=True)
        commands = self.repo / "claude" / "commands"
        commands.mkdir()
        for command, skill in {
            "commit": "commit-msg",
            "deep-review": "deep-review",
            "feat": "feat",
            "fix": "fix",
        }.items():
            (commands / f"{command}.md").write_text(
                f"# {command}\n", encoding="utf-8"
            )
            self.write_native_skill(skill)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def run_port(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(PORT_SCRIPT),
                "--repo",
                str(self.repo),
                "--overwrite",
                "--no-backup",
                *args,
            ],
            capture_output=True,
            check=False,
            text=True,
        )

    def write_native_skill(self, name: str) -> Path:
        path = self.repo / "codex" / "skills" / name / "SKILL.md"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"# native {name}\n", encoding="utf-8")
        return path

    def test_ports_known_command_as_reference_without_overwriting_native_skill(self) -> None:
        native = self.write_native_skill("feat")
        commands = self.repo / "claude" / "commands"
        (commands / "feat.md").write_text(
            "# Claude command\n\n"
            "$ARGUMENTS を `.claude` と CLAUDE.md で確認し、`/feat` を使う。\n"
            "@ $HOME/.claude/CLAUDE.md\n"
            "`${HOME}/.claude/skills/tdd/SKILL.md` を読む。\n"
            "`${HOME}/.claude/rules/*` は @import 済みで context にある。\n"
            "`code-reviewer` は読み取り専用・sonnet モデルで安定している。\n",
            encoding="utf-8",
        )

        result = self.run_port()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(native.read_text(encoding="utf-8"), "# native feat\n")
        reference = self.repo / "codex" / "skills" / "feat" / "references" / "claude-command.md"
        text = reference.read_text(encoding="utf-8")
        self.assertIn("source=claude/commands/feat.md", text)
        self.assertIn("ユーザー指定の対象", text)
        self.assertIn(".codex", text)
        self.assertIn("AGENTS.md", text)
        self.assertIn("`@feat`", text)
        self.assertNotIn("$ARGUMENTS", text)
        self.assertIn("`${HOME}/.codex/AGENTS.md` を読む", text)
        self.assertIn("`$tdd`", text)
        self.assertIn("rules-inject hook", text)
        self.assertNotIn("@import", text)
        self.assertNotIn("sonnet", text)

    def test_maps_commit_command_to_commit_msg_invocation(self) -> None:
        self.write_native_skill("commit-msg")
        commands = self.repo / "claude" / "commands"
        (commands / "commit.md").write_text("Use `/commit`.\n", encoding="utf-8")

        result = self.run_port()

        self.assertEqual(result.returncode, 0, result.stderr)
        reference = (
            self.repo
            / "codex"
            / "skills"
            / "commit-msg"
            / "references"
            / "claude-command.md"
        )
        text = reference.read_text(encoding="utf-8")
        self.assertIn("`@commit-msg`", text)
        self.assertNotIn("`@commit`", text)

    def test_ports_skill_with_valid_frontmatter_and_codex_references(self) -> None:
        skill = self.repo / "claude" / "skills" / "semantic-generation" / "SKILL.md"
        skill.parent.mkdir()
        skill.write_text(
            "---\n"
            "name: semantic-generation\n"
            "description: Build a referent table before design documents.\n"
            "---\n\n"
            "# Semantic generation\n\n"
            "[[semantic-generation]] follows [[referent-before-label]] and [[terminology]].\n",
            encoding="utf-8",
        )

        result = self.run_port()

        self.assertEqual(result.returncode, 0, result.stderr)
        output = (
            self.repo / "codex" / "skills" / "semantic-generation" / "SKILL.md"
        ).read_text(encoding="utf-8")
        self.assertIn("# codex_port_source: claude/skills/semantic-generation/SKILL.md", output)
        self.assertNotIn("\ncodex_port_source:", output)
        self.assertNotIn("[[", output)
        self.assertIn("`$semantic-generation`", output)
        self.assertIn("`referent-before-label`", output)
        self.assertIn("`terminology`", output)

    def test_unknown_command_fails_preflight_before_any_write(self) -> None:
        self.write_native_skill("feat")
        commands = self.repo / "claude" / "commands"
        (commands / "feat.md").write_text("# feat\n", encoding="utf-8")
        (commands / "surprise.md").write_text("# surprise\n", encoding="utf-8")
        rule_dest = self.repo / "codex" / "rules" / "existing.md"
        rule_dest.parent.mkdir(parents=True)
        rule_dest.write_text("# unchanged\n", encoding="utf-8")

        result = self.run_port()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown Claude command", result.stderr)
        self.assertFalse(
            (self.repo / "codex" / "skills" / "feat" / "references" / "claude-command.md").exists()
        )
        self.assertEqual(rule_dest.read_text(encoding="utf-8"), "# unchanged\n")

    def test_missing_manifest_command_fails_preflight_before_any_write(self) -> None:
        (self.repo / "claude" / "commands" / "fix.md").unlink()

        result = self.run_port()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing Claude command", result.stderr)
        self.assertFalse(
            (self.repo / "codex" / "skills" / "feat" / "references").exists()
        )

    def test_unexpected_skill_resource_fails_before_any_write(self) -> None:
        first = self.repo / "claude" / "skills" / "first" / "SKILL.md"
        first.parent.mkdir()
        first.write_text("# first\n", encoding="utf-8")
        second = self.repo / "claude" / "skills" / "second" / "SKILL.md"
        second.parent.mkdir()
        second.write_text("# second\n", encoding="utf-8")
        (second.parent / "references").mkdir()
        (second.parent / "references" / "extra.md").write_text(
            "# extra\n", encoding="utf-8"
        )

        result = self.run_port()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported Claude skill resource", result.stderr)
        self.assertFalse(
            (self.repo / "codex" / "skills" / "first" / "SKILL.md").exists()
        )

    def test_prune_is_explicit_and_removes_only_managed_stale_outputs(self) -> None:
        rules = self.repo / "codex" / "rules"
        rules.mkdir(parents=True)
        managed = rules / "stale.md"
        managed.write_text(
            "# stale\n"
            "<!-- codex-port: managed; source=claude/rules/stale.md; "
            "generated-by=scripts/port-claude-assets-to-codex.py -->\n",
            encoding="utf-8",
        )
        unmanaged = rules / "native.md"
        unmanaged.write_text("# native\n", encoding="utf-8")

        self.assertEqual(self.run_port().returncode, 0)
        self.assertTrue(managed.exists())
        self.assertEqual(self.run_port("--prune", "--dry-run").returncode, 0)
        self.assertTrue(managed.exists())

        result = self.run_port("--prune")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(managed.exists())
        self.assertTrue(unmanaged.exists())


class VerifyCodexPluginTest(unittest.TestCase):
    def test_rule_sync_detects_content_drift(self) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_codex_plugin_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "codex" / "rules" / "example.md"
            plugin = root / "plugins" / "dotfile-work-codex" / "rules" / "example.md"
            source.parent.mkdir(parents=True)
            plugin.parent.mkdir(parents=True)
            source.write_text("# same\n", encoding="utf-8")
            plugin.write_text("# same\n", encoding="utf-8")
            self.assertEqual(verify.check_rule_sync(root), 0)

            plugin.write_text("# drift\n", encoding="utf-8")
            self.assertNotEqual(verify.check_rule_sync(root), 0)


class GenerateStandardWorkflowSkillsTest(unittest.TestCase):
    def test_plugin_sync_uses_manifest_and_runs_the_full_pipeline(self) -> None:
        generator = load_script(GENERATOR_SCRIPT, "generate_standard_workflow_skills_test")

        self.assertEqual(
            generator.CLAUDE_COMMAND_REFERENCES["commit-msg"],
            "claude/commands/commit.md",
        )
        workflow = generator.WORKFLOWS["plugin-sync"][2]
        commands = [
            "generate-standard-workflow-skills.py",
            "port-claude-assets-to-codex.py",
            "apply-codex-performance-profile.py",
            "sync-codex-plugin.py",
            "verify-codex-plugin.py",
        ]
        positions = [workflow.index(command) for command in commands]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("--prune", workflow)


if __name__ == "__main__":
    unittest.main()
