#!/usr/bin/env bash
set -euo pipefail

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# --- Load Central Utility Library ---
LIB_UTILS="$SCRIPT_DIR/lib/utils.sh"
if [ -f "$LIB_UTILS" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS"
else
    echo "Error: utility library not found at $LIB_UTILS"
    exit 1
fi

AIKO_LOG_COMPONENT="layout"

LAYOUTS_DIR="$AIKO_ROOT/layouts"
[ ! -d "$LAYOUTS_DIR" ] && LAYOUTS_DIR="$AIKO_ROOT/waybar/layouts"

ACTIVE_LINK="$AIKO_ROOT/active_layout"
[ ! -d "$(dirname "$ACTIVE_LINK")" ] && ACTIVE_LINK="$AIKO_ROOT/waybar/active_layout"

# Check layouts directory
if [ ! -d "$LAYOUTS_DIR" ]; then
    error "Layouts directory not found: $LAYOUTS_DIR"
    exit 1
fi

# List available layout profiles
layouts=($(find "$LAYOUTS_DIR" -maxdepth 1 -mindepth 1 -type d | sort))
if [ ${#layouts[@]} -eq 0 ]; then
    error "No layout profiles found in $LAYOUTS_DIR"
    exit 1
fi

selected_layout=""
selected_name=""

# If layout name is passed as argument
if [ "${1:-}" != "" ]; then
    if [ -d "$1" ]; then
        selected_layout="$1"
    elif [ -d "$LAYOUTS_DIR/$1" ]; then
        selected_layout="$LAYOUTS_DIR/$1"
    fi
fi

# Visual selection via wofi
if [ -z "$selected_layout" ]; then
    options=""
    for l in "${layouts[@]}"; do
        name=$(basename "$l")
        options+="$name\n"
    done

    selected_name=$(echo -e "$options" | wofi --dmenu --prompt "Select Waybar Layout" --width 300 --height 350 || true)
    [ -z "$selected_name" ] && exit 0

    for l in "${layouts[@]}"; do
        name=$(basename "$l")
        if [ "$name" = "$selected_name" ]; then
            selected_layout="$l"
            break
        fi
    done
fi

[ -z "$selected_layout" ] && error "Layout profile not found" && exit 1

if [ -z "$selected_name" ]; then
    selected_name=$(basename "$selected_layout")
fi

log "Applying Waybar Layout Profile: $selected_name"

# Create symlink relative to link's directory to avoid absolute path breaks
rm -f "$ACTIVE_LINK"
(cd "$(dirname "$ACTIVE_LINK")" && ln -sf "layouts/$selected_name" "$(basename "$ACTIVE_LINK")")

# Restart Waybar
RESTART_SCRIPT="$SCRIPT_DIR/restart-waybar.sh"
if [ -f "$RESTART_SCRIPT" ]; then
    log "Restarting Waybar with new layout..."
    nohup bash "$RESTART_SCRIPT" >/dev/null 2>&1 &
fi

success "Layout profile '$selected_name' applied!"
