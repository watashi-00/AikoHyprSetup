#!/usr/bin/env bash

# diagnostics.sh - System health check for AikoHyprSetup
# Usage: ./diagnostics.sh

# --- Colors ---
NC=$'\e[0m'
BOLD=$'\e[1m'
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[0;34m'
CYAN=$'\e[0;36m'

# Icons
CHECK="✔"
ERROR="✘"
WARN="⚠"
INFO="ℹ"

log() { printf "${BLUE}[diag]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[$CHECK]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[$WARN]${NC} %s\n" "$*"; }
err() { printf "${RED}[$ERROR]${NC} %s\n" "$*"; }

divider() {
    printf "${CYAN}--------------------------------------------------${NC}\n"
}

divider
printf "${BOLD}${MAGENTA}   AikoHyprSetup Environment Diagnostics   ${NC}\n"
divider

# --- 1. Dependencies ---
log "Checking core dependencies..."
deps=(hyprland waybar socat magick jq playerctl python3)
missing=()
for d in "${deps[@]}"; do
    if command -v "$d" >/dev/null 2>&1; then
        success "$d found: $(command -v "$d")"
    else
        err "$d NOT found"
        missing+=("$d")
    fi
done

# --- 2. Python Environment ---
log "Checking Python environment..."
py_modules=(gi psutil json urllib.request threading)
for m in "${py_modules[@]}"; do
    if python3 -c "import $m" >/dev/null 2>&1; then
        success "Python module '$m' OK"
    else
        err "Python module '$m' MISSING"
    fi
done

# --- 3. Active Listeners ---
log "Checking active listeners..."
listeners=("icon-listener.sh" "clipboard-listener.sh")
for l in "${listeners[@]}"; do
    if pgrep -f "$l" >/dev/null; then
        success "$l is running"
    else
        err "$l is NOT running"
    fi
done

# --- 4. Hyprland Environment ---
log "Checking Hyprland environment..."
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    success "HYPRLAND_INSTANCE_SIGNATURE is set"
else
    err "HYPRLAND_INSTANCE_SIGNATURE is empty (Not in Hyprland?)"
fi

# --- 5. Filesystem & Links ---
log "Checking configuration links..."
waybar_dir="$HOME/.config/waybar"
if [ -L "$waybar_dir/style.css" ]; then
    success "Global theme link: $(readlink "$waybar_dir/style.css")"
else
    err "Global theme link (style.css) MISSING"
fi

widgets=("aiko-note" "aiko-player" "aiko-clock" "aiko-usercard" "aiko-weather" "aiko-list" "aiko-sys")
for w in "${widgets[@]}"; do
    w_path="$waybar_dir/widgets/$w"
    if [ -d "$w_path" ]; then
        if [ -L "$w_path/theme.css" ]; then
            success "Widget theme link ($w): $(readlink "$w_path/theme.css")"
        else
            warn "Widget theme link ($w) MISSING"
        fi
    else
        err "Widget folder ($w) MISSING"
    fi
done

# --- 6. CLI Integration ---
log "Checking CLI integration..."
if command -v aiko >/dev/null 2>&1; then
    success "'aiko' command is global"
else
    warn "'aiko' command is NOT global"
fi

divider
log "Diagnostics complete."
divider
