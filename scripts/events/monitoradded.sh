#!/usr/bin/env bash
# scripts/events/monitoradded.sh - Handle monitoradded Hyprland event

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
AIKO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AIKO_SCRIPTS="$AIKO_ROOT/scripts"

if [ -f "$AIKO_SCRIPTS/lib/utils.sh" ]; then
    # shellcheck disable=SC1091
    source "$AIKO_SCRIPTS/lib/utils.sh"
fi

AIKO_LOG_COMPONENT="event-monitor"
RESTART_SCRIPT="$AIKO_SCRIPTS/restart-waybar.sh"
DEBOUNCE_FILE="/tmp/aiko-monitor-restart-trigger"

log "Monitor event received: $1"

# Debounce mechanism: Write our PID to the trigger file
echo "$$" > "$DEBOUNCE_FILE"

# Wait a short moment to let any rapid consecutive monitor events arrive
sleep 1.2

# Check if another instance ran and updated the trigger file
if [ "$(cat "$DEBOUNCE_FILE" 2>/dev/null)" != "$$" ]; then
    log "Consecutive monitor event detected. Cancelling this restart execution in favor of the newer event."
    exit 0
fi

# Clean up trigger file
rm -f "$DEBOUNCE_FILE"

if [ -f "$RESTART_SCRIPT" ]; then
    log "Triggering Waybar restart..."
    # Run with target AIKO_ROOT config directory to ensure correct theme/config load
    nohup env AIKO_ROOT="$HOME/.config/waybar" bash "$RESTART_SCRIPT" >/dev/null 2>&1 &
else
    error "Restart script not found at $RESTART_SCRIPT"
fi
