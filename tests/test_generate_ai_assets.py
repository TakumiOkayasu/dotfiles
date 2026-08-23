#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
GENERATOR = REPO_ROOT / "scripts" / "generate-ai-assets.py"


def copy_repository(destination: Path) -> Path:
    repo = destination / "repo"
    shutil.copytree(
        REPO_ROOT,
        repo,
        ignore=shutil.ignore_patterns(
            ".git",
            ".generated",
            ".stow-work",
            "plugins",
            "__pycache__",
        ),
    )
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(
        [
            "git",
            "add",
            "--",
            "common",
            "claude",
            "codex",
            "scripts",
            "install.sh",
        ],
        cwd=repo,
        check=True,
    )
    return repo


def run_generator(repo: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(repo / "scripts" / GENERATOR.name), "--repo", str(repo)],
        cwd=repo,
        capture_output=True,
        text=True,
        timeout=60,
    )


def tree_digest(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(candidate for candidate in root.rglob("*") if candidate.is_file()):
        digest.update(path.relative_to(root).as_posix().encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


class TestGenerateAiAssets(unittest.TestCase):
    def assert_generated_views(self, generated: Path) -> None:
        claude_skill = generated / "claude" / "skills" / "tdd" / "SKILL.md"
        codex_skill = generated / "codex" / "skills" / "tdd" / "SKILL.md"
        plugin_skill = (
            generated
            / "plugins"
            / "dotfile-work-codex"
            / "skills"
            / "tdd"
            / "SKILL.md"
        )
        self.assertIn("INSTALL_GENERATION_SENTINEL", claude_skill.read_text())
        self.assertIn("INSTALL_GENERATION_SENTINEL", codex_skill.read_text())
        self.assertIn("INSTALL_GENERATION_SENTINEL", plugin_skill.read_text())
        self.assertFalse((generated / "claude" / "skills" / "untracked-only").exists())
        self.assertFalse((generated / "codex" / "skills" / "untracked-only").exists())
        self.assertTrue(
            (generated / ".agents" / "plugins" / "marketplace.json").is_file()
        )
        marketplace = json.loads(
            (generated / ".agents" / "plugins" / "marketplace.json").read_text()
        )
        self.assertEqual(
            {plugin["source"]["path"] for plugin in marketplace["plugins"]},
            {
                "./.codex/plugins/dotfile-work-codex",
                "./.codex/plugins/dotfile-work-codex-extra",
            },
        )

    def test_repository_tracks_sources_not_generated_codex_views(self) -> None:
        tracked = subprocess.run(
            ["git", "ls-files", "-z", "--", "codex/skills", "codex/rules"],
            cwd=REPO_ROOT,
            capture_output=True,
            check=True,
        ).stdout
        paths = {
            path
            for raw in tracked.split(b"\0")
            if raw
            for path in (raw.decode("utf-8"),)
            if (REPO_ROOT / path).is_file()
        }

        self.assertEqual(
            paths,
            {
                "codex/skills/rules-compliance-review/SKILL.md",
            },
        )

    def test_generates_claude_codex_and_plugin_views_from_tracked_common(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = copy_repository(Path(directory))
            shared_skill = repo / "common" / "skills" / "tdd" / "SKILL.md"
            shared_skill.write_text(
                shared_skill.read_text(encoding="utf-8") + "\nINSTALL_GENERATION_SENTINEL\n",
                encoding="utf-8",
            )
            subprocess.run(
                ["git", "add", "--", "common/skills/tdd/SKILL.md"],
                cwd=repo,
                check=True,
            )
            untracked_skill = repo / "common" / "skills" / "untracked-only"
            untracked_skill.mkdir()
            (untracked_skill / "SKILL.md").write_text(
                "---\nname: untracked-only\ndescription: must stay local\n---\n",
                encoding="utf-8",
            )

            result = run_generator(repo)

            self.assertEqual(result.returncode, 0, result.stderr)
            generated = repo / ".generated" / "ai-assets"
            self.assert_generated_views(generated)

            first_digest = tree_digest(generated)
            repeated = run_generator(repo)
            self.assertEqual(repeated.returncode, 0, repeated.stderr)
            self.assertEqual(tree_digest(generated), first_digest)

    def test_failed_generation_preserves_last_complete_tree(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = copy_repository(Path(directory))
            first = run_generator(repo)
            self.assertEqual(first.returncode, 0, first.stderr)
            generated = repo / ".generated" / "ai-assets"
            before = tree_digest(generated)

            invalid_resource = repo / "common" / "skills" / "tdd" / "invalid.bin"
            invalid_resource.write_bytes(b"unsupported tracked resource")
            subprocess.run(
                ["git", "add", "--", "common/skills/tdd/invalid.bin"],
                cwd=repo,
                check=True,
            )

            failed = run_generator(repo)

            self.assertNotEqual(failed.returncode, 0)
            self.assertEqual(tree_digest(generated), before)

    def test_installer_stops_before_home_changes_when_generation_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = copy_repository(root)
            home = root / "home"
            home.mkdir()
            invalid_resource = repo / "common" / "skills" / "tdd" / "invalid.bin"
            invalid_resource.write_bytes(b"unsupported tracked resource")
            subprocess.run(
                ["git", "add", "--", "common/skills/tdd/invalid.bin"],
                cwd=repo,
                check=True,
            )

            result = subprocess.run(
                ["sh", str(repo / "install.sh"), "-f"],
                cwd=repo,
                env={**os.environ, "HOME": str(home)},
                capture_output=True,
                text=True,
                timeout=60,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(home.iterdir()), [])

    def test_installer_uses_generated_views_for_shared_ai_assets(self) -> None:
        install_script = (REPO_ROOT / "install.sh").read_text(encoding="utf-8")

        self.assertIn("scripts/generate-ai-assets.py", install_script)
        self.assertIn(".generated/ai-assets/claude", install_script)
        self.assertIn(".generated/ai-assets/codex", install_script)
        self.assertIn(".generated/ai-assets/plugins", install_script)


if __name__ == "__main__":
    unittest.main()
