#!/usr/bin/env bash

# diagnostics.sh - System health check for AikoHyprSetup
# Usage: ./diagnostics.sh

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS="$SCRIPT_DIR/lib/utils.sh"

if [ -f "$LIB_UTILS" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS"
else
    echo "Error: utility library not found at $LIB_UTILS"
    exit 1
fi

AIKO_LOG_COMPONENT="diag"

divider() {
    printf "${CYAN}--------------------------------------------------${NC}\n"
}

divider
printf "${BOLD}${MAGENTA}   AikoHyprSetup v$AIKO_VERSION Environment Diagnostics   ${NC}\n"
divider

# --- 1. Dependencies ---
log "Checking core dependencies..."
deps=(
    hyprland waybar wofi mako hyprpaper kitty jq playerctl cava
    pipewire wireplumber pavucontrol wl-copy cliphist
    grim slurp curl hyprpicker swappy socat magick python3
)
missing=()
for d in "${deps[@]}"; do
    if have "$d"; then
        success "$d found: $(command -v "$d")"
    else
        error "$d NOT found"
        missing+=("$d")
    fi
done

# Check specialized dependencies
log "Checking specialized utilities..."
spec_deps=(nm-applet bluetoothctl zenity gthumb)
for d in "${spec_deps[@]}"; do
    if have "$d"; then
        success "$d found"
    else
        warn "$d NOT found (optional but recommended)"
    fi
done

# --- 2. Python Environment ---
log "Checking Python environment..."
py_modules=(gi psutil json urllib.request threading)
for m in "${py_modules[@]}"; do
    if python3 -c "import $m" >/dev/null 2>&1; then
        success "Python module '$m' OK"
    else
        error "Python module '$m' MISSING"
    fi
done

# --- 3. Active Listeners ---
log "Checking active listeners..."
if pgrep -f "event-listener.sh" >/dev/null; then
    success "event-listener.sh is running"
else
    error "event-listener.sh is NOT running"
fi

if pgrep -f "wl-paste --type text" >/dev/null; then
    success "Clipboard watcher daemon is running"
else
    error "Clipboard watcher daemon is NOT running"
fi

# --- 4. Hyprland Environment ---
log "Checking Hyprland environment..."
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    success "HYPRLAND_INSTANCE_SIGNATURE is set"
else
    error "HYPRLAND_INSTANCE_SIGNATURE is empty (Not in Hyprland?)"
fi

# --- 5. Filesystem & Links ---
log "Checking configuration links..."
waybar_dir="$HOME/.config/waybar"
if [ -L "$waybar_dir/style.css" ]; then
    success "Global theme link: $(readlink "$waybar_dir/style.css")"
else
    error "Global theme link (style.css) MISSING"
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
        error "Widget folder ($w) MISSING"
    fi
done

# --- 6. CLI Integration ---
log "Checking CLI integration..."
if have aiko; then
    success "'aiko' command is global"
else
    warn "'aiko' command is NOT global"
fi

divider
log "Diagnostics complete."
divider
