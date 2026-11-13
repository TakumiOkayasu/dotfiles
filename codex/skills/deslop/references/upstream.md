# Upstream provenance

- Author: Kuu (fumiya-kume).
- Source: [deslop/skills/deslop/SKILL.md](https://github.com/fumiya-kume/claude-code/blob/923a30e9f22bcc3860a5a844845e8ae9b0b1121b/deslop/skills/deslop/SKILL.md).
- Revision: `923a30e9f22bcc3860a5a844845e8ae9b0b1121b`.
- License: GPL-3.0-only; the complete upstream license is preserved in `../LICENSE`.
- Modified for dotfiles on 2026-11-13. This is an adaptation, not an upstream Codex release.

## Runtime changes

Removed Claude-only tools, fork, agent, and model declarations. Preserved branch-diff cleanup and the short final report. Use an identified PR base before the upstream fallback order, inspect callers before deleting checks, and preserve unrelated working-tree changes.

Project instructions and the current runtime's tool/approval contracts take precedence over this workflow. No Claude tool, agent, model, permission list, or hook is registered by these Markdown instructions.
