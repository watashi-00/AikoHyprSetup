#!/usr/bin/env bash

# AikoHyprSetup V2 - Unified Widget Launcher
# Handles toggling, binary fallbacks, and environment checks for all widgets.

# Usage: ./widget_launcher.sh <widget-name>
# Example: ./widget_launcher.sh aiko-clock

WIDGET_NAME="${1:-}"
[ -z "$WIDGET_NAME" ] && exit 1

# Resolve real path to locate utility library
SCRIPT_DIR_WL="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_WL="$SCRIPT_DIR_WL/utils.sh"

if [ -f "$LIB_UTILS_WL" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_WL"
else
    # If called from a sub-folder during dev
    LIB_UTILS_WL="$(cd "$SCRIPT_DIR_WL/.." && pwd)/lib/utils.sh"
    [ -f "$LIB_UTILS_WL" ] && source "$LIB_UTILS_WL"
fi

# Ensure paths are loaded
[ -z "${AIKO_WIDGETS:-}" ] && get_aiko_paths

WIDGET_DIR="$AIKO_WIDGETS/$WIDGET_NAME"
[ ! -d "$WIDGET_DIR" ] && error "Widget '$WIDGET_NAME' not found in $AIKO_WIDGETS" && exit 1

PY_SCRIPT="$WIDGET_DIR/$WIDGET_NAME.py"
BIN_FILE="$WIDGET_DIR/$WIDGET_NAME-bin"

# --- 1. Toggle Logic ---
# Check if already running by checking for the python script name
if pgrep -f "$WIDGET_NAME.py" > /dev/null || pgrep -x "$WIDGET_NAME-bin" > /dev/null; then
    pkill -f "$WIDGET_NAME.py" || true
    pkill -x "$WIDGET_NAME-bin" || true
    exit 0
fi

# --- 2. Execution Logic ---

# Priority 1: Compiled Binary
if [ -f "$BIN_FILE" ]; then
    "$BIN_FILE" &
    exit 0
fi

# Priority 2: Python Script (with check)
if [ -f "$PY_SCRIPT" ]; then
    if python3 -c "import gi; gi.require_version('Gtk', '3.0')" >/dev/null 2>&1; then
        python3 "$PY_SCRIPT" &
        exit 0
    fi
fi

# --- 3. Fallbacks ---

# Special Case: aiko-note terminal fallback
if [ "$WIDGET_NAME" = "aiko-note" ]; then
    if have notify-send; then
        notify-send "AikoHyprSetup" "PyGObject not found. Falling back to terminal editor."
    fi
    NOTES_FILE="$HOME/.cache/aiko-note.txt"
    if have kitty && have nvim; then
        exec kitty --class aiko-note -e nvim "$NOTES_FILE"
    fi
fi

error "Could not launch $WIDGET_NAME. Missing dependencies or script not found."
exit 1
