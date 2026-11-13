# Upstream provenance

- Author: Kuu (fumiya-kume).
- Source: [fix-ci/commands/fix-ci.md](https://github.com/fumiya-kume/claude-code/blob/923a30e9f22bcc3860a5a844845e8ae9b0b1121b/fix-ci/commands/fix-ci.md).
- Revision: `923a30e9f22bcc3860a5a844845e8ae9b0b1121b`.
- License: GPL-3.0-only; the complete upstream license is preserved in `../LICENSE`.
- Modified for dotfiles on 2026-11-13. This is an adaptation, not an upstream Codex release.

## Runtime changes

Replaced Claude-only tools with available GitHub connectors or authenticated gh. Preserved failure diagnosis, targeted repair, exact-head CI verification, iteration, and the three-attempt stop. Removed automatic login and blanket staging. Commit/push require both existing user authorization and project permission; forbidden operations stop with a handoff.

Project instructions and the current runtime's tool/approval contracts take precedence over this workflow. No Claude tool, agent, model, permission list, or hook is registered by these Markdown instructions.
