#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()
TARGETS = [
    ROOT / 'codex' / 'prompts',
    ROOT / 'codex' / 'skills',
    ROOT / 'docs',
]
REPL = {
    '/prompt:list': 'prompt:list',
    '/prompt:help': 'prompt:help',
    '/prompt:feat': 'prompt:feat',
    '/prompt:fix': 'prompt:fix',
    '/prompt:deep-review': 'prompt:deep-review',
    '/prompt:review': 'prompt:review',
    '/prompt:security-review': 'prompt:security-review',
    '/prompt:commit-msg': 'prompt:commit-msg',
    '/prompt:commit': 'prompt:commit',
    '/prompt:plan': 'prompt:plan',
    '/prompt:explain': 'prompt:explain',
    '/prompt:test': 'prompt:test',
    '/prompt:refactor': 'prompt:refactor',
    '/prompt:rules': 'prompt:rules',
    '/prompt:prompt-tune': 'prompt:prompt-tune',
    '/prompt:handoff': 'prompt:handoff',
    '`/prompt:': '`prompt:',
    ' `/prompt:': ' `prompt:',
}

def patch_file(path: pathlib.Path) -> bool:
    try:
        text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        return False
    new = text
    for a, b in REPL.items():
        new = new.replace(a, b)
    # generic prose corrections
    new = new.replace('/prompt:*', 'prompt:*')
    if new == text:
        return False
    path.write_text(new, encoding='utf-8')
    return True

changed = []
for base in TARGETS:
    if not base.exists():
        continue
    for p in base.rglob('*'):
        if p.is_file() and p.suffix in {'.md', '.txt'}:
            if patch_file(p):
                changed.append(p.relative_to(ROOT))

for p in changed:
    print(f'patched: {p}')
print(f'changed={len(changed)}')
