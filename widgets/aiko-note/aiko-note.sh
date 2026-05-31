#!/usr/bin/env bash
# aiko-note.sh - Launcher for the GTK Aiko-Note widget

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Priority 1: Run the compiled binary (from build.sh)
if [ -f "$SCRIPT_DIR/aiko-note-bin" ]; then
    "$SCRIPT_DIR/aiko-note-bin"
    exit 0
fi

# Priority 2: Fallback to Python GTK widget
if python3 -c "import gi; gi.require_version('Gtk', '3.0')" >/dev/null 2>&1; then
    python3 "$SCRIPT_DIR/aiko-note.py"
    exit 0
fi

# Priority 3: Final fallback to Terminal/Nvim if GTK is missing
notify-send "AikoHyprSetup" "PyGObject not found. Falling back to terminal editor."
NOTES_FILE="$HOME/.cache/aiko-note.txt"
kitty --class aiko-note -e nvim "$NOTES_FILE"

