#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Agentic OS — Installer
# =============================================================================
# Main installer for new users. Run after `git clone`:
#   bash scripts/install.sh
#
# What it does:
#   1. Checks prerequisites (git, bash, python3)
#   2. Creates .env from .env.example if missing
#   3. Runs scripts/setup.sh for system dependencies
#   4. Presents a skill selection menu
#   5. Auto-resolves skill dependencies
#   6. Removes unselected optional skills
#   7. Writes installed.json with the user's choices
#   8. Prints next steps
#
# Idempotent — safe to run multiple times.
# =============================================================================

# ---------- Resolve repo root from script location ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Convert MSYS/Git Bash paths to Windows-native for Python compatibility
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) REPO_ROOT="$(cygpath -m "$REPO_ROOT")" ;;
esac

# ---------- Colors ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ---------- Helpers ----------
info()    { printf "${CYAN}%s${NC}\n" "$1"; }
success() { printf "${GREEN}  ✓ %s${NC}\n" "$1"; }
warn()    { printf "${YELLOW}  ! %s${NC}\n" "$1"; }
fail()    { printf "${RED}  ✗ %s${NC}\n" "$1"; }

# ---------- Paths ----------
CATALOG="$REPO_ROOT/.claude/skills/_catalog/catalog.json"
INSTALLED_JSON="$REPO_ROOT/.claude/skills/_catalog/installed.json"
SKILLS_DIR="$REPO_ROOT/.claude/skills"

# =============================================================================
# 1. Welcome banner
# =============================================================================
clear 2>/dev/null || true
echo ""
printf "${CYAN}${BOLD}"
cat << 'BANNER'
    ╔══════════════════════════════════════════════╗
    ║                                              ║
    ║            A G E N T I C   O S               ║
    ║                                              ║
    ║      Your AI-powered business assistant      ║
    ║                                              ║
    ╚══════════════════════════════════════════════╝
BANNER
printf "${NC}"
echo ""
printf "${DIM}  Installer v1.0${NC}\n"
echo ""

# =============================================================================
# 2. Check prerequisites
# =============================================================================
info "Checking prerequisites..."
echo ""

PREREQ_FAIL=0
PYTHON_CMD="python3"

# Git
printf "  git .......... "
if command -v git &>/dev/null; then
    printf "${GREEN}$(git --version | awk '{print $3}')${NC}\n"
else
    printf "${RED}not found${NC}\n"
    fail "Install git: https://git-scm.com/downloads"
    PREREQ_FAIL=1
fi

# Bash (version 3+ is fine for this script)
printf "  bash ......... "
if command -v bash &>/dev/null; then
    printf "${GREEN}${BASH_VERSION}${NC}\n"
else
    printf "${RED}not found${NC}\n"
    fail "bash is required"
    PREREQ_FAIL=1
fi

# Python 3 — check python3 first, fall back to python (Windows often uses 'python')
printf "  python3 ...... "
if command -v python3 &>/dev/null; then
    printf "${GREEN}$(python3 --version 2>&1 | awk '{print $2}')${NC}\n"
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PY_VER=$(python --version 2>&1 | awk '{print $2}')
    case "$PY_VER" in
        3.*) printf "${GREEN}${PY_VER} (as 'python')${NC}\n"
             PYTHON_CMD="python" ;;
        *)   printf "${RED}found python ${PY_VER} — need Python 3${NC}\n"
             fail "Install Python 3: https://www.python.org/downloads/"
             PREREQ_FAIL=1 ;;
    esac
else
    printf "${RED}not found${NC}\n"
    fail "Install Python 3: https://www.python.org/downloads/"
    PREREQ_FAIL=1
fi

echo ""

if [[ $PREREQ_FAIL -ne 0 ]]; then
    fail "Missing prerequisites — install them and re-run this script."
    exit 1
fi

success "All prerequisites met"
echo ""

# =============================================================================
# 3. Create .env from .env.example if missing
# =============================================================================
info "Checking environment..."
echo ""

if [[ -f "$REPO_ROOT/.env" ]]; then
    success ".env already exists"
else
    if [[ -f "$REPO_ROOT/.env.example" ]]; then
        cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
        success "Created .env from .env.example"
        warn "Add your API keys to .env later — skills work without them"
    else
        warn "No .env.example found — skipping .env creation"
    fi
fi
echo ""

# =============================================================================
# 4. Run system dependency setup
# =============================================================================
info "Installing system dependencies..."
echo ""

if [[ -f "$REPO_ROOT/scripts/setup.sh" ]]; then
    PYTHON_CMD="$PYTHON_CMD" bash "$REPO_ROOT/scripts/setup.sh"
else
    warn "scripts/setup.sh not found — skipping dependency install"
fi
echo ""

# =============================================================================
# 5. Verify catalog exists
# =============================================================================
if [[ ! -f "$CATALOG" ]]; then
    fail "Catalog not found at $CATALOG"
    fail "Your clone may be incomplete. Try: git checkout -- .claude/skills/_catalog/"
    exit 1
fi

# =============================================================================
# 6. Parse catalog and build skill menu
# =============================================================================
# We use Python to parse JSON since jq may not be installed.
# The python script outputs structured data the bash script consumes.

# Extract core skills list (tr -d '\r' strips Windows carriage returns)
CORE_SKILLS=$($PYTHON_CMD -c "
import json, sys
with open('$CATALOG') as f:
    cat = json.load(f)
for s in cat['core_skills']:
    print(s)
" | tr -d '\r')

# Extract optional skills grouped by category, with metadata
# Output format: name|category|description|services|dependencies
OPTIONAL_SKILLS=$($PYTHON_CMD -c "
import json
with open('$CATALOG') as f:
    cat = json.load(f)
core = set(cat['core_skills'])
order = {'utility': 1, 'strategy': 2, 'execution': 3, 'visual': 4, 'operations': 5}
skills = []
for name, info in cat['skills'].items():
    if name not in core:
        skills.append((
            order.get(info['category'], 99),
            info['category'],
            name,
            info['description'],
            ','.join(info.get('requires_services', [])),
            ','.join(info.get('dependencies', []))
        ))
skills.sort(key=lambda x: (x[0], x[2]))
for s in skills:
    print(f'{s[2]}|{s[1]}|{s[3]}|{s[4]}|{s[5]}')
" | tr -d '\r')

# =============================================================================
# 7. Display the skill selection menu
# =============================================================================
echo ""
printf "${CYAN}${BOLD}═══════════════════════════════════════════════${NC}\n"
printf "${CYAN}${BOLD}  Skill Selection${NC}\n"
printf "${CYAN}${BOLD}═══════════════════════════════════════════════${NC}\n"
echo ""

# Show core skills (descriptions hardcoded to avoid encoding issues on Windows)
printf "${BOLD}  CORE (always installed):${NC}\n"
while IFS= read -r skill; do
    case "$skill" in
        meta-skill-creator) desc="Build and iterate on new skills" ;;
        meta-wrap-up)       desc="End-of-session wrap-up" ;;
        mkt-brand-voice)    desc="Extract or build your brand voice" ;;
        mkt-positioning)    desc="Develop positioning angles" ;;
        mkt-icp)            desc="Define ideal customer profiles" ;;
        *)                  desc="" ;;
    esac
    printf "    ${GREEN}✓${NC} %-26s ${DIM}-- %s${NC}\n" "$skill" "$desc"
done <<< "$CORE_SKILLS"
echo ""

# Build arrays for optional skills
declare -a SKILL_NAMES=()
declare -a SKILL_CATEGORIES=()
declare -a SKILL_DESCRIPTIONS=()
declare -a SKILL_SERVICES=()
declare -a SKILL_DEPS=()

while IFS='|' read -r name category description services deps; do
    [[ -z "$name" ]] && continue
    SKILL_NAMES+=("$name")
    SKILL_CATEGORIES+=("$category")
    SKILL_DESCRIPTIONS+=("$description")
    SKILL_SERVICES+=("$services")
    SKILL_DEPS+=("$deps")
done <<< "$OPTIONAL_SKILLS"

# Display grouped by category
printf "${BOLD}  OPTIONAL — enter numbers to toggle, or \"all\" to select everything:${NC}\n"
echo ""

CURRENT_CATEGORY=""
NUM=0
for i in "${!SKILL_NAMES[@]}"; do
    NUM=$((i + 1))
    cat="${SKILL_CATEGORIES[$i]}"

    # Print category header when it changes
    if [[ "$cat" != "$CURRENT_CATEGORY" ]]; then
        # Capitalize first letter of category (pure bash, no Python)
        first="$(echo "${cat:0:1}" | tr '[:lower:]' '[:upper:]')"
        cat_display="${first}${cat:1}"
        printf "    ${BOLD}%s:${NC}\n" "$cat_display"
        CURRENT_CATEGORY="$cat"
    fi

    # Build the service note (e.g., "needs FIRECRAWL_API_KEY")
    svc_note=""
    if [[ -n "${SKILL_SERVICES[$i]}" ]]; then
        svc_note=" ${DIM}(needs ${SKILL_SERVICES[$i]})${NC}"
    fi

    # Build the dependency note (e.g., "auto-adds: tool-humanizer")
    dep_note=""
    if [[ -n "${SKILL_DEPS[$i]}" ]]; then
        dep_note=" ${DIM}(auto-adds: ${SKILL_DEPS[$i]})${NC}"
    fi

    printf "     ${BOLD}[%2d]${NC} %-26s ${DIM}— %s${NC}%b%b\n" \
        "$NUM" "${SKILL_NAMES[$i]}" "${SKILL_DESCRIPTIONS[$i]}" "$svc_note" "$dep_note"
done
echo ""

# =============================================================================
# 8. Collect user selection
# =============================================================================
printf "  Enter numbers separated by spaces (e.g., \"1 5 6\"), \"all\", or press Enter for core only: "
read -r USER_INPUT

# =============================================================================
# 9-12. Resolve deps, remove skills, write installed.json (via python3)
# =============================================================================
# Delegate all selection logic to python3 for bash 3 compatibility.
# Python handles: parsing input, resolving deps, computing install/remove lists,
# removing folders, and writing installed.json.

echo ""

$PYTHON_CMD << PYEOF
import json, datetime, os, sys, shutil

catalog_path = "$CATALOG"
installed_json = "$INSTALLED_JSON"
skills_dir = "$SKILLS_DIR"
user_input = """$USER_INPUT""".strip()

with open(catalog_path) as f:
    catalog = json.load(f)

core = catalog['core_skills']
optional = catalog['skills']

# Build ordered list of optional skill names (same order as menu)
order = {'utility': 1, 'strategy': 2, 'execution': 3, 'visual': 4, 'operations': 5}
skill_list = sorted(optional.keys(), key=lambda n: (order.get(optional[n]['category'], 99), n))

# Parse user selection
selected = set()
if user_input.lower() == 'all':
    selected = set(skill_list)
elif user_input:
    for token in user_input.split():
        try:
            num = int(token)
            if 1 <= num <= len(skill_list):
                selected.add(skill_list[num - 1])
            else:
                print(f"  \033[1;33m! Ignoring invalid selection: {token}\033[0m")
        except ValueError:
            print(f"  \033[1;33m! Ignoring invalid selection: {token}\033[0m")

# Resolve dependencies
deps_added = []
to_check = list(selected)
while to_check:
    skill = to_check.pop()
    for dep in optional.get(skill, {}).get('dependencies', []):
        if dep not in selected and dep in optional:
            selected.add(dep)
            deps_added.append(f"{dep} (required by {skill})")
            to_check.append(dep)

if deps_added:
    print("  \033[0;36mAuto-resolved dependencies:\033[0m")
    for note in deps_added:
        print(f"    \033[0;32m+\033[0m {note}")
    print()

# Build final lists
installed_skills = sorted(set(core) | selected)
removed_skills = sorted(set(skill_list) - selected)

# Remove unselected skill folders
if removed_skills:
    print("  \033[0;36mRemoving unselected skills...\033[0m")
    for skill in removed_skills:
        skill_path = os.path.join(skills_dir, skill)
        if os.path.isdir(skill_path):
            shutil.rmtree(skill_path)
            print(f"    \033[2mremoved {skill}\033[0m")
    print()

# Write installed.json
os.makedirs(os.path.dirname(installed_json), exist_ok=True)
data = {
    'installed_at': datetime.date.today().isoformat(),
    'version': catalog['version'],
    'installed_skills': installed_skills,
    'removed_skills': removed_skills
}
with open(installed_json, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

# Print summary
print()
print("\033[0;36m\033[1m═══════════════════════════════════════════════\033[0m")
print("\033[0;36m\033[1m  Installation Complete\033[0m")
print("\033[0;36m\033[1m═══════════════════════════════════════════════\033[0m")
print()
print(f"  \033[1mInstalled skills ({len(installed_skills)}):\033[0m")
for s in installed_skills:
    print(f"    \033[0;32m✓\033[0m {s}")
print()

if removed_skills:
    print(f"  \033[1mRemoved ({len(removed_skills)}):\033[0m")
    for s in removed_skills:
        print(f"    \033[2m✗ {s}\033[0m")
    print()

# Show needed API keys
all_services = sorted(set(
    svc for name in selected
    for svc in optional.get(name, {}).get('requires_services', [])
    if svc
))
if all_services:
    print("  \033[1;33m\033[1mAPI keys to add (optional — skills work without them):\033[0m")
    for svc in all_services:
        print(f"    \033[1;33m→\033[0m {svc}  \033[2m(add to .env)\033[0m")
    print()

print("  \033[1mNext steps:\033[0m")
print("    1. Add API keys to .env (if any skills need them)")
print("    2. Run \033[1mclaude\033[0m and say \033[1m'start here'\033[0m")
print()
print("  \033[2mRe-run this installer anytime to change your skill selection.\033[0m")
print()
PYEOF
