#!/bin/bash

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HYPR_SRC="$HOME/.config/hypr/hyprland.conf"
WOFI_SRC="$HOME/.config/wofi"
MAKO_SRC="$HOME/.config/mako"

echo "Updating local backups of external configs..."

# Backup Hyprland
if [ -f "$HYPR_SRC" ]; then
    mkdir -p "$REPO_DIR/configs/hypr"
    cp "$HYPR_SRC" "$REPO_DIR/configs/hypr/"
    echo "✓ Hyprland config updated."
else
    echo "✗ Hyprland config not found at $HYPR_SRC"
fi

# Backup Wofi
if [ -d "$WOFI_SRC" ]; then
    mkdir -p "$REPO_DIR/configs/wofi"
    cp -r "$WOFI_SRC/"* "$REPO_DIR/configs/wofi/"
    echo "✓ Wofi configs updated."
else
    echo "✗ Wofi directory not found at $WOFI_SRC"
fi

# Backup Mako
if [ -d "$MAKO_SRC" ]; then
    mkdir -p "$REPO_DIR/configs/mako"
    cp -r "$MAKO_SRC/"* "$REPO_DIR/configs/mako/"
    echo "✓ Mako configs updated."
else
    echo "✗ Mako directory not found at $MAKO_SRC"
fi

echo "Done! You can now commit the changes."
