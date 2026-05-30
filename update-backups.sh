#!/bin/bash

# Define paths
REPO_DIR="/home/watashi/.config/waybar"
HYPR_SRC="/home/watashi/.config/hypr/hyprland.conf"
WOFI_SRC="/home/watashi/.config/wofi"

echo "Updating local backups of external configs..."

# Backup Hyprland
if [ -f "$HYPR_SRC" ]; then
    mkdir -p "$REPO_DIR/hypr-config"
    cp "$HYPR_SRC" "$REPO_DIR/hypr-config/"
    echo "✓ Hyprland config updated."
else
    echo "✗ Hyprland config not found at $HYPR_SRC"
fi

# Backup Wofi
if [ -d "$WOFI_SRC" ]; then
    mkdir -p "$REPO_DIR/wofi-config"
    cp -r "$WOFI_SRC/"* "$REPO_DIR/wofi-config/"
    echo "✓ Wofi configs updated."
else
    echo "✗ Wofi directory not found at $WOFI_SRC"
fi

echo "Done! You can now commit the changes."
