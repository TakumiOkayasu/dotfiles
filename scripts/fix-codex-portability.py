#!/usr/bin/env python3
"""Fix common Claude-to-Codex portability issues under codex/.

Default mode is a dry run. Use --apply to modify files and remove generated
or orphaned paths.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


REPLACEMENTS = (
    ("~/.claude", "~/.codex"),
    (".claude/progress.md", ".codex/progress.md"),
    ("claude_tmp", "codex_tmp"),
    ("~/.claude/CLAUDE.md", "~/.codex/AGENTS.md"),
    ("CLAUDE.md", "AGENTS.md"),
    ("Claude Code セッション", "Codex セッション"),
    ("Claude セッション", "Codex セッション"),
    ("ClaudeCode (ここ)", "Codex (ここ)"),
    ("ClaudeCode", "Codex"),
    ("Claude Code", "Codex"),
    ("Task / Agent tool", "spawn_agent"),
    ("Task tool", "spawn_agent"),
    ("general-purpose subagent", "Codex subagent"),
    (
        "`~/.codex/rules/*` は @import 済みで context にある",
        "`~/.codex/rules/*` は Codex が自動 import しないため、必要に応じて明示的に読む",
    ),
    (
        "`~/.codex/rules/*` は @import 済みで既に context にある。読み直さず、今回の差分で違反しうる具体パターンを観点別に列挙する。",
        "`~/.codex/rules/*` は Codex が自動 import しない。必要な rule を明示的に読み、今回の差分で違反しうる具体パターンを観点別に列挙する。",
    ),
)

TARGET_DIRS = (
    "codex/prompts",
    "codex/rules",
    "codex/skills",
)

TEXT_SUFFIXES = {".md", ".sh", ".json", ".toml"}

GITIGNORE_LINES = (
    "codex_tmp/",
    "codex/progress.md",
    "codex/checkpoints/",
    "codex/agents-tmp/",
)


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[1]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_if_changed(path: Path, text: str, apply: bool, ops: list[str]) -> None:
    old = read_text(path)
    if text == old:
        return

    ops.append(f"update {path}")
    if apply:
        path.write_text(text, encoding="utf-8")


def collect_codex_text_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for rel in TARGET_DIRS:
        base = root / rel
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if path.is_file() and path.suffix in TEXT_SUFFIXES:
                files.append(path)

    return sorted(set(files))


def apply_text_replacements(root: Path, apply: bool, ops: list[str]) -> None:
    for path in collect_codex_text_files(root):
        text = read_text(path)
        new_text = text
        for old, new in REPLACEMENTS:
            new_text = new_text.replace(old, new)
        write_if_changed(path, new_text, apply, ops)


def fix_codex_config_info(root: Path, apply: bool, ops: list[str]) -> None:
    path = root / "codex/bin/codex-config-info.sh"
    if not path.exists():
        return

    text = read_text(path)
    text = text.replace(
        'SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P || dirname "$0")',
        'if SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P); then\n'
        "    :\n"
        "else\n"
        '    SCRIPT_DIR=$(dirname "$0")\n'
        "fi",
    )
    text = text.replace(
        '                "$PROJECT_SETTINGS") label="Project: codex/settings.json" ;;\n'
        '                "$PROJECT_LOCAL_SETTINGS") label="Local: codex/settings.local.json" ;;\n',
        '                "$PROJECT_SETTINGS") label="Project: .codex/hooks.json" ;;\n'
        '                "$PROJECT_LOCAL_SETTINGS") label="Local: .codex/hooks.local.json" ;;\n',
    )
    text = text.replace('echo -n "  "', 'printf "%s" "  "')
    text = text.replace('echo -n \'  "skills": \'', 'printf "%s" \'  "skills": \'')
    text = text.replace('echo -n \'  "failures": \'', 'printf "%s" \'  "failures": \'')

    marker = '    done\n}\n\n'
    default_all = (
        '    done\n\n'
        '    if [ "$SHOW_HOOKS$SHOW_SKILLS$SHOW_FAILURES" = "falsefalsefalse" ]; then\n'
        "        SHOW_HOOKS=true\n"
        "        SHOW_SKILLS=true\n"
        "        SHOW_FAILURES=true\n"
        "    fi\n"
        "}\n\n"
    )
    if default_all not in text and marker in text:
        text = text.replace(marker, default_all, 1)

    write_if_changed(path, text, apply, ops)


def fix_shellcheck_patterns(root: Path, apply: bool, ops: list[str]) -> None:
    replacements = {
        "codex/hooks/hook-dispatcher.sh": (
            (
                'SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P || dirname "$0")',
                'if SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P); then\n'
                "    :\n"
                "else\n"
                '    SCRIPT_DIR=$(dirname "$0")\n'
                "fi",
            ),
        ),
        "codex/hooks/session-start-reminder.sh": (
            (
                'SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P || dirname "$0")',
                'if SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P); then\n'
                "    :\n"
                "else\n"
                '    SCRIPT_DIR=$(dirname "$0")\n'
                "fi",
            ),
        ),
        "codex/hooks/project-environment-check.sh": (
            ("git rev-parse --abbrev-ref --symbolic-full-name @{u}", "git rev-parse --abbrev-ref --symbolic-full-name '@{u}'"),
            ("git rev-list --count @{u}..HEAD", "git rev-list --count '@{u}..HEAD'"),
        ),
    }

    for rel, pairs in replacements.items():
        path = root / rel
        if not path.exists():
            continue
        text = read_text(path)
        for old, new in pairs:
            text = text.replace(old, new)
        write_if_changed(path, text, apply, ops)


def ensure_gitignore(root: Path, apply: bool, ops: list[str]) -> None:
    path = root / ".gitignore"
    if path.exists():
        text = read_text(path)
    else:
        text = ""

    additions = [line for line in GITIGNORE_LINES if line not in text.splitlines()]
    if not additions:
        return

    suffix = "" if not text or text.endswith("\n") else "\n"
    new_text = text + suffix + "# Codex generated state\n" + "\n".join(additions) + "\n"
    write_if_changed(path, new_text, apply, ops)


def remove_path(path: Path, apply: bool, ops: list[str]) -> None:
    if not path.exists():
        return
    ops.append(f"remove {path}")
    if not apply:
        return
    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()


def remove_generated_paths(root: Path, apply: bool, ops: list[str]) -> None:
    remove_path(root / "codex/agents-tmp", apply, ops)

    codex_dir = root / "codex"
    if codex_dir.exists():
        for path in codex_dir.rglob(".DS_Store"):
            remove_path(path, apply, ops)

    skills_dir = root / "codex/skills"
    if not skills_dir.exists():
        return
    for path in sorted(skills_dir.iterdir()):
        if path.is_dir() and not (path / "SKILL.md").exists():
            remove_path(path, apply, ops)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=repo_root_from_script())
    parser.add_argument("--apply", action="store_true", help="modify files instead of printing a dry run")
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / "install.sh").exists() or not (root / "codex").exists():
        raise SystemExit(f"not a dotfile-work repository: {root}")

    ops: list[str] = []
    apply_text_replacements(root, args.apply, ops)
    fix_codex_config_info(root, args.apply, ops)
    fix_shellcheck_patterns(root, args.apply, ops)
    ensure_gitignore(root, args.apply, ops)
    remove_generated_paths(root, args.apply, ops)

    if ops:
        print("\n".join(ops))
    else:
        print("no changes needed")

    if not args.apply:
        print("\ndry run only; rerun with --apply to modify files")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
