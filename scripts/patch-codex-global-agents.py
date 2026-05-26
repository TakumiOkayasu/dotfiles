#!/usr/bin/env python3
"""Insert mandatory rules-loading policy into codex/global_AGENTS.md."""

from __future__ import annotations

import argparse
from pathlib import Path

BEGIN = "<!-- codex-rules-required: begin -->"
END = "<!-- codex-rules-required: end -->"
BLOCK = f"""
{BEGIN}

### Rules required loading

- 作業開始時、`~/.codex/rules/*.md`、repo-local `codex/rules/*.md`、project-local `.codex/rules/*.md` のうち存在するものを読む。
- `rules-inject.sh` が full content を context に注入した場合、その注入内容を読了済み rules として扱う。
- 実装 / 修正 / リファクタ / テスト追加 / レビュー / 設計では、最低限 `coding-conventions.md`, `implementation-policy.md`, `hallucination-prevention.md`, `hierarchical-architecture.md` を適用する。
- rules 未読または checksum 不一致のまま mutating tool を使わない。`rules-guard.sh` が block した場合は、先に rules を再読する。
- 競合時は project-local rule を優先し、競合内容を完了報告に明示する。

{END}
"""


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--repo", default=".")
    return p.parse_args()


def main() -> int:
    args = parse_args()
    repo = Path(args.repo).resolve()
    path = repo / "codex" / "global_AGENTS.md"
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("# Codex Global Instructions\n\n" + BLOCK + "\n", encoding="utf-8")
        print("created codex/global_AGENTS.md")
        return 0

    text = path.read_text(encoding="utf-8")
    if BEGIN in text:
        print("global_AGENTS already patched")
        return 0

    marker = "## 9. Subagents"
    if marker in text:
        text = text.replace(marker, BLOCK + "\n" + marker, 1)
    else:
        text = text.rstrip() + "\n\n" + BLOCK + "\n"

    backup = path.with_name(path.name + ".pre-rules-port.bak")
    if not backup.exists():
        backup.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
    path.write_text(text, encoding="utf-8")
    print("patched codex/global_AGENTS.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
