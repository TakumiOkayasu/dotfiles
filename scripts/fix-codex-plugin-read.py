#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

CORE = "dotfile-work-codex"
EXTRA = "dotfile-work-codex-extra"
PLUGIN_NAMES = [CORE, EXTRA]


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        backup = path.with_suffix(path.suffix + ".bad-json.bak")
        shutil.copy2(path, backup)
        print(f"WARN: invalid JSON backed up: {path} -> {backup}: {exc}")
        return {}


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def plugin_entry(name: str) -> dict:
    # For a personal marketplace at ~/.agents/plugins/marketplace.json, Codex resolves
    # local source.path relative to the marketplace root, which is the home directory.
    # The plugin folders are copied to ~/.codex/plugins/<name>, so the path must be
    # ./.codex/plugins/<name>, not ./plugins/<name>.
    return {
        "name": name,
        "source": {"source": "local", "path": f"./.codex/plugins/{name}"},
        "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
        "category": "Productivity",
    }


def ensure_personal_marketplace(home: Path) -> Path:
    path = home / ".agents" / "plugins" / "marketplace.json"
    data = load_json(path)
    if not data:
        data = {
            "name": "dotfile-work-personal",
            "interface": {"displayName": "dotfile-work personal plugins"},
            "plugins": [],
        }
    data.setdefault("name", "dotfile-work-personal")
    data.setdefault("interface", {"displayName": "dotfile-work personal plugins"})
    data.setdefault("plugins", [])

    kept = [p for p in data.get("plugins", []) if p.get("name") not in PLUGIN_NAMES]
    kept.extend(plugin_entry(n) for n in PLUGIN_NAMES)
    data["plugins"] = kept
    write_json(path, data)
    return path


def copy_personal_plugins(repo: Path, home: Path) -> None:
    dst_root = home / ".codex" / "plugins"
    dst_root.mkdir(parents=True, exist_ok=True)
    for name in PLUGIN_NAMES:
        src = repo / "plugins" / name
        dst = dst_root / name
        if not src.exists():
            print(f"WARN: plugin source missing, skip: {src}")
            continue
        if dst.exists() or dst.is_symlink():
            if dst.is_symlink() or dst.is_file():
                dst.unlink()
            else:
                shutil.rmtree(dst)
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns("*.bak", "__pycache__", ".DS_Store"))
        print(f"installed personal plugin source: {dst}")


def patch_personal_installer(repo: Path) -> None:
    script = repo / "scripts" / "install-codex-plugin-personal.py"
    if not script.exists():
        print(f"WARN: installer not found, skip patch: {script}")
        return
    text = script.read_text(encoding="utf-8")
    original = text
    text = text.replace('"path": f"./plugins/{CORE}"', '"path": f"./.codex/plugins/{CORE}"')
    text = text.replace('"path": f"./plugins/{EXTRA}"', '"path": f"./.codex/plugins/{EXTRA}"')
    text = text.replace('"path": f"./plugins/{name}"', '"path": f"./.codex/plugins/{name}"')
    if text != original:
        backup = script.with_suffix(script.suffix + ".pre-plugin-read-hotfix.bak")
        if not backup.exists():
            shutil.copy2(script, backup)
        script.write_text(text, encoding="utf-8")
        print(f"patched personal installer: {script}")
    else:
        print(f"personal installer already patched: {script}")


def clear_dotfile_work_cache(home: Path) -> None:
    cache_root = home / ".codex" / "plugins" / "cache"
    if not cache_root.exists():
        return
    removed = 0
    for path in list(cache_root.glob(f"*/{CORE}")) + list(cache_root.glob(f"*/{EXTRA}")):
        if path.exists():
            shutil.rmtree(path)
            removed += 1
            print(f"removed stale plugin cache: {path}")
    if removed == 0:
        print("plugin cache: no stale dotfile-work entries found")


def validate(home: Path) -> bool:
    marketplace = home / ".agents" / "plugins" / "marketplace.json"
    data = load_json(marketplace)
    ok = True
    for name in PLUGIN_NAMES:
        entries = [p for p in data.get("plugins", []) if p.get("name") == name]
        if not entries:
            print(f"ERROR: marketplace entry missing: {name}")
            ok = False
            continue
        src = entries[-1].get("source", {})
        rel = src.get("path") if isinstance(src, dict) else None
        if not rel:
            print(f"ERROR: source.path missing for {name}")
            ok = False
            continue
        resolved = (home / rel[2:]).resolve() if rel.startswith("./") else Path(rel).expanduser().resolve()
        manifest = resolved / ".codex-plugin" / "plugin.json"
        if not manifest.exists():
            print(f"ERROR: manifest missing for {name}: {manifest}")
            ok = False
        else:
            try:
                payload = json.loads(manifest.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                print(f"ERROR: invalid plugin manifest {manifest}: {exc}")
                ok = False
            else:
                print(f"OK: {name} -> {manifest} ({payload.get('version', 'no-version')})")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description="Fix dotfile-work Codex plugin/read failures caused by personal marketplace path mismatch.")
    parser.add_argument("repo", nargs="?", default=".", help="dotfile-work repository root")
    parser.add_argument("--no-personal-copy", action="store_true", help="Only patch repo script and marketplace; do not copy plugins to ~/.codex/plugins")
    parser.add_argument("--no-cache-clear", action="store_true", help="Do not clear dotfile-work plugin cache")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()
    home = Path.home()
    if not (repo / "plugins").exists():
        raise SystemExit(f"ERROR: plugin directory not found under repo: {repo / 'plugins'}")

    patch_personal_installer(repo)
    if not args.no_personal_copy:
        copy_personal_plugins(repo, home)
    marketplace = ensure_personal_marketplace(home)
    print(f"patched personal marketplace: {marketplace}")
    if not args.no_cache_clear:
        clear_dotfile_work_cache(home)

    if not validate(home):
        raise SystemExit(1)

    print("\nNext:")
    print("  1. Restart Codex")
    print("  2. Open /plugins")
    print("  3. Reinstall or enable dotfile-work Codex Core")
    print("  4. Review/trust plugin hooks")
    print("  Optional CLI: codex plugin marketplace list && codex plugin marketplace upgrade")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
