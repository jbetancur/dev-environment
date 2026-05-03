#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)"

usage() {
  echo "Usage: ./run.sh [command]"
  echo ""
  echo "Commands:"
  echo "  install           Full bootstrap (default)"
  echo "  update            Upgrade packages and re-link dotfiles"
  echo "  config            Apply user.conf preferences (Citrix pattern, etc.)"
  echo "  link              Re-link dotfiles only"
  echo "  defaults          Apply macOS defaults"
  echo "  check             Verify all tools are installed and working"
  echo "  restore           Restore macOS defaults from backup"
  echo "  restore-dotfiles  Restore dotfiles from a previous backup"
  echo "  uninstall         Remove all packages, casks, and symlinks (keeps Homebrew)"
  echo ""
  echo "If no command is given, 'install' is run."
}

CMD="${1:-install}"

case "$CMD" in
  install)  bash "$SCRIPTS_DIR/install.sh" ;;
  update)   bash "$SCRIPTS_DIR/update.sh" ;;
  config)   bash "$SCRIPTS_DIR/config.sh" ;;
  link)     bash "$SCRIPTS_DIR/link.sh" ;;
  defaults) bash "$SCRIPTS_DIR/defaults.sh" ;;
  check)             bash "$SCRIPTS_DIR/check.sh" ;;
  restore)           bash "$SCRIPTS_DIR/restore-defaults.sh" ;;
  restore-dotfiles)  bash "$SCRIPTS_DIR/restore-dotfiles.sh" ;;
  uninstall)         bash "$SCRIPTS_DIR/uninstall.sh" ;;
  help|--help|-h) usage ;;
  *) echo "Unknown command: $CMD"; echo ""; usage; exit 1 ;;
esac
