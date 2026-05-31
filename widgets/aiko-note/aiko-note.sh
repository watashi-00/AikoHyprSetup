#!/usr/bin/env bash
# aiko-note.sh - Launcher for the GTK Aiko-Note widget

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Check if python3-gobject is installed
if ! python3 -c "import gi; gi.require_version('Gtk', '3.0')" >/dev/null 2>&1; then
    notify-send "AikoHyprSetup" "Error: python3-gi (PyGObject) is required for the Notes widget."
    
    # Fallback to the old terminal method if GTK is missing
    NOTES_FILE="$HOME/.cache/aiko-note.txt"
    kitty --class aiko-note -e nvim "$NOTES_FILE"
    exit 1
fi

# Run the python GTK widget
python3 "$SCRIPT_DIR/aiko-note.py"
