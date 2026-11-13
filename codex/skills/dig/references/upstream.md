# Upstream provenance

- Author: Kuu (fumiya-kume).
- Source: [dig/commands/dig.md](https://github.com/fumiya-kume/claude-code/blob/923a30e9f22bcc3860a5a844845e8ae9b0b1121b/dig/commands/dig.md).
- Revision: `923a30e9f22bcc3860a5a844845e8ae9b0b1121b`.
- License: GPL-3.0-only; the complete upstream license is preserved in `../LICENSE`.
- Modified for dotfiles on 2026-11-13. This is an adaptation, not an upstream Codex release.

## Runtime changes

Replaced Claude-only input/planning tools and fork metadata with the current host tool contract. Preserved context gathering, risk-ordered assumptions, iterative questioning, per-round integration, and completeness evaluation. Questions stop when a required answer is unavailable instead of retrying indefinitely.

Project instructions and the current runtime's tool/approval contracts take precedence over this workflow. No Claude tool, agent, model, permission list, or hook is registered by these Markdown instructions.
