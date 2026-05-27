#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path
BEGIN='<!-- codex-rules-required: begin -->'; END='<!-- codex-rules-required: end -->'
BLOCK=f'''{BEGIN}

### Rules required loading

- 作業開始時、`~/.codex/rules/*.md`、repo-local `codex/rules/*.md`、project-local `.codex/rules/*.md` のうち存在するものを読む。
- `rules-inject.sh` が full content を context に注入した場合、その注入内容を読了済み rules として扱う。
- 実装 / 修正 / リファクタ / テスト追加 / レビュー / 設計では、最低限 `coding-conventions.md`, `implementation-policy.md`, `hallucination-prevention.md`, `hierarchical-architecture.md` を適用する。
- rules 未読または checksum 不一致のまま mutating tool を使わない。`rules-guard.sh` が block した場合は、先に rules を再読する。
- plugin-only 運用では workflow 起動は `$feat`, `$fix`, `$deep-review`, `$rules-required` などの `$skill` を使う。独自 `/prompt:*` や `prompt:*` 互換導線は使わない。
- 競合時は project-local rule を優先し、競合内容を完了報告に明示する。

{END}
'''
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--repo', default='.'); args=ap.parse_args(); repo=Path(args.repo).resolve(); path=repo/'codex/global_AGENTS.md'
    if not path.exists(): path.parent.mkdir(parents=True, exist_ok=True); path.write_text('# Codex Global Instructions\n\n'+BLOCK); print('created codex/global_AGENTS.md'); return
    orig=path.read_text()
    if BEGIN in orig and END in orig:
        s=orig.index(BEGIN); e=orig.index(END,s)+len(END); text=orig[:s].rstrip()+'\n\n'+BLOCK.strip()+'\n\n'+orig[e:].lstrip()
    else:
        marker='## 9. Subagents'; text=orig.replace(marker, BLOCK+'\n'+marker, 1) if marker in orig else orig.rstrip()+'\n\n'+BLOCK
    if text!=orig:
        bak=path.with_name(path.name+'.pre-plugin-only-rules.bak')
        if not bak.exists(): bak.write_text(orig)
        path.write_text(text); print('patched codex/global_AGENTS.md')
    else: print('global_AGENTS already patched')
if __name__=='__main__': main()
