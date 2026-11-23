"""Behavior tests use invented models, never the account's live model catalog."""
from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "update-codex-models.py"
MODULE = runpy.run_path(str(SCRIPT))


def model(slug: str, *, visibility: str = "list", plan: str = "test",
          minimum: str = "0.100.0", efforts: tuple[str, ...] = ("medium", "high")) -> dict:
    return {
        "slug": slug, "visibility": visibility, "available_in_plans": [plan],
        "minimal_client_version": minimum,
        "supported_reasoning_levels": [{"effort": effort} for effort in efforts],
    }


class TestCodexModelUpdates(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name)
        (self.repo / "codex" / "agents").mkdir(parents=True)
        self.template = self.repo / "codex" / "config.toml.template"
        self.original = (
            '# keep this comment\nmodel = "gpt-1-sol" # selected model\n'
            'model_reasoning_effort = "high"\n'
            '[agents]\ndefault_subagent_model = "gpt-1-luna"\n'
            'default_subagent_reasoning_effort = "medium"\n'
        )
        self.template.write_text(self.original, encoding="utf-8")
        self.catalog = {"models": [
            model("gpt-1-sol"), model("gpt-2.9-sol"), model("gpt-2.10-sol"),
            model("gpt-1-luna"), model("gpt-2-luna"), model("gpt-99-astra"),
        ]}

    def plan(self, catalog: dict | None = None) -> dict[Path, str]:
        return MODULE["plan_updates"](self.repo, catalog or self.catalog, "test", "0.200.0")

    def test_updates_only_declared_same_family_ids_and_preserves_settings(self) -> None:
        """Expected: numeric ordering picks 2.10, with effort and comments intact."""
        expected = self.original.replace("gpt-1-sol", "gpt-2.10-sol").replace(
            "gpt-1-luna", "gpt-2-luna"
        )
        self.assertEqual(self.plan(), {self.template: expected})
        self.assertEqual(self.template.read_text(encoding="utf-8"), self.original)

    def test_excludes_hidden_wrong_plan_and_newer_client_requirements(self) -> None:
        """Expected: each unavailable candidate is excluded rather than selected."""
        self.catalog["models"] += [
            model("gpt-9-sol", visibility="hide"),
            model("gpt-10-sol", plan="other"),
            model("gpt-11-sol", minimum="0.201.0"),
        ]
        self.assertIn('model = "gpt-2.10-sol"', self.plan()[self.template])

    def test_updates_profiles_and_agents_without_touching_instruction_examples(self) -> None:
        """Expected: real assignments change, quoted instruction examples stay literal."""
        agent = self.repo / "codex" / "agents" / "reviewer.toml"
        content = (
            "developer_instructions = '''\n"
            'model = "gpt-1-sol"\n'
            "'''\nmodel = 'gpt-1-sol'\nmodel_reasoning_effort = 'high'\n"
        )
        agent.write_text(content, encoding="utf-8")
        profile = self.repo / "codex" / "balanced.config.toml"
        profile.write_text('model = "gpt-1-sol"\nmodel_reasoning_effort = "high"\n')
        changes = self.plan()
        self.assertEqual(changes[agent], content.replace("model = 'gpt-1-sol'", "model = 'gpt-2.10-sol'"))
        self.assertEqual(changes[profile], 'model = "gpt-2.10-sol"\nmodel_reasoning_effort = "high"\n')

    def test_is_idempotent_after_applying_the_plan(self) -> None:
        """Expected: another run creates no changes or repeated update PR."""
        for path, content in self.plan().items():
            path.write_text(content, encoding="utf-8")
        self.assertEqual(self.plan(), {})

    def test_does_not_downgrade_a_newer_configured_model(self) -> None:
        """Expected: an older catalog leaves a newer explicit selection unchanged."""
        self.template.write_text(self.original.replace("gpt-1-sol", "gpt-3-sol"))
        self.assertIn('model = "gpt-3-sol"', self.plan()[self.template])

    def test_rejects_an_existing_model_that_requires_a_newer_cli(self) -> None:
        """Expected: an incompatible existing pin fails rather than remaining silently."""
        self.catalog["models"] = [
            model("gpt-0-sol"), model("gpt-1-sol", minimum="0.201.0"),
            model("gpt-1-luna"),
        ]
        with self.assertRaisesRegex(ValueError, "requires Codex CLI"):
            self.plan()

    def test_rejects_unknown_family_without_guessing_a_model_id(self) -> None:
        """Expected: an incomplete ID fails explicitly instead of guessing Sol/Astra."""
        self.template.write_text(self.original.replace("gpt-1-sol", "gpt-2"))
        with self.assertRaisesRegex(ValueError, "model ID"):
            self.plan()

    def test_rejects_missing_candidates_and_unsupported_effort_before_writes(self) -> None:
        """Expected: incompatible upgrades fail and every source file stays unchanged."""
        for catalog in (
            {"models": [model("gpt-2-luna")]},
            {"models": [model("gpt-2-sol", efforts=("medium",)), model("gpt-2-luna")]},
        ):
            with self.subTest(catalog=catalog), self.assertRaises(ValueError):
                self.plan(catalog)
            self.assertEqual(self.template.read_text(encoding="utf-8"), self.original)

    def test_rejects_malformed_catalogs(self) -> None:
        """Expected: changed upstream schema cannot silently produce a successful no-op."""
        for catalog in ({"models": []}, {"models": "invalid"}, {"models": [{"slug": "gpt-2-sol"}]}):
            with self.subTest(catalog=catalog), self.assertRaises(ValueError):
                self.plan(catalog)

    def test_cli_defaults_to_preview_and_writes_only_when_requested(self) -> None:
        """Expected: preview preserves files; --write applies the same validated plan."""
        catalog = self.repo / "catalog.json"
        catalog.write_text(json.dumps(self.catalog), encoding="utf-8")
        args = ["--repo", str(self.repo), "--catalog", str(catalog),
                "--cli-version", "0.200.0", "--plan", "test"]
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(MODULE["main"](args), 0)
        self.assertEqual(self.template.read_text(encoding="utf-8"), self.original)
        self.assertIn("0.100.0", output.getvalue())
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(MODULE["main"]([*args, "--write"]), 0)
        self.assertIn('model = "gpt-2.10-sol"', self.template.read_text(encoding="utf-8"))

    def test_fetches_catalog_from_the_latest_stable_release_not_main(self) -> None:
        """Expected: the catalog URL uses the verified non-prerelease release tag."""
        release = {"tag_name": "rust-v0.200.0", "draft": False, "prerelease": False}
        with patch("urllib.request.urlopen", side_effect=[
            io.BytesIO(json.dumps(release).encode()),
            io.BytesIO(json.dumps(self.catalog).encode()),
        ]) as request:
            catalog, version, source = MODULE["fetch_catalog"]()
        self.assertEqual(catalog, self.catalog)
        self.assertEqual(version, "0.200.0")
        self.assertIn("/rust-v0.200.0/codex-rs/models-manager/models.json", source)
        self.assertEqual(request.call_count, 2)

    def test_rejects_prerelease_metadata(self) -> None:
        """Expected: an unexpected prerelease cannot become the update baseline."""
        release = {"tag_name": "rust-v0.200.0-alpha.1", "draft": False, "prerelease": True}
        with patch("urllib.request.urlopen", return_value=io.BytesIO(json.dumps(release).encode())):
            with self.assertRaises(ValueError):
                MODULE["fetch_catalog"]()


if __name__ == "__main__":
    unittest.main()
