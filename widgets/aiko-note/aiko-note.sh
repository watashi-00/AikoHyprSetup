#!/usr/bin/env bash
# aiko-note.sh - A simple floating note widget

NOTES_FILE="$HOME/.cache/aiko-note.txt"
mkdir -p "$(dirname "$NOTES_FILE")"
touch "$NOTES_FILE"

# For now, let's use a floating terminal with a text editor
# In a real implementation, this could be a GTK app or a specialized wofi setup
# We'll use kitty with a specific class for Hyprland rules

kitty --class aiko-note -e nvim "$NOTES_FILE"
