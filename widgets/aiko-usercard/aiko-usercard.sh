#!/usr/bin/env bash
# aiko-usercard.sh - Launcher/Toggler for the Aiko User Card widget

# Close if already running
if pgrep -f "aiko-usercard.py" > /dev/null; then
    pkill -f "aiko-usercard.py"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
python3 "$SCRIPT_DIR/aiko-usercard.py" &
