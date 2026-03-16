#!/usr/bin/env bash
# Uninstall the Agentic OS Watchdog — removes from macOS launchd
# Job files in cron/jobs/ are NOT deleted.

set -euo pipefail

PLIST_NAME="com.agentic-os.watchdog"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

echo "Agentic OS Watchdog Uninstaller"
echo "================================"
echo ""

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "Watchdog is not installed (no plist found)."
  exit 0
fi

# Unload from launchd
launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Remove plist
rm -f "$PLIST_PATH"

echo "Watchdog removed."
echo ""
echo "Your job files in cron/jobs/ are untouched."
echo "To reinstall later: bash scripts/install-watchdog.sh"
