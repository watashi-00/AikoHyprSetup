#!/usr/bin/env bash

# Resolve real path to locate utility library
SCRIPT_DIR_BAK="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_BAK="$SCRIPT_DIR_BAK/lib/utils.sh"

if [ -f "$LIB_UTILS_BAK" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_BAK"
else
    AIKO_ROOT="$HOME/.config/waybar"
fi

AIKO_LOG_COMPONENT="backup"

# Define paths
HYPR_SRC="$HOME/.config/hypr/hyprland.conf"
WOFI_SRC="$HOME/.config/wofi"
MAKO_SRC="$HOME/.config/mako"

log "Updating local backups of external configs..."

# Backup Hyprland
if [ -f "$HYPR_SRC" ]; then
    mkdir -p "$AIKO_ROOT/configs/hypr"
    cp "$HYPR_SRC" "$AIKO_ROOT/configs/hypr/"
    success "Hyprland config updated."
else
    error "Hyprland config not found at $HYPR_SRC"
fi

# Backup Wofi
if [ -d "$WOFI_SRC" ]; then
    mkdir -p "$AIKO_ROOT/configs/wofi"
    cp -r "$WOFI_SRC/"* "$AIKO_ROOT/configs/wofi/"
    success "Wofi configs updated."
else
    error "Wofi directory not found at $WOFI_SRC"
fi

# Backup Mako
if [ -d "$MAKO_SRC" ]; then
    mkdir -p "$AIKO_ROOT/configs/mako"
    cp -r "$MAKO_SRC/"* "$AIKO_ROOT/configs/mako/"
    success "Mako configs updated."
else
    error "Mako directory not found at $MAKO_SRC"
fi

log "Done! You can now commit the changes."
