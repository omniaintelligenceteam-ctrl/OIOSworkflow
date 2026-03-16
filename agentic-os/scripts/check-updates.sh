#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# Agentic OS — Check for Updates
# Shows if upstream has new commits without pulling them.
#
# Usage: bash scripts/check-updates.sh
# ==========================================================

# ---------- Colors ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ---------- Helpers ----------
info()    { printf "${CYAN}  %s${NC}\n" "$1"; }
success() { printf "${GREEN}  ✓ %s${NC}\n" "$1"; }
warn()    { printf "${YELLOW}  → %s${NC}\n" "$1"; }
fail()    { printf "${RED}  ✗ %s${NC}\n" "$1"; }

# ---------- Repo root from script location ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) REPO_ROOT="$(cygpath -m "$REPO_ROOT")" ;; esac
cd "$REPO_ROOT"

# ---------- Verify git repo ----------
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    fail "Not a git repository. Run this from the Agentic OS root."
    exit 1
fi

echo ""
printf "${CYAN}${BOLD}  Agentic OS — Checking for updates...${NC}\n"
echo ""

# ---------- Fetch latest from origin ----------
info "Fetching from origin..."
if ! git fetch origin main --quiet 2>/dev/null; then
    fail "Could not reach origin. Check your internet connection."
    exit 1
fi

# ---------- Compare local vs remote ----------
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main 2>/dev/null) || {
    fail "Could not find origin/main. Is the remote configured?"
    exit 1
}

if [[ "$LOCAL" == "$REMOTE" ]]; then
    echo ""
    success "You're up to date!"
    echo ""
    exit 0
fi

BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)

if [[ "$BEHIND" -eq 0 ]]; then
    success "You're up to date! (local is ahead or diverged)"
    echo ""
    exit 0
fi

echo ""
printf "${YELLOW}  You are ${BOLD}%s commit(s)${NC}${YELLOW} behind origin/main.${NC}\n" "$BEHIND"
echo ""
info "New commits:"
git log --oneline HEAD..origin/main | while IFS= read -r line; do
    printf "    ${BOLD}•${NC} %s\n" "$line"
done
echo ""
printf "  Run ${BOLD}bash scripts/update.sh${NC} to update.\n"
echo ""
