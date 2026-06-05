#!/usr/bin/env bash

# AikoHyprSetup V2 - Integrated Self-Test Suite
# This script performs a deep integrity check of the codebase to find silent errors.

# Resolve real path to locate utility library
SCRIPT_DIR_TEST="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_TEST="$SCRIPT_DIR_TEST/lib/utils.sh"

if [ -f "$LIB_UTILS_TEST" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_TEST"
else
    echo "Error: utility library not found at $LIB_UTILS_TEST"
    exit 1
fi

AIKO_LOG_COMPONENT="test"
aiko_init_term

divider() {
    printf "${CYAN}--------------------------------------------------${NC}\n"
}

divider
log "Starting AikoHyprSetup v$AIKO_VERSION Self-Test Suite..."
divider

ERRORS=0

# --- 1. Path & Variable Integrity ---
log "Testing path discovery..."
if [ -n "$AIKO_ROOT" ] && [ -d "$AIKO_ROOT" ]; then
    success "AIKO_ROOT validated: $AIKO_ROOT"
else
    error "AIKO_ROOT is invalid or not a directory."
    ((ERRORS++))
fi

paths=("AIKO_SCRIPTS" "AIKO_WIDGETS" "AIKO_THEMES" "AIKO_ASSETS" "AIKO_CONFIGS")
for p in "${paths[@]}"; do
    val="${!p}"
    if [ -d "$val" ]; then
        success "$p validated: $val"
    else
        error "$p directory missing: $val"
        ((ERRORS++))
    fi
done

# --- 2. Script Syntax Integrity (Bash) ---
log "Checking Bash syntax for all scripts..."
while read -r script; do
    if bash -n "$script"; then
        success "Syntax OK: $(basename "$script")"
    else
        error "SYNTAX ERROR in $script"
        ((ERRORS++))
    fi
done < <(find "$AIKO_ROOT" -name "*.sh" -not -path "*/.git/*" -not -path "*/.bak-*/*" -not -name "*.bak-*")

# --- 3. Python Integrity ---
log "Checking Python syntax for all widgets..."
while read -r py_script; do
    if python3 -m py_compile "$py_script" >/dev/null 2>&1; then
        success "Python OK: $(basename "$py_script")"
    else
        error "PYTHON SYNTAX ERROR in $py_script"
        ((ERRORS++))
    fi
    # Cleanup compilation artifacts
    rm -rf "$(dirname "$py_script")/__pycache__"
done < <(find "$AIKO_WIDGETS" -name "*.py" -not -path "*/.bak-*/*" -not -name "*.bak-*")

# --- 4. Widget Directory Structure ---
log "Verifying widget integrity..."
widgets=("aiko-clock" "aiko-weather" "aiko-note" "aiko-player" "aiko-list" "aiko-sys" "aiko-usercard" "aiko-monitors" "aiko-audio" "aiko-calendar" "aiko-timer" "aiko-recorder" "aiko-search")
for w in "${widgets[@]}"; do
    w_dir="$AIKO_WIDGETS/$w"
    if [ -d "$w_dir" ]; then
        if [ -f "$w_dir/$w.py" ]; then
            success "Widget '$w' is complete."
        else
            error "Widget '$w' is missing its entry point ($w.py)."
            ((ERRORS++))
        fi
    else
        error "Widget folder '$w' is missing."
        ((ERRORS++))
    fi
done

# --- 5. Configs & Desktop Integrity ---
log "Verifying desktop launchers..."
while read -r desktop; do
    if grep -q "Exec=aiko --" "$desktop"; then
        success "Launcher OK: $(basename "$desktop")"
    else
        warn "Launcher $(basename "$desktop") might be using old paths."
    fi
done < <(find "$AIKO_CONFIGS/applications" -name "*.desktop")

divider
if [ "$ERRORS" -eq 0 ]; then
    success "ALL TESTS PASSED! Your AikoHyprSetup V2 is solid."
else
    error "TESTS FAILED: Found $ERRORS errors. Please review the logs above."
fi
divider

exit "$ERRORS"
