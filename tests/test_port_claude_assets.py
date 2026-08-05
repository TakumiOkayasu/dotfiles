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
SYNC_SCRIPT = REPO_ROOT / "scripts" / "sync-codex-plugin.py"
CLAUDE_TDD_QA_FIXTURE = """# Test-Driven Development

| 機能単位 (画面 / API / エンドポイント / ジョブ) | ユーザー登録画面、決済 API、夜間バッチ | qa-nightmare subagent を起動する |

機能単位と判定したら、テストリスト作成に進む前に qa-nightmare subagent を起動して悪夢テストケースを先に列挙する。

### qa-nightmare 起動

Task tool で `subagent_type: qa-nightmare` を起動する。

`qa-nightmare-preflight` を使う。

### 結果の扱い

<!-- qa-continuation:start -->
Claude runtime continuation contract.
<!-- qa-continuation:end -->

機能単位の場合は `qa-nightmare` subagent の出力を反映する。
"""


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

    def port_codex_tdd_fixture(self) -> str:
        skill = self.repo / "claude" / "skills" / "tdd" / "SKILL.md"
        skill.parent.mkdir()
        skill.write_text(CLAUDE_TDD_QA_FIXTURE, encoding="utf-8")

        result = self.run_port()

        self.assertEqual(result.returncode, 0, result.stderr)
        return (self.repo / "codex" / "skills" / "tdd" / "SKILL.md").read_text(
            encoding="utf-8"
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
            "`$HOME/.claude/CLAUDE.md` 「着手前の方針検証」と整合する。\n"
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
        self.assertIn("`RULES_CORE.md`", text)
        self.assertIn("taskに該当する詳細ruleだけを明示的に読む", text)
        self.assertNotIn("rules-inject hook", text)
        self.assertIn("Taskのscopeとriskを確認し", text)
        self.assertNotIn("着手前の方針検証", text)
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

    def test_tracked_methodology_references_match_transformer(self) -> None:
        porter = load_script(PORT_SCRIPT, "port_claude_methodology_reference_test")

        for command, skill in (
            ("commit", "commit-msg"),
            ("feat", "feat"),
            ("fix", "fix"),
            ("deep-review", "deep-review"),
        ):
            source = REPO_ROOT / "claude" / "commands" / f"{command}.md"
            transformed, _role = porter.transform_source(
                source, repo=REPO_ROOT, kind="command"
            )
            expected = transformed.rstrip() + "\n"
            actual = (
                REPO_ROOT
                / "codex"
                / "skills"
                / skill
                / "references"
                / "claude-command.md"
            ).read_text(encoding="utf-8")
            self.assertEqual(actual, expected)

    def test_tracked_selective_rule_assets_match_transformer(self) -> None:
        porter = load_script(PORT_SCRIPT, "port_claude_selective_rules_test")

        for relative_source in (
            Path("claude/skills/bug-hunt/SKILL.md"),
            Path("claude/skills/bug-hunt/references/review-lenses.md"),
        ):
            source = REPO_ROOT / relative_source
            transformed, _role = porter.transform_source(
                source, repo=REPO_ROOT, kind="skill"
            )
            relative_output = relative_source.relative_to("claude/skills")
            actual = (REPO_ROOT / "codex" / "skills" / relative_output).read_text(
                encoding="utf-8"
            )
            self.assertEqual(actual, transformed.rstrip() + "\n")

        orchestrate_source = (
            REPO_ROOT / "claude" / "skills" / "orchestrate" / "SKILL.md"
        )
        orchestrate_expected, _role = porter.transform_source(
            orchestrate_source, repo=REPO_ROOT, kind="skill"
        )
        orchestrate_actual = (
            REPO_ROOT / "codex" / "skills" / "orchestrate" / "SKILL.md"
        ).read_text(encoding="utf-8")
        self.assertEqual(orchestrate_actual, orchestrate_expected.rstrip() + "\n")

        for source in sorted((REPO_ROOT / "claude" / "rules").glob("*.md")):
            transformed, _role = porter.transform_source(
                source, repo=REPO_ROOT, kind="rule"
            )
            expected = transformed.rstrip() + "\n"
            actual = (REPO_ROOT / "codex" / "rules" / source.name).read_text(
                encoding="utf-8"
            )
            self.assertEqual(actual, expected)

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

    def test_should_fail_closed_when_codex_tdd_lacks_empty_tool_surface(self) -> None:
        output = self.port_codex_tdd_fixture()

        self.assertIn(
            "現行Codex custom-agentには構造的なempty tool surfaceがない", output
        )
        self.assertIn("`agent_type: qa_nightmare` をdispatchしない", output)
        self.assertIn("現行Codex: 未実行を明示 (dispatch禁止)", output)
        self.assertIn("### qa_nightmare の将来有効化仕様", output)
        self.assertIn("### 将来有効化時の結果の扱い", output)
        self.assertIn("`qa-nightmare-preflight`", output)
        self.assertNotIn(
            "`spawn_agent` で `agent_type: qa_nightmare` を起動する", output
        )

    def test_should_sync_continuation_when_porting_codex_tdd(self) -> None:
        output = self.port_codex_tdd_fixture()

        self.assertIn("followup_taskでledger digestとrequested_rankだけ", output)
        self.assertIn("compact continuation_ledger", output)
        self.assertIn("各代表ケースを再構成できるredacted事実", output)
        self.assertIn("ledger_upper_bound_tokens <= output_reserve_tokens", output)
        self.assertIn("機能単位の場合はqa_nightmare未実行を明示", output)
        self.assertIn("通常TDD候補を親が作る", output)
        self.assertEqual(output.count("<!-- qa-continuation:start -->"), 1)
        self.assertEqual(output.count("<!-- qa-continuation:end -->"), 1)

    def test_should_apply_tdd_surface_contract_when_role_is_tdd_skill(self) -> None:
        porter = load_script(PORT_SCRIPT, "port_claude_assets_role_test")

        output = porter.transform_text(
            CLAUDE_TDD_QA_FIXTURE,
            source=Path("renamed/artifact.md"),
            kind="skill",
            role=porter.ArtifactRole.TDD_SKILL,
        )

        self.assertIn("`agent_type: qa_nightmare` をdispatchしない", output)
        self.assertIn("followup_taskでledger digestとrequested_rankだけ", output)

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

    def test_ports_allowlisted_skill_resource(self) -> None:
        skill = self.repo / "claude" / "skills" / "bug-hunt" / "SKILL.md"
        skill.parent.mkdir()
        skill.write_text(
            "# Bug Hunt\n\nRead `references/review-lenses.md`.\n",
            encoding="utf-8",
        )
        reference = skill.parent / "references" / "review-lenses.md"
        reference.parent.mkdir()
        reference.write_text(
            "# Review Lenses\n\nCheck `.claude` paths.\n",
            encoding="utf-8",
        )

        result = self.run_port()

        self.assertEqual(result.returncode, 0, result.stderr)
        output = (
            self.repo
            / "codex"
            / "skills"
            / "bug-hunt"
            / "references"
            / "review-lenses.md"
        ).read_text(encoding="utf-8")
        self.assertIn("source=claude/skills/bug-hunt/references/review-lenses.md", output)
        self.assertIn("Check `.codex` paths.", output)
        self.assertIn("Rules are not automatically loaded.", output)

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

    def test_prune_removes_resource_after_source_and_allowlist_removal(self) -> None:
        porter = load_script(PORT_SCRIPT, "port_claude_prune_removed_resource_test")
        porter.ALLOWED_SKILL_FILES = frozenset({"SKILL.md"})
        resource = (
            self.repo
            / "codex"
            / "skills"
            / "bug-hunt"
            / "references"
            / "review-lenses.md"
        )
        resource.parent.mkdir(parents=True)
        resource.write_text(
            "# stale\n"
            "<!-- codex-port: managed; "
            "source=claude/skills/bug-hunt/references/review-lenses.md; "
            "generated-by=scripts/port-claude-assets-to-codex.py -->\n",
            encoding="utf-8",
        )
        args = type("Args", (), {"dry_run": False})()

        pruned = porter.prune_stale_outputs(self.repo, args)

        self.assertEqual(pruned, [resource])
        self.assertFalse(resource.exists())


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
    def test_workflow_generator_is_idempotent_without_backups(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            command = [
                sys.executable,
                str(GENERATOR_SCRIPT),
                "--repo",
                str(repo),
                "--overwrite",
            ]

            first = subprocess.run(
                command, capture_output=True, text=True, timeout=30
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            first_outputs = {
                path.relative_to(repo): path.read_bytes()
                for path in sorted((repo / "codex" / "skills").rglob("*"))
                if path.is_file()
            }

            second = subprocess.run(
                command, capture_output=True, text=True, timeout=30
            )
            self.assertEqual(second.returncode, 0, second.stderr)
            second_outputs = {
                path.relative_to(repo): path.read_bytes()
                for path in sorted((repo / "codex" / "skills").rglob("*"))
                if path.is_file()
            }

            self.assertEqual(second_outputs, first_outputs)
            self.assertNotIn(
                b"Generated at:",
                second_outputs[Path("codex/skills/PLUGIN_ONLY_WORKFLOWS.md")],
            )
            self.assertEqual(list(repo.rglob("*.bak")), [])

    def test_core_manifest_describes_selective_rule_loading(self) -> None:
        sync = load_script(SYNC_SCRIPT, "sync_codex_plugin_rule_contract_test")
        interface = sync.core_manifest()["interface"]

        self.assertIn(
            "selective markdown rule loading", interface["longDescription"]
        )
        self.assertNotIn("rule injection", interface["longDescription"])
        self.assertIn(
            "select and apply task-applicable rules",
            "\n".join(interface["defaultPrompt"]),
        )

    def test_plugin_sync_is_deterministic(self) -> None:
        sync = load_script(SYNC_SCRIPT, "sync_codex_plugin_determinism_test")

        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            (repo / "codex" / "skills").mkdir(parents=True)

            def snapshot() -> dict[Path, bytes]:
                return {
                    path.relative_to(repo): path.read_bytes()
                    for path in sorted((repo / "plugins").rglob("*"))
                    if path.is_file()
                }

            sync.sync_core(repo, clean=True)
            sync.sync_extra(repo, clean=True)
            first = snapshot()

            sync.sync_core(repo, clean=True)
            sync.sync_extra(repo, clean=True)
            second = snapshot()

            self.assertEqual(second, first)
            for content in second.values():
                self.assertNotIn(b"Generated at:", content)

    def test_tracked_rule_workflows_match_generator(self) -> None:
        generator = load_script(
            GENERATOR_SCRIPT, "generate_standard_workflow_rule_contract_test"
        )

        for name in ("feat", "rules-required"):
            description, title, content = generator.WORKFLOWS[name]
            expected = generator.skill_body(name, description, title, content)
            actual = (
                REPO_ROOT / "codex" / "skills" / name / "SKILL.md"
            ).read_text(encoding="utf-8")
            self.assertEqual(actual, expected)

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
