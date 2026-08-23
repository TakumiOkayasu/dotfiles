#!/usr/bin/env python3
"""Build installable Claude and Codex assets from tracked canonical sources."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from codex_asset_manifest import AssetManifest, load_asset_manifest

ASSET_MANIFEST_PATH = SCRIPTS_DIR / "claude-command-map.json"
PIPELINE = (
    ("generate-standard-workflow-skills.py", "--overwrite"),
    (
        "port-claude-assets-to-codex.py",
        "--overwrite",
        "--no-backup",
        "--prune",
    ),
    ("apply-codex-performance-profile.py",),
    ("sync-codex-plugin.py", "--clean"),
    ("verify-codex-plugin.py",),
)
MANAGED_MARKER = b"codex-port: managed"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate verified AI-specific install assets from common/*."
    )
    parser.add_argument("--repo", default=".", help="dotfile-work repository root")
    parser.add_argument(
        "--output",
        help="published tree (default: REPO/.generated/ai-assets)",
    )
    parser.add_argument(
        "--list-target",
        choices=("claude", "codex"),
        help="print stow SRC:DEST entries from an existing generated tree",
    )
    return parser.parse_args()


def run_git(repo: Path, *args: str) -> bytes:
    result = subprocess.run(
        ["git", *args],
        cwd=repo,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(detail or f"git {' '.join(args)} failed")
    return result.stdout


def tracked_paths(repo: Path) -> tuple[Path, ...]:
    output = run_git(repo, "ls-files", "-z", "--", "common", "claude", "codex")
    return tuple(
        sorted(
            (Path(raw.decode("utf-8")) for raw in output.split(b"\0") if raw),
            key=lambda path: path.as_posix(),
        )
    )


def copy_file(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or destination.is_symlink():
        raise RuntimeError(f"generated asset collision: {destination}")
    shutil.copy2(source, destination, follow_symlinks=False)


def is_native_codex_path(
    relative: Path,
    source: Path,
    manifest: AssetManifest,
) -> bool:
    if relative.parts[:1] == ("rules",):
        return False
    if relative.parts[:1] == ("skills",):
        if len(relative.parts) < 3 or relative.parts[1] not in manifest.codex_native_skills:
            return False
        if source.is_file() and MANAGED_MARKER in source.read_bytes():
            return False
    return True


def copy_tracked_inputs(repo: Path, stage: Path, manifest: AssetManifest) -> None:
    for relative in tracked_paths(repo):
        source = repo / relative
        if not source.is_file() and not source.is_symlink():
            continue
        if relative.parts[0] == "codex" and not is_native_codex_path(
            Path(*relative.parts[1:]), source, manifest
        ):
            continue
        copy_file(source, stage / relative)


def overlay_tree(source: Path, destination: Path) -> None:
    if not source.exists():
        return
    for path in sorted(source.rglob("*")):
        if path.is_file() or path.is_symlink():
            copy_file(path, destination / path.relative_to(source))


def build_claude_view(stage: Path) -> None:
    common = stage / "common"
    claude = stage / "claude"
    overlay_tree(common / "commands", claude / "commands")
    overlay_tree(common / "rules", claude / "rules")
    overlay_tree(common / "skills", claude / "skills")
    overlay_tree(common / "hooks", claude / "hooks")
    overlay_tree(
        common / "qa-nightmare" / "checklists",
        claude / "skills" / "qa-nightmare" / "checklists",
    )
    manifest = common / "qa-nightmare" / "manifest.json"
    if manifest.is_file():
        copy_file(manifest, claude / "skills" / "qa-nightmare" / "manifest.json")


def build_codex_shared_runtime(stage: Path) -> None:
    common = stage / "common"
    codex = stage / "codex"
    overlay_tree(common / "hooks", codex / "hooks")
    overlay_tree(
        common / "qa-nightmare" / "checklists",
        codex / "agents" / "qa-nightmare" / "checklists",
    )
    manifest = common / "qa-nightmare" / "manifest.json"
    if manifest.is_file():
        copy_file(manifest, codex / "agents" / "qa-nightmare" / "manifest.json")


def run_pipeline(stage: Path) -> None:
    for script, *options in PIPELINE:
        result = subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / script), "--repo", str(stage), *options],
            cwd=stage,
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip()
            raise RuntimeError(f"{script} failed: {detail}")


def rewrite_personal_marketplace(candidate: Path) -> None:
    path = candidate / ".agents" / "plugins" / "marketplace.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    for plugin in data.get("plugins", []):
        source = plugin.get("source", {})
        plugin_path = source.get("path")
        if isinstance(plugin_path, str) and plugin_path.startswith("./plugins/"):
            source["path"] = f"./.codex/{plugin_path[2:]}"
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def codex_destination(relative: Path) -> Path | None:
    value = relative.as_posix()
    if value == "global_AGENTS.md":
        return Path(".codex/AGENTS.md")
    if value == "SUBAGENTS.md":
        return Path(".codex/SUBAGENTS.md")
    if relative.parent == Path(".") and relative.name.endswith(".config.toml"):
        return Path(".codex") / relative
    if relative.parts[:1] in (("agents",), ("bin",), ("hooks",), ("rules",)):
        return Path(".codex") / relative
    return None


def manifest_mappings(candidate: Path) -> dict[str, list[dict[str, object]]]:
    mappings: dict[str, list[dict[str, object]]] = {"claude": [], "codex": []}
    claude_root = candidate / "claude"
    for path in sorted(claude_root.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(claude_root)
        if relative == Path("CLAUDE.md"):
            continue
        if relative == Path("global_CLAUDE.md"):
            destination = Path(".claude/CLAUDE.md")
        elif relative == Path("statusline.settings.json"):
            destination = Path(".claude/statusline.json")
        else:
            destination = Path(".claude") / relative
        mappings["claude"].append(file_mapping(candidate, path, destination))

    codex_root = candidate / "codex"
    for path in sorted(codex_root.rglob("*")):
        if not path.is_file():
            continue
        destination = codex_destination(path.relative_to(codex_root))
        if destination is not None:
            mappings["codex"].append(file_mapping(candidate, path, destination))

    plugins_root = candidate / "plugins"
    for path in sorted(plugins_root.rglob("*")):
        if path.is_file():
            destination = Path(".codex/plugins") / path.relative_to(plugins_root)
            mappings["codex"].append(file_mapping(candidate, path, destination))

    marketplace = candidate / ".agents" / "plugins" / "marketplace.json"
    mappings["codex"].append(
        file_mapping(candidate, marketplace, Path(".agents/plugins/marketplace.json"))
    )
    for target, entries in mappings.items():
        destinations = [entry["destination"] for entry in entries]
        if len(destinations) != len(set(destinations)):
            raise RuntimeError(f"duplicate {target} install destination")
    return mappings


def file_mapping(candidate: Path, path: Path, destination: Path) -> dict[str, object]:
    mode = stat.S_IMODE(path.stat().st_mode)
    return {
        "source": path.relative_to(candidate).as_posix(),
        "destination": destination.as_posix(),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "mode": f"{mode:04o}",
    }


def write_manifest(candidate: Path) -> None:
    data = {"version": 1, "targets": manifest_mappings(candidate)}
    (candidate / "manifest.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def assemble_candidate(stage: Path, candidate: Path) -> None:
    for name in ("claude", "codex", "plugins", ".agents"):
        source = stage / name
        if not source.exists():
            raise RuntimeError(f"pipeline did not create {name}")
        shutil.copytree(source, candidate / name, symlinks=True)
    rewrite_personal_marketplace(candidate)
    write_manifest(candidate)


def publish(candidate: Path, output: Path) -> None:
    parent = output.parent
    parent.mkdir(parents=True, exist_ok=True)
    version = parent / f".{output.name}-{uuid.uuid4().hex}"
    os.replace(candidate, version)

    link = parent / f".{output.name}-link-{uuid.uuid4().hex}"
    previous_target: Path | None = None
    backup: Path | None = None
    try:
        link.symlink_to(version.name, target_is_directory=True)
        if output.is_symlink():
            current = Path(os.readlink(output))
            previous_target = current if current.is_absolute() else parent / current
            os.replace(link, output)
        elif output.exists():
            backup = parent / f".{output.name}-backup-{uuid.uuid4().hex}"
            os.replace(output, backup)
            try:
                os.replace(link, output)
            except OSError:  # codex-rule-ignore: restore published tree and re-raise
                os.replace(backup, output)
                raise
        else:
            os.replace(link, output)
    except OSError:  # codex-rule-ignore: remove failed unpublished tree and re-raise
        if link.is_symlink():
            link.unlink()
        if version.exists():
            shutil.rmtree(version)
        raise

    if backup is not None:
        cleanup_previous_tree(backup)
    if (
        previous_target is not None
        and previous_target.parent == parent
        and previous_target.name.startswith(f".{output.name}-")
        and previous_target.exists()
    ):
        cleanup_previous_tree(previous_target)


def cleanup_previous_tree(path: Path) -> None:
    try:
        shutil.rmtree(path)
    except OSError as error:  # codex-rule-ignore: publication succeeded; retain old tree and warn
        print(f"generate-ai-assets: warning: cannot remove {path}: {error}", file=sys.stderr)


def validate_output(repo: Path, output: Path) -> None:
    try:
        output.relative_to(repo)
    except ValueError as error:  # codex-rule-ignore: add CLI context to path failure
        raise RuntimeError("--output must be inside --repo for stow installation") from error


def list_target(repo: Path, output: Path, target: str) -> None:
    manifest_path = output / "manifest.json"
    if not manifest_path.is_file():
        raise RuntimeError(f"generated manifest not found: {manifest_path}")
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    try:
        prefix = output.relative_to(repo)
        entries = data["targets"][target]
    except (KeyError, TypeError, ValueError) as error:  # codex-rule-ignore: reject malformed manifest at CLI boundary
        raise RuntimeError(f"invalid generated manifest: {manifest_path}") from error
    for entry in entries:
        source = prefix / entry["source"]
        print(f"{source.as_posix()}:{entry['destination']}")


def generate(repo: Path, output: Path) -> None:
    manifest = load_asset_manifest(ASSET_MANIFEST_PATH)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".ai-assets-stage-", dir=output.parent
    ) as directory:
        temporary = Path(directory)
        stage = temporary / "repo"
        candidate = temporary / "candidate"
        stage.mkdir()
        candidate.mkdir()
        copy_tracked_inputs(repo, stage, manifest)
        build_claude_view(stage)
        build_codex_shared_runtime(stage)
        run_pipeline(stage)
        assemble_candidate(stage, candidate)
        publish(candidate, output)


def main() -> int:
    args = parse_args()
    repo = Path(args.repo).resolve()
    if args.output:
        requested = Path(args.output)
        requested = requested if requested.is_absolute() else repo / requested
        output = requested.parent.resolve() / requested.name
    else:
        output = repo / ".generated/ai-assets"
    try:
        if not (repo / ".git").exists():
            raise RuntimeError(f"not a git worktree: {repo}")
        validate_output(repo, output)
        if args.list_target:
            list_target(repo, output, args.list_target)
        else:
            generate(repo, output)
            print(f"generated AI assets: {output.relative_to(repo)}")
        return 0
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as error:  # codex-rule-ignore: report supported CLI failures
        print(f"generate-ai-assets: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
