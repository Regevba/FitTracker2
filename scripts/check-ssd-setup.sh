#!/usr/bin/env bash
# check-ssd-setup.sh
# Audit script — verifies that FitTracker2 development is fully on the SSD.
# Run from anywhere on the Mac. Reports what's set up and what's missing.
#
# Usage:
#   bash scripts/check-ssd-setup.sh
#
# Or from anywhere:
#   curl -fsSL https://raw.githubusercontent.com/Regevba/FitTracker2/claude/review-code-changes-E7RH7/scripts/check-ssd-setup.sh | bash

set -u

SSD_PATH="${SSD_PATH:-/Volumes/DevSSD}"
PROJECT_PATH="${PROJECT_PATH:-$SSD_PATH/FitTracker2}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() { echo -e "${GREEN}✓${NC} $1"; PASS_COUNT=$((PASS_COUNT+1)); }
warn() { echo -e "${YELLOW}⚠${NC} $1"; WARN_COUNT=$((WARN_COUNT+1)); }
fail() { echo -e "${RED}✗${NC} $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }
info() { echo -e "${BLUE}ℹ${NC} $1"; }
section() { echo; echo -e "${BLUE}━━━ $1 ━━━${NC}"; }

echo "FitTracker2 SSD Setup Audit"
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Host: $(hostname)"

# ─────────────────────────────────────────────────────
section "1. SSD Mount Check"
# ─────────────────────────────────────────────────────

if [ -d "$SSD_PATH" ]; then
    pass "SSD mounted at $SSD_PATH"
    SSD_AVAIL=$(df -h "$SSD_PATH" 2>/dev/null | tail -1 | awk '{print $4}')
    SSD_USED=$(df -h "$SSD_PATH" 2>/dev/null | tail -1 | awk '{print $3}')
    info "  Used: $SSD_USED  Available: $SSD_AVAIL"
else
    fail "SSD NOT mounted at $SSD_PATH"
    info "  Plug in the external SSD or set SSD_PATH env var"
    echo
    echo "Cannot continue without SSD. Exiting."
    exit 1
fi

# ─────────────────────────────────────────────────────
section "2. Project Location"
# ─────────────────────────────────────────────────────

if [ -d "$PROJECT_PATH" ]; then
    pass "FitTracker2 repo exists at $PROJECT_PATH"
else
    fail "FitTracker2 repo NOT found at $PROJECT_PATH"
    info "  Run: cd $SSD_PATH && git clone https://github.com/Regevba/FitTracker2.git"
    exit 1
fi

# Check if project is actually on the SSD device
PROJECT_DEVICE=$(df "$PROJECT_PATH" 2>/dev/null | tail -1 | awk '{print $1}')
SSD_DEVICE=$(df "$SSD_PATH" 2>/dev/null | tail -1 | awk '{print $1}')
if [ "$PROJECT_DEVICE" = "$SSD_DEVICE" ]; then
    pass "Project is on the SSD device ($PROJECT_DEVICE)"
else
    fail "Project is NOT on the SSD device"
    info "  Project device: $PROJECT_DEVICE"
    info "  SSD device:     $SSD_DEVICE"
fi

cd "$PROJECT_PATH" || exit 1

# ─────────────────────────────────────────────────────
section "3. Git State"
# ─────────────────────────────────────────────────────

if [ -d ".git" ]; then
    pass "Git repo present"
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    info "  Current branch: $BRANCH"
    HEAD_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    info "  HEAD: $HEAD_SHA"

    if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
        pass "Working tree clean"
    else
        warn "Uncommitted changes present"
    fi

    # Check if branch is in sync with remote
    git fetch --quiet 2>/dev/null || true
    LOCAL=$(git rev-parse @ 2>/dev/null)
    REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "no upstream")
    if [ "$LOCAL" = "$REMOTE" ]; then
        pass "Local in sync with remote"
    elif [ "$REMOTE" = "no upstream" ]; then
        warn "No upstream tracking branch"
    else
        warn "Local diverged from remote (run: git pull)"
    fi
else
    fail "Not a git repo"
fi

# ─────────────────────────────────────────────────────
section "4. Project-Local Build Directory (.build/)"
# ─────────────────────────────────────────────────────

if [ -d ".build" ]; then
    pass ".build/ directory exists"
    BUILD_SIZE=$(du -sh .build 2>/dev/null | awk '{print $1}')
    info "  Size: $BUILD_SIZE"

    for subdir in ai-venv spm-cache xcode-home clang-cache DerivedData TestDerivedData npm-cache; do
        if [ -d ".build/$subdir" ]; then
            pass "  .build/$subdir/ exists"
        else
            warn "  .build/$subdir/ missing (will be created on first build)"
        fi
    done
else
    warn ".build/ directory does not exist"
    info "  Run 'make verify-local' to create it"
fi

# ─────────────────────────────────────────────────────
section "5. .npmrc Check"
# ─────────────────────────────────────────────────────

if [ -f ".npmrc" ]; then
    if grep -q "cache=.build/npm-cache" .npmrc; then
        pass ".npmrc points npm cache to .build/npm-cache"
    else
        warn ".npmrc exists but doesn't redirect cache"
        info "  Contents: $(cat .npmrc)"
    fi
else
    fail ".npmrc missing"
    info "  Create with: echo 'cache=.build/npm-cache' > .npmrc"
fi

# ─────────────────────────────────────────────────────
section "6. .gitignore Check"
# ─────────────────────────────────────────────────────

if grep -q "^.build/" .gitignore 2>/dev/null; then
    pass ".gitignore excludes .build/"
else
    fail ".gitignore does NOT exclude .build/"
    info "  Add: echo '.build/' >> .gitignore"
fi

# ─────────────────────────────────────────────────────
section "7. Makefile SSD Compliance"
# ─────────────────────────────────────────────────────

if grep -q "BUILD_DIR.*PROJECT_ROOT.*\.build" Makefile 2>/dev/null; then
    pass "Makefile uses BUILD_DIR=PROJECT_ROOT/.build"
else
    fail "Makefile not configured for SSD .build/"
fi

if grep -q "/tmp/FitTracker" Makefile 2>/dev/null; then
    fail "Makefile still has /tmp/FitTracker references"
    grep -n "/tmp/FitTracker" Makefile
else
    pass "Makefile has zero /tmp/FitTracker references"
fi

# ─────────────────────────────────────────────────────
section "8. macOS-Specific Overrides (only run on macOS)"
# ─────────────────────────────────────────────────────

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Xcode DerivedData
    XCODE_DD=$(defaults read com.apple.dt.Xcode IDECustomDerivedDataLocation 2>/dev/null || echo "")
    XCODE_DD_USE=$(defaults read com.apple.dt.Xcode IDEUseCustomDerivedDataLocation 2>/dev/null || echo "")
    if [[ "$XCODE_DD" == "$SSD_PATH"* ]] && [ "$XCODE_DD_USE" = "1" ]; then
        pass "Xcode DerivedData → $XCODE_DD"
    elif [ -n "$XCODE_DD" ]; then
        warn "Xcode DerivedData set to $XCODE_DD (not on SSD)"
    else
        warn "Xcode DerivedData using system default (~/Library/Developer/Xcode/DerivedData)"
        info "  Run: defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation -string \"$SSD_PATH/.xcode-shared/DerivedData\""
        info "       defaults write com.apple.dt.Xcode IDEUseCustomDerivedDataLocation -bool YES"
    fi

    # Xcode Archives
    XCODE_AR=$(defaults read com.apple.dt.Xcode IDECustomDistributionArchivesLocation 2>/dev/null || echo "")
    if [[ "$XCODE_AR" == "$SSD_PATH"* ]]; then
        pass "Xcode Archives → $XCODE_AR"
    else
        warn "Xcode Archives using default (~/Library/Developer/Xcode/Archives)"
    fi

    # CoreSimulator symlink
    CORESIM_PATH="$HOME/Library/Developer/CoreSimulator"
    if [ -L "$CORESIM_PATH" ]; then
        TARGET=$(readlink "$CORESIM_PATH")
        if [[ "$TARGET" == "$SSD_PATH"* ]]; then
            pass "CoreSimulator → $TARGET (symlinked to SSD)"
        else
            warn "CoreSimulator symlinked to $TARGET (not on SSD)"
        fi
    elif [ -d "$CORESIM_PATH" ]; then
        warn "CoreSimulator is a real directory on internal disk"
        CORESIM_SIZE=$(du -sh "$CORESIM_PATH" 2>/dev/null | awk '{print $1}')
        info "  Size: $CORESIM_SIZE — eligible for SSD migration"
    else
        info "CoreSimulator not yet created"
    fi

    # npm global cache
    NPM_CACHE=$(npm config get cache 2>/dev/null || echo "")
    if [[ "$NPM_CACHE" == "$SSD_PATH"* ]]; then
        pass "npm global cache → $NPM_CACHE"
    else
        warn "npm global cache: $NPM_CACHE (not on SSD)"
        info "  Run: npm config set cache $SSD_PATH/.npm-cache"
    fi

    # Homebrew cache
    if [ -n "${HOMEBREW_CACHE:-}" ]; then
        if [[ "$HOMEBREW_CACHE" == "$SSD_PATH"* ]]; then
            pass "HOMEBREW_CACHE → $HOMEBREW_CACHE"
        else
            warn "HOMEBREW_CACHE set to $HOMEBREW_CACHE (not on SSD)"
        fi
    else
        warn "HOMEBREW_CACHE not set"
        info "  Add to ~/.zshrc: export HOMEBREW_CACHE=\"$SSD_PATH/.homebrew-cache\""
    fi

    # pip cache
    if [ -f "$HOME/.pip/pip.conf" ]; then
        PIP_CACHE=$(grep "cache-dir" "$HOME/.pip/pip.conf" 2>/dev/null | sed 's/.*=//' | xargs)
        if [[ "$PIP_CACHE" == "$SSD_PATH"* ]]; then
            pass "pip cache-dir → $PIP_CACHE"
        else
            warn "pip cache-dir: $PIP_CACHE (not on SSD)"
        fi
    else
        warn "pip config not set"
        info "  Run: mkdir -p ~/.pip && echo -e '[global]\\ncache-dir = $SSD_PATH/.pip-cache' > ~/.pip/pip.conf"
    fi
else
    info "Not running on macOS — skipping Xcode/Homebrew checks"
fi

# ─────────────────────────────────────────────────────
section "9. Internal Disk Check (look for stragglers)"
# ─────────────────────────────────────────────────────

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Check if Xcode default DerivedData has FitTracker artifacts
    DEFAULT_DD="$HOME/Library/Developer/Xcode/DerivedData"
    if [ -d "$DEFAULT_DD" ]; then
        FT_DIRS=$(find "$DEFAULT_DD" -maxdepth 1 -name "FitTracker*" 2>/dev/null | wc -l | xargs)
        if [ "$FT_DIRS" -gt 0 ]; then
            warn "Found $FT_DIRS FitTracker DerivedData entries in default location"
            info "  Run: rm -rf $DEFAULT_DD/FitTracker*"
        else
            pass "No FitTracker entries in default Xcode DerivedData"
        fi
    fi

    # Check /tmp for FitTracker artifacts
    TMP_FT=$(ls /tmp/FitTracker* 2>/dev/null | wc -l | xargs)
    if [ "$TMP_FT" -gt 0 ]; then
        warn "Found $TMP_FT FitTracker artifacts in /tmp"
        info "  Clean: rm -rf /tmp/FitTracker*"
    else
        pass "No FitTracker artifacts in /tmp"
    fi
fi

# ─────────────────────────────────────────────────────
section "10. Documentation Check"
# ─────────────────────────────────────────────────────

REQUIRED_DOCS=(
    "docs/project/ssd-setup-guide-2026-04-06.md"
    "docs/project/session-summary-2026-04-06.md"
    "docs/design-system/ux-foundations.md"
    "docs/design-system/closure-summary-2026-04-06.md"
    ".claude/skills/ux/SKILL.md"
)
for doc in "${REQUIRED_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        LINES=$(wc -l < "$doc" | xargs)
        pass "  $doc ($LINES lines)"
    else
        fail "  $doc MISSING"
    fi
done

# ─────────────────────────────────────────────────────
section "Summary"
# ─────────────────────────────────────────────────────

echo
echo -e "  ${GREEN}Pass: $PASS_COUNT${NC}   ${YELLOW}Warn: $WARN_COUNT${NC}   ${RED}Fail: $FAIL_COUNT${NC}"
echo

if [ "$FAIL_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ Setup is complete. Everything is on the SSD.${NC}"
elif [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠ Mostly set up. See warnings above for optional improvements.${NC}"
else
    echo -e "${RED}✗ Setup incomplete. See failures above.${NC}"
    echo -e "${BLUE}  Read: docs/project/ssd-setup-guide-2026-04-06.md${NC}"
fi

echo
echo "For full setup instructions, see:"
echo "  docs/project/ssd-setup-guide-2026-04-06.md"
echo
