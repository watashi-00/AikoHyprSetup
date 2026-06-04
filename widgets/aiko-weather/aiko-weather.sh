#!/usr/bin/env bash
# aiko-weather.sh - Launcher/Toggler for the Aiko Weather widget

# Close if already running
if pgrep -f "aiko-weather.py" > /dev/null; then
    pkill -f "aiko-weather.py"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
python3 "$SCRIPT_DIR/aiko-weather.py" &
