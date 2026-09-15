#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
from types import ModuleType
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
GENERATOR_SCRIPT = REPO_ROOT / "scripts" / "generate-standard-workflow-skills.py"


def load_generator() -> ModuleType:
    spec = importlib.util.spec_from_file_location("workflow_descriptions", GENERATOR_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {GENERATOR_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TestWorkflowSkillDescriptions(unittest.TestCase):
    def test_should_render_description_without_appending_invocation_instructions(self) -> None:
        generator = load_generator()
        description = "Review a database migration."

        output = generator.skill_body(
            "review", description, "Review", "## Goal\nReview."
        )

        self.assertEqual(
            output.split("\n---\n", 1)[0],
            f"---\nname: review\ndescription: {description}",
        )

    def test_should_scope_matching_to_workflow_intent_not_generic_verbs(self) -> None:
        workflows = load_generator().WORKFLOWS
        for name, generic_triggers in {
            "feat": ("'implement'", "'add'", "'create'"),
            "review": ("'check'", "'inspect'"),
        }.items():
            with self.subTest(skill=name):
                description = workflows[name][0]
                for trigger in generic_triggers:
                    self.assertNotIn(trigger, description)
        self.assertIn("unclear", workflows["implementation-router"][0])
        self.assertIn("code", workflows["deep-review"][0])
        self.assertNotIn("First reproduce", workflows["fix"][0])

    def test_should_generate_declared_metadata_and_preserve_workflow_contracts(self) -> None:
        generator = load_generator()
        with tempfile.TemporaryDirectory() as temp_dir:
            result = subprocess.run(
                [sys.executable, str(GENERATOR_SCRIPT), "--repo", temp_dir],
                capture_output=True,
                check=False,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            skills = Path(temp_dir) / "codex" / "skills"
            self.assertEqual(
                {path.parent.name for path in skills.glob("*/SKILL.md")},
                set(generator.WORKFLOWS),
            )
            for name, (description, title, _content) in generator.WORKFLOWS.items():
                with self.subTest(skill=name):
                    output = (skills / name / "SKILL.md").read_text(encoding="utf-8")
                    metadata, body = output.split("\n---\n", 1)
                    self.assertEqual(
                        metadata, f"---\nname: {name}\ndescription: {description}"
                    )
                    self.assertTrue(body.startswith(f"\n# {title}\n"))
                    self.assertIn(generator.COMMON.strip(), body)
                    if name in generator.CLAUDE_COMMAND_REFERENCES:
                        self.assertIn(generator.CLAUDE_COMMAND_REFERENCES[name], body)
                        self.assertIn("references/claude-command.md", body)

    def test_should_keep_workflow_bodies_independent_of_description(self) -> None:
        generator = load_generator()
        for name, (description, title, content) in generator.WORKFLOWS.items():
            with self.subTest(skill=name):
                original = generator.skill_body(name, description, title, content)
                changed = generator.skill_body(
                    name, "Changed routing description.", title, content
                )
                self.assertEqual(
                    original.split("\n---\n", 1)[1],
                    changed.split("\n---\n", 1)[1],
                )


if __name__ == "__main__":
    unittest.main()
