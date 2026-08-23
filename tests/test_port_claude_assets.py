#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import ModuleType
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
PORT_SCRIPT = REPO_ROOT / "scripts" / "port-claude-assets-to-codex.py"
GENERATOR_SCRIPT = REPO_ROOT / "scripts" / "generate-standard-workflow-skills.py"
VERIFY_SCRIPT = REPO_ROOT / "scripts" / "verify-codex-plugin.py"
PROFILE_SCRIPT = REPO_ROOT / "scripts" / "apply-codex-performance-profile.py"
SYNC_SCRIPT = REPO_ROOT / "scripts" / "sync-codex-plugin.py"
ASSET_MANIFEST = REPO_ROOT / "scripts" / "claude-command-map.json"
ASSET_MANIFEST_SCRIPT = REPO_ROOT / "scripts" / "codex_asset_manifest.py"
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


def write_shared_command_outputs(root: Path, porter: ModuleType) -> None:
    commands_dir = root / "common" / "commands"
    commands_dir.mkdir(parents=True, exist_ok=True)
    for command_name, skill_name in porter.COMMAND_DESTINATIONS.items():
        source = commands_dir / f"{command_name}.md"
        source.write_text(f"# {command_name}\n", encoding="utf-8")
        expected, _role = porter.transform_source(
            source, repo=root, kind="command"
        )
        generated = (
            root
            / "codex"
            / "skills"
            / skill_name
            / porter.COMMAND_REFERENCES[command_name]
        )
        generated.parent.mkdir(parents=True, exist_ok=True)
        generated.write_text(expected.rstrip() + "\n", encoding="utf-8")


class PortClaudeAssetsTest(unittest.TestCase):
    def test_rule_port_uses_single_blank_line_before_runtime_contract(self) -> None:
        module = load_script(PORT_SCRIPT, "port_claude_assets_rule_spacing_test")

        result = module.add_portability_notes(
            "# Rule\n\nBody\n\n",
            source=Path("common/rules/example.md"),
            kind="rule",
        )

        self.assertNotIn("\n\n\n## Codex rule loading", result)

    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp_dir.name)
        (self.repo / "common" / "skills").mkdir(parents=True)
        (self.repo / "common" / "rules").mkdir(parents=True)
        commands = self.repo / "common" / "commands"
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
        skill = self.repo / "common" / "skills" / "tdd" / "SKILL.md"
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

    def test_should_port_nested_resource_when_common_skill_contains_it(self) -> None:
        common = self.repo / "common"
        (common / "skills" / "bug-hunt" / "references").mkdir(parents=True)
        (common / "skills" / "bug-hunt" / "SKILL.md").write_text(
            "---\nname: bug-hunt\ndescription: Find bugs.\n---\n\n# Bug Hunt\n",
            encoding="utf-8",
        )
        (common / "skills" / "bug-hunt" / "references" / "review-lenses.md").write_text(
            "# Review Lenses\n\nClaude Code contract.\n", encoding="utf-8"
        )

        result = self.run_port()

        self.assertEqual(result.returncode, 0, result.stderr)
        skill = self.repo / "codex" / "skills" / "bug-hunt" / "SKILL.md"
        reference = skill.parent / "references" / "review-lenses.md"
        self.assertIn(
            "source=common/skills/bug-hunt/SKILL.md",
            skill.read_text(encoding="utf-8"),
        )
        reference_text = reference.read_text(encoding="utf-8")
        self.assertIn("source=common/skills/bug-hunt/references/review-lenses.md", reference_text)
        self.assertIn("Codex contract.", reference_text)

    def test_ports_known_command_as_reference_without_overwriting_native_skill(self) -> None:
        native = self.write_native_skill("feat")
        commands = self.repo / "common" / "commands"
        (commands / "feat.md").write_text(
            "# Claude command\n\n"
            "$ARGUMENTS を `.claude` と CLAUDE.md で確認し、`/feat` を使う。\n"
            "@ $HOME/.claude/CLAUDE.md\n"
            "`${HOME}/.claude/skills/tdd/SKILL.md` を読む。\n"
            "`${HOME}/.claude/rules/*` は @import 済みで context にある。\n"
            "`$HOME/.claude/CLAUDE.md` 「着手前の方針検証」と整合する。\n"
            "`code-reviewer` は読み取り専用・sonnet モデルで安定している。\n",
            encoding="utf-8",
        )

        result = self.run_port()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(native.read_text(encoding="utf-8"), "# native feat\n")
        reference = self.repo / "codex" / "skills" / "feat" / "references" / "claude-command.md"
        text = reference.read_text(encoding="utf-8")
        self.assertIn("source=common/commands/feat.md", text)
        self.assertIn("ユーザー指定の対象", text)
        self.assertIn(".codex", text)
        self.assertIn("AGENTS.md", text)
        self.assertIn("`$feat`", text)
        self.assertNotIn("`@feat`", text)
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
        commands = self.repo / "common" / "commands"
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
        self.assertIn("`$commit-msg`", text)
        self.assertNotIn("`$commit`", text)

    def test_should_reject_shared_skill_directory_without_entrypoint(self) -> None:
        orphan_reference = (
            self.repo
            / "common"
            / "skills"
            / "orphan"
            / "references"
            / "details.md"
        )
        orphan_reference.parent.mkdir(parents=True)
        orphan_reference.write_text("# Details\n", encoding="utf-8")

        result = self.run_port()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid shared skill layout", result.stderr)

    def test_ports_skill_with_valid_frontmatter_and_codex_references(self) -> None:
        skill = self.repo / "common" / "skills" / "semantic-generation" / "SKILL.md"
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
        self.assertIn("# codex_port_source: common/skills/semantic-generation/SKILL.md", output)
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
        self.assertNotIn("\n\n\n", output)

    def test_unknown_command_fails_preflight_before_any_write(self) -> None:
        self.write_native_skill("feat")
        commands = self.repo / "common" / "commands"
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
        (self.repo / "common" / "commands" / "fix.md").unlink()

        result = self.run_port()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing Claude command", result.stderr)
        self.assertFalse(
            (self.repo / "codex" / "skills" / "feat" / "references").exists()
        )

    def test_unexpected_skill_resource_fails_before_any_write(self) -> None:
        first = self.repo / "common" / "skills" / "first" / "SKILL.md"
        first.parent.mkdir()
        first.write_text("# first\n", encoding="utf-8")
        second = self.repo / "common" / "skills" / "second" / "SKILL.md"
        second.parent.mkdir()
        second.write_text("# second\n", encoding="utf-8")
        (second.parent / "scripts").mkdir()
        (second.parent / "scripts" / "extra.py").write_text(
            "raise SystemExit(0)\n", encoding="utf-8"
        )

        result = self.run_port()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsupported Claude skill resource", result.stderr)
        self.assertFalse(
            (self.repo / "codex" / "skills" / "first" / "SKILL.md").exists()
        )

    def test_untransformable_skill_resource_fails_before_any_write(self) -> None:
        first = self.repo / "common" / "skills" / "first" / "SKILL.md"
        first.parent.mkdir()
        first.write_text("# first\n", encoding="utf-8")
        second = self.repo / "common" / "skills" / "second" / "SKILL.md"
        second.parent.mkdir()
        second.write_text("# second\n", encoding="utf-8")
        reference = second.parent / "references" / "details.md"
        reference.parent.mkdir()
        reference.write_bytes(b"\xff")

        result = self.run_port()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("UnicodeDecodeError", result.stderr)
        self.assertFalse(
            (self.repo / "codex" / "skills" / "first" / "SKILL.md").exists()
        )

    def test_prune_is_explicit_and_removes_only_managed_stale_outputs(self) -> None:
        rules = self.repo / "codex" / "rules"
        rules.mkdir(parents=True)
        managed = rules / "stale.md"
        managed.write_text(
            "# stale\n"
            "<!-- codex-port: managed; source=common/rules/stale.md; "
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


class AssetManifestTest(unittest.TestCase):
    def test_should_reject_non_string_command_fields_when_manifest_is_loaded(
        self,
    ) -> None:
        manifest_module = load_script(
            ASSET_MANIFEST_SCRIPT, "asset_manifest_field_type_test"
        )
        original = json.loads(ASSET_MANIFEST.read_text(encoding="utf-8"))

        with tempfile.TemporaryDirectory() as temp_dir:
            manifest_path = Path(temp_dir) / "manifest.json"
            for field in ("source", "skill", "reference"):
                with self.subTest(field=field):
                    invalid = json.loads(json.dumps(original))
                    invalid["commands"][0][field] = 123
                    manifest_path.write_text(
                        json.dumps(invalid), encoding="utf-8"
                    )

                    with self.assertRaisesRegex(ValueError, "invalid command entry"):
                        manifest_module.load_asset_manifest(manifest_path)


class VerifyCodexPluginTest(unittest.TestCase):
    def test_should_reject_core_skill_missing_from_catalog(self) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_unknown_core_skill_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "common" / "skills").mkdir(parents=True)
            verify.CODEX_NATIVE_SKILLS = frozenset()
            verify.CORE_SKILLS = frozenset({"missing-core"})

            self.assertNotEqual(verify.check_core_skill_catalog(root), 0)

    def test_should_load_core_skill_tier_from_single_manifest(self) -> None:
        manifest = json.loads(ASSET_MANIFEST.read_text(encoding="utf-8"))
        expected = frozenset(manifest["core_skills"])
        profile = load_script(PROFILE_SCRIPT, "profile_core_skill_manifest_test")
        sync = load_script(SYNC_SCRIPT, "sync_core_skill_manifest_test")
        verify = load_script(VERIFY_SCRIPT, "verify_core_skill_manifest_test")

        self.assertEqual(profile.CORE_SKILLS, expected)
        self.assertEqual(sync.CORE_SKILLS, expected)
        self.assertEqual(verify.CORE_SKILLS, expected)

    def test_should_report_shared_and_native_counts_when_requested(self) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_skill_count_report_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            for path in [
                root / "common" / "skills" / "shared" / "SKILL.md",
                root
                / "plugins"
                / "dotfile-work-codex"
                / "skills"
                / "shared"
                / "SKILL.md",
                root
                / "plugins"
                / "dotfile-work-codex-extra"
                / "skills"
                / "native"
                / "SKILL.md",
            ]:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("# skill\n", encoding="utf-8")

            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                verify.report_skill_counts(root)

            self.assertIn("shared_skills=1", output.getvalue())
            self.assertIn(
                f"codex_native_skills={len(verify.CODEX_NATIVE_SKILLS)}",
                output.getvalue(),
            )

    def test_should_detect_content_drift_when_shared_rule_changes(self) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_shared_non_skill_source_test")
        porter = load_script(PORT_SCRIPT, "port_shared_non_skill_source_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            rule = root / "common" / "rules" / "sample.md"
            rule.parent.mkdir(parents=True)
            rule.write_text("# Rule\n", encoding="utf-8")
            write_shared_command_outputs(root, porter)

            expected_rule, _role = porter.transform_source(
                rule, repo=root, kind="rule"
            )
            generated_rule = root / "codex" / "rules" / "sample.md"
            generated_rule.parent.mkdir(parents=True)
            generated_rule.write_text(
                expected_rule.rstrip() + "\n", encoding="utf-8"
            )
            self.assertEqual(
                verify.check_shared_rule_and_command_source_sync(root), 0
            )

            generated_rule.write_text(expected_rule + "stale\n", encoding="utf-8")
            self.assertNotEqual(
                verify.check_shared_rule_and_command_source_sync(root), 0
            )

    def test_should_reject_missing_shared_source_directories_when_verifying(
        self,
    ) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_missing_shared_sources_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)

            result = verify.check_shared_rule_and_command_source_sync(root)

            self.assertNotEqual(result, 0)

    def test_should_reject_manifest_drift_when_shared_command_is_missing(
        self,
    ) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_missing_shared_command_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "common" / "rules").mkdir(parents=True)
            (root / "common" / "commands").mkdir(parents=True)

            with self.assertRaisesRegex(ValueError, "missing Claude command"):
                verify.check_shared_rule_and_command_source_sync(root)

    def test_should_detect_stale_output_when_shared_rule_source_is_deleted(
        self,
    ) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_deleted_shared_rule_test")
        porter = load_script(PORT_SCRIPT, "port_deleted_shared_rule_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            rule = root / "common" / "rules" / "sample.md"
            rule.parent.mkdir(parents=True)
            rule.write_text("# Rule\n", encoding="utf-8")
            write_shared_command_outputs(root, porter)
            expected_rule, _role = porter.transform_source(
                rule, repo=root, kind="rule"
            )
            generated_rule = root / "codex" / "rules" / "sample.md"
            generated_rule.parent.mkdir(parents=True)
            generated_rule.write_text(
                expected_rule.rstrip() + "\n", encoding="utf-8"
            )

            rule.unlink()

            self.assertNotEqual(
                verify.check_shared_rule_and_command_source_sync(root), 0
            )

    def test_should_ignore_rule_bundle_and_backups_when_checking_stale_outputs(
        self,
    ) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_shared_rule_artifacts_test")
        porter = load_script(PORT_SCRIPT, "port_shared_rule_artifacts_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            rule = root / "common" / "rules" / "sample.md"
            rule.parent.mkdir(parents=True)
            rule.write_text("# Rule\n", encoding="utf-8")
            write_shared_command_outputs(root, porter)
            expected_rule, _role = porter.transform_source(
                rule, repo=root, kind="rule"
            )
            generated_rule = root / "codex" / "rules" / "sample.md"
            generated_rule.parent.mkdir(parents=True)
            generated_rule.write_text(
                expected_rule.rstrip() + "\n", encoding="utf-8"
            )
            bundle = generated_rule.parent / "RULES_BUNDLE.md"
            bundle.write_text(expected_rule.rstrip() + "\n", encoding="utf-8")
            backup = generated_rule.with_suffix(".md.bak")
            backup.write_text(expected_rule.rstrip() + "\n", encoding="utf-8")

            result = verify.check_shared_rule_and_command_source_sync(root)

            self.assertEqual(result, 0)

    def test_should_accept_catalog_when_only_declared_native_skills_are_extra(
        self,
    ) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_shared_skill_catalog_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            shared = root / "common" / "skills" / "sample" / "SKILL.md"
            shared.parent.mkdir(parents=True)
            shared.write_text("# sample\n", encoding="utf-8")
            for name in {"sample", *verify.CODEX_NATIVE_SKILLS}:
                skill = root / "codex" / "skills" / name / "SKILL.md"
                skill.parent.mkdir(parents=True)
                skill.write_text(f"# {name}\n", encoding="utf-8")

            self.assertEqual(verify.check_shared_skill_catalog(root), 0)

            unexpected = root / "codex" / "skills" / "unexpected" / "SKILL.md"
            unexpected.parent.mkdir(parents=True)
            unexpected.write_text("# unexpected\n", encoding="utf-8")
            self.assertNotEqual(verify.check_shared_skill_catalog(root), 0)

    def test_should_detect_content_drift_when_shared_skill_changes(self) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_shared_skill_source_test")
        porter = load_script(PORT_SCRIPT, "port_shared_skill_source_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "common" / "skills" / "sample" / "SKILL.md"
            source.parent.mkdir(parents=True)
            source.write_text(
                "---\nname: sample\ndescription: Sample.\n---\n\n# Sample\n",
                encoding="utf-8",
            )
            reference = source.parent / "references" / "details.md"
            reference.parent.mkdir()
            reference.write_text("# Details\n", encoding="utf-8")
            output, _role = porter.transform_source(
                source, repo=root, kind="skill"
            )
            generated = root / "codex" / "skills" / "sample" / "SKILL.md"
            generated.parent.mkdir(parents=True)
            generated.write_text(output.rstrip() + "\n", encoding="utf-8")
            reference_output, _role = porter.transform_source(
                reference, repo=root, kind="skill_resource"
            )
            generated_reference = generated.parent / "references" / "details.md"
            generated_reference.parent.mkdir()
            generated_reference.write_text(
                reference_output.rstrip() + "\n", encoding="utf-8"
            )

            self.assertEqual(verify.check_shared_skill_source_sync(root), 0)

            generated.write_text(output + "stale\n", encoding="utf-8")
            self.assertNotEqual(verify.check_shared_skill_source_sync(root), 0)

    def test_should_detect_stale_output_when_nested_skill_source_is_deleted(
        self,
    ) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_deleted_shared_resource_test")
        porter = load_script(PORT_SCRIPT, "port_deleted_shared_resource_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "common" / "skills" / "sample" / "SKILL.md"
            source.parent.mkdir(parents=True)
            source.write_text(
                "---\nname: sample\ndescription: Sample.\n---\n\n# Sample\n",
                encoding="utf-8",
            )
            reference = source.parent / "references" / "details.md"
            reference.parent.mkdir()
            reference.write_text("# Details\n", encoding="utf-8")
            output, _role = porter.transform_source(
                source, repo=root, kind="skill"
            )
            generated = root / "codex" / "skills" / "sample" / "SKILL.md"
            generated.parent.mkdir(parents=True)
            generated.write_text(output.rstrip() + "\n", encoding="utf-8")
            reference_output, _role = porter.transform_source(
                reference, repo=root, kind="skill_resource"
            )
            generated_reference = generated.parent / "references" / "details.md"
            generated_reference.parent.mkdir()
            generated_reference.write_text(
                reference_output.rstrip() + "\n", encoding="utf-8"
            )

            reference.unlink()

            self.assertNotEqual(verify.check_shared_skill_source_sync(root), 0)

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

    def test_should_detect_stale_generated_content_when_rule_aggregate_is_verified(
        self,
    ) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_rule_aggregate_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            rules = root / "codex" / "rules"
            rules.mkdir(parents=True)
            (rules / "RULES_CORE.md").write_text("# Core\n", encoding="utf-8")
            (rules / "sample.md").write_text("# Sample\n", encoding="utf-8")
            (rules / "RULES_INDEX.md").write_text("# stale\n", encoding="utf-8")
            (rules / "RULES_BUNDLE.md").write_text("# stale\n", encoding="utf-8")

            self.assertNotEqual(verify.check_rule_aggregate_sync(root), 0)

    def test_should_detect_tier_drift_when_core_and_extra_skills_are_swapped(
        self,
    ) -> None:
        verify = load_script(VERIFY_SCRIPT, "verify_skill_tier_test")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            core_name = min(verify.CORE_SKILLS)
            optional_name = "optional-only"
            for name in (core_name, optional_name):
                source = root / "codex" / "skills" / name / "SKILL.md"
                source.parent.mkdir(parents=True)
                source.write_text(f"# {name}\n", encoding="utf-8")

            wrong_core = (
                root
                / "plugins"
                / "dotfile-work-codex"
                / "skills"
                / optional_name
                / "SKILL.md"
            )
            wrong_extra = (
                root
                / "plugins"
                / "dotfile-work-codex-extra"
                / "skills"
                / core_name
                / "SKILL.md"
            )
            for path in (wrong_core, wrong_extra):
                path.parent.mkdir(parents=True)
                path.write_text(
                    (root / "codex" / "skills" / path.parent.name / "SKILL.md").read_text(
                        encoding="utf-8"
                    ),
                    encoding="utf-8",
                )

            self.assertNotEqual(verify.check_skill_sync(root), 0)


class GenerateStandardWorkflowSkillsTest(unittest.TestCase):
    def test_workflow_generator_is_idempotent(self) -> None:
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

            sync.sync_core(repo, clean=True, skills_to_copy=())
            sync.sync_extra(repo, clean=True, skills_to_copy=())
            first = snapshot()
            sync.sync_core(repo, clean=True, skills_to_copy=())
            sync.sync_extra(repo, clean=True, skills_to_copy=())
            second = snapshot()

            self.assertEqual(second, first)
            for content in second.values():
                self.assertNotIn(b"Generated at:", content)

    def test_generated_workflows_leave_blank_line_after_headings(self) -> None:
        generator = load_script(
            GENERATOR_SCRIPT, "generate_standard_workflow_spacing_test"
        )

        for name, (description, title, content) in generator.WORKFLOWS.items():
            with self.subTest(name=name):
                generated = generator.skill_body(name, description, title, content)
                self.assertNotRegex(generated, r"(?m)^#{2,6} .+\n(?!\n)")

    def test_plugin_sync_uses_manifest_and_runs_the_full_pipeline(self) -> None:
        generator = load_script(GENERATOR_SCRIPT, "generate_standard_workflow_skills_test")

        self.assertEqual(
            generator.CLAUDE_COMMAND_REFERENCES["commit-msg"],
            "common/commands/commit.md",
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
        for command in commands:
            self.assertIn(f"uv run python scripts/{command}", workflow)

    def test_generated_assets_workflow_rejects_untracked_views(self) -> None:
        workflow_path = REPO_ROOT / ".github" / "workflows" / "verify.yml"
        workflow = workflow_path.read_text(encoding="utf-8")

        self.assertIn(
            "git ls-files --others --exclude-standard -- codex/skills codex/rules",
            workflow,
        )


if __name__ == "__main__":
    unittest.main()
