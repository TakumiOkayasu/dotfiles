#!/usr/bin/env python3
from __future__ import annotations
import argparse, sys
from pathlib import Path

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--repo', default='.'); args=ap.parse_args(); path=Path(args.repo).resolve()/'install.sh'
    if not path.exists(): print(f'skip: install.sh not found: {path}', file=sys.stderr); return
    orig=path.read_text(); out=[]; changed=False
    for line in orig.splitlines():
        stripped=line.strip()
        if stripped.endswith(')') and 'bin/' in stripped and 'hooks/' in stripped and 'rules/*.md' in stripped and ('prompts/' in stripped or 'bin/*.sh' in stripped):
            repl=line[:len(line)-len(line.lstrip())]+'bin/*|hooks/*.sh|rules/*.md)'
            changed = changed or repl!=line; out.append(repl)
        else: out.append(line)
    text='\n'.join(out)+('\n' if orig.endswith('\n') else '')
    if changed:
        bak=path.with_name(path.name+'.pre-plugin-only.bak')
        if not bak.exists(): bak.write_text(orig)
        path.write_text(text)
    print(f'patched install.sh Codex mapping: {changed}')
if __name__=='__main__': main()
