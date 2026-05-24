#!/usr/bin/env bash
# scripts/dns-sync.sh
#
# Keeps /etc/hosts in sync with the local dev cluster DNS entries.
# Run automatically on network change via launchd (see dotfiles/.config/launchd/).
#
# When home (HOMELAB_DNS reachable):  removes managed entries from /etc/hosts
# When away (HOMELAB_DNS unreachable): adds entries so *.ACME_SUBDOMAIN.ACME_DOMAIN → 127.0.0.1
#
# Usage:
#   sudo ./scripts/dns-sync.sh          # auto-detect and sync
#   sudo ./scripts/dns-sync.sh --add    # force add entries
#   sudo ./scripts/dns-sync.sh --remove # force remove entries
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PULUMI_ENV="${SCRIPT_DIR}/../pulumi/.env"
USER_CONF="${SCRIPT_DIR}/../user.conf"

# Load domain values from pulumi/.env (primary source).
if [[ -f "$PULUMI_ENV" ]]; then
  source "$PULUMI_ENV"
elif [[ -f "$USER_CONF" ]]; then
  source "$USER_CONF"
else
  echo "pulumi/.env not found — nothing to sync"
  exit 0
fi

# pulumi/.env uses SUBDOMAIN/DOMAIN; user.conf used ACME_SUBDOMAIN/ACME_DOMAIN.
SUBDOMAIN="${SUBDOMAIN:-${ACME_SUBDOMAIN:-}}"
DOMAIN="${DOMAIN:-${ACME_DOMAIN:-}}"
HOMELAB_DNS="${HOMELAB_DNS:-10.0.10.5}"

if [[ -z "$SUBDOMAIN" || -z "$DOMAIN" ]]; then
  echo "SUBDOMAIN or DOMAIN not set in pulumi/.env — nothing to sync"
  exit 0
fi

HOSTS_FILE="/etc/hosts"
MARKER_START="# --- dev-environment dns-sync start ---"
MARKER_END="# --- dev-environment dns-sync end ---"

# Services to register — add new ones here as you create HTTPRoutes
SERVICES=(
  hubble
  grafana
  argocd
  registry
)

# Build the hosts block
hosts_block() {
  echo "$MARKER_START"
  for svc in "${SERVICES[@]}"; do
    echo "127.0.0.1 ${svc}.${SUBDOMAIN}.${DOMAIN}"
  done
  echo "$MARKER_END"
}

add_entries() {
  # Remove existing block first (handles re-runs and stale empty blocks)
  sed -i '' "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE" 2>/dev/null || true
  echo "" >> "$HOSTS_FILE"
  hosts_block >> "$HOSTS_FILE"
  echo "  dns-sync: added entries for *.${SUBDOMAIN}.${DOMAIN}"
}

remove_entries() {
  if ! grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
    echo "  dns-sync: no entries to remove"
    return
  fi
  # Remove everything between (and including) the markers
  sed -i '' "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE"
  # Remove any trailing blank line left behind
  sed -i '' -e '/^$/N;/^\n$/d' "$HOSTS_FILE"
  echo "  dns-sync: removed entries for *.${SUBDOMAIN}.${DOMAIN}"
}

is_home() {
  ping -c1 -W1 "$HOMELAB_DNS" &>/dev/null
}

# -- main --------------------------------------------------------------------
case "${1:-auto}" in
  --add)    add_entries ;;
  --remove) remove_entries ;;
  auto)
    if is_home; then
      echo "  dns-sync: home network detected — removing /etc/hosts entries"
      remove_entries
    else
      echo "  dns-sync: away from home — adding /etc/hosts entries"
      add_entries
    fi
    ;;
  *)
    echo "Usage: sudo dns-sync.sh [--add | --remove]"
    exit 1
    ;;
esac
