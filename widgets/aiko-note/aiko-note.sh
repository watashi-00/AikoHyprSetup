#!/usr/bin/env bash
# aiko-note.sh - A simple floating note widget

NOTES_FILE="$HOME/.cache/aiko-note.txt"
mkdir -p "$(dirname "$NOTES_FILE")"
touch "$NOTES_FILE"

# For now, let's use a floating terminal with a text editor
# In a real implementation, this could be a GTK app or a specialized wofi setup
# We'll use kitty with a specific class for Hyprland rules

EDITOR_BIN="nvim"
if ! command -v nvim >/dev/null 2>&1; then
    if command -v nano >/dev/null 2>&1; then
        EDITOR_BIN="nano"
    elif command -v vi >/dev/null 2>&1; then
        EDITOR_BIN="vi"
    else
        EDITOR_BIN="vim"
    fi
fi

kitty --class aiko-note -e "$EDITOR_BIN" "$NOTES_FILE"
