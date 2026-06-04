#!/usr/bin/env bash
# aiko-clock.sh - Launcher/Toggler for the Aiko Clock widget

# Close if already running
if pgrep -f "aiko-clock.py" > /dev/null; then
    pkill -f "aiko-clock.py"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
python3 "$SCRIPT_DIR/aiko-clock.py" &
