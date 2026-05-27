#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

CORE = "dotfile-work-codex"
EXTRA = "dotfile-work-codex-extra"


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def marketplace() -> dict:
    return {
        "name": "dotfile-work-personal",
        "interface": {"displayName": "dotfile-work personal plugins"},
        "plugins": [
            {"name": CORE, "source": {"source": "local", "path": f"./.codex/plugins/{CORE}"}, "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}, "category": "Productivity"},
            {"name": EXTRA, "source": {"source": "local", "path": f"./.codex/plugins/{EXTRA}"}, "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}, "category": "Productivity"},
        ],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    args = ap.parse_args()
    root = Path(args.repo).resolve()
    home = Path.home()
    dst_root = home / ".codex" / "plugins"
    dst_root.mkdir(parents=True, exist_ok=True)
    for name in [CORE, EXTRA]:
        src = root / "plugins" / name
        dst = dst_root / name
        if not src.exists():
            print(f"skip missing plugin: {src}")
            continue
        if dst.exists() or dst.is_symlink():
            if dst.is_symlink() or dst.is_file():
                dst.unlink()
            else:
                shutil.rmtree(dst)
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns("*.bak", "__pycache__"))
        print(f"installed personal plugin source: {dst}")
    write_json(home / ".agents" / "plugins" / "marketplace.json", marketplace())
    print("installed personal marketplace: ~/.agents/plugins/marketplace.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
