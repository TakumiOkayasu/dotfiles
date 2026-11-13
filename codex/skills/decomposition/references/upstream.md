# Upstream provenance

- Author: Kuu (fumiya-kume).
- Source: [decomposition/commands/decomposition.md](https://github.com/fumiya-kume/claude-code/blob/923a30e9f22bcc3860a5a844845e8ae9b0b1121b/decomposition/commands/decomposition.md).
- Revision: `923a30e9f22bcc3860a5a844845e8ae9b0b1121b`.
- License: GPL-3.0-only; the complete upstream license is preserved in `../LICENSE`.
- Modified for dotfiles on 2026-11-13. This is an adaptation, not an upstream Codex release.

## Runtime changes

Replaced Claude-only input/planning tools and fork metadata with the current host tool contract. Preserved repository exploration, component/dependency analysis, iterative interviews, What/Where/How/Why/Verify descriptions, pending task recording, and review loops.

Project instructions and the current runtime's tool/approval contracts take precedence over this workflow. No Claude tool, agent, model, permission list, or hook is registered by these Markdown instructions.
