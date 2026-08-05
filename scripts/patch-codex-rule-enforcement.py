#!/usr/bin/env python3
"""Patch dotfile-work for deterministic codex/rules/*.md enforcement."""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def patch_dispatcher(repo: Path) -> None:
    path = repo / "codex/hooks/hook-dispatcher.sh"
    if not path.exists():
        return
    text = read(path)
    if "rules-enforce.sh" not in text:
        text = text.replace(
            "post-tool-use)\n        run_hook context-monitor.sh\n        ;;",
            "post-tool-use)\n        run_hook rules-enforce.sh\n        run_hook context-monitor.sh\n        ;;",
        )
        text = text.replace(
            "pre-compact)\n        run_hook pre-compact-backup.sh\n        ;;",
            "pre-compact)\n        run_hook pre-compact-backup.sh\n        ;;\n    stop)\n        run_hook rules-enforce.sh\n        ;;",
        )
    elif "stop)" not in text:
        text = text.replace(
            "pre-compact)\n        run_hook pre-compact-backup.sh\n        ;;",
            "pre-compact)\n        run_hook pre-compact-backup.sh\n        ;;\n    stop)\n        run_hook rules-enforce.sh\n        ;;",
        )
    write(path, text)


def hook_handler(command: str, status: str, timeout: int = 30) -> dict:
    return {"type": "command", "command": command, "timeout": timeout, "statusMessage": status}


def add_or_replace_event(hooks: dict, event: str, matcher: str | None, handler: dict) -> None:
    items = hooks.setdefault(event, [])
    for group in items:
        if matcher is None:
            if "matcher" in group:
                continue
        elif group.get("matcher") != matcher:
            continue
        commands = [h.get("command") for h in group.setdefault("hooks", [])]
        if handler["command"] not in commands:
            group["hooks"].append(handler)
        return
    group = {"hooks": [handler]}
    if matcher is not None:
        group["matcher"] = matcher
    items.append(group)


def patch_codex_hooks_json(repo: Path) -> None:
    path = repo / "codex/hooks.json"
    if not path.exists():
        return
    data = json.loads(read(path))
    hooks = data.setdefault("hooks", {})
    dispatcher = "$HOME/.codex/hooks/hook-dispatcher.sh"
    add_or_replace_event(hooks, "PostToolUse", "Bash|apply_patch|Edit|Write|MultiEdit|ApplyPatch", hook_handler(f"{dispatcher} post-tool-use", "Checking rules compliance"))
    add_or_replace_event(hooks, "Stop", None, hook_handler(f"{dispatcher} stop", "Final rules compliance check"))
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def patch_plugin_hooks(path: Path) -> None:
    if not path.exists():
        return
    data = json.loads(read(path))
    hooks = data.setdefault("hooks", {})
    add_or_replace_event(hooks, "PostToolUse", "Bash|apply_patch|Edit|Write|MultiEdit|ApplyPatch", hook_handler("${PLUGIN_ROOT}/hooks/rules-enforce.sh", "Checking rules compliance"))
    add_or_replace_event(hooks, "Stop", None, hook_handler("${PLUGIN_ROOT}/hooks/rules-enforce.sh", "Final rules compliance check"))
    write(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def ensure_plugin_files(repo: Path) -> None:
    plugin = repo / "plugins/dotfile-work-codex"
    if not plugin.exists():
        return
    for rel in [
        "hooks/rules-enforce.sh",
        "hooks/rules-enforce.py",
        "hooks/rules-inject.sh",
        "hooks/rules-guard.sh",
    ]:
        src = repo / "codex" / rel
        dst = plugin / rel
        if src.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            if dst.suffix in {".sh", ".py"}:
                dst.chmod(dst.stat().st_mode | 0o111)
    skill_src = repo / "codex/skills/rules-compliance-review"
    skill_dst = plugin / "skills/rules-compliance-review"
    if skill_src.exists():
        if skill_dst.exists():
            shutil.rmtree(skill_dst)
        shutil.copytree(skill_src, skill_dst)
    patch_plugin_hooks(plugin / "hooks/hooks.json")


def clean_markers(repo: Path) -> None:
    for marker in [repo / "codex_tmp/.codex_rules_loaded"]:
        if marker.exists():
            marker.unlink()


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", nargs="?", default=".")
    parser.add_argument("--repo", dest="repo_option")
    args = parser.parse_args(argv[1:])
    repo = Path(args.repo_option or args.repo).resolve()
    if not (repo / ".git").exists() and not (repo / "install.sh").exists():
        print(f"not a dotfile-work repo root: {repo}", file=sys.stderr)
        return 1
    patch_dispatcher(repo)
    patch_codex_hooks_json(repo)
    patch_plugin_hooks(repo / "plugins/dotfile-work-codex/hooks/hooks.json")
    ensure_plugin_files(repo)
    clean_markers(repo)
    print("OK: deterministic rules enforcement patched")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
