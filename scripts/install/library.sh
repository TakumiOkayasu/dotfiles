# shellcheck shell=sh
# Definition-only modules. The caller provides the absolute INSTALLER_LIB_DIR.
# Initialization and CLI execution are explicit, separate calls.

# shellcheck source=scripts/install/context.sh
. "$INSTALLER_LIB_DIR/context.sh"
# shellcheck source=scripts/install/files.sh
. "$INSTALLER_LIB_DIR/files.sh"
# shellcheck source=scripts/install/links.sh
. "$INSTALLER_LIB_DIR/links.sh"
# shellcheck source=scripts/install/assets.sh
. "$INSTALLER_LIB_DIR/assets.sh"
# shellcheck source=scripts/install/git.sh
. "$INSTALLER_LIB_DIR/git.sh"
# shellcheck source=scripts/install/shell.sh
. "$INSTALLER_LIB_DIR/shell.sh"
# shellcheck source=scripts/install/static.sh
. "$INSTALLER_LIB_DIR/static.sh"
# shellcheck source=scripts/install/claude.sh
. "$INSTALLER_LIB_DIR/claude.sh"
# shellcheck source=scripts/install/codex.sh
. "$INSTALLER_LIB_DIR/codex.sh"
# shellcheck source=scripts/install/ui.sh
. "$INSTALLER_LIB_DIR/ui.sh"
# shellcheck source=scripts/install/main.sh
. "$INSTALLER_LIB_DIR/main.sh"
