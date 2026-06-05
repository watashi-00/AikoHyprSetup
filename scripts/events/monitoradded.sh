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

log "Monitor added/activated event: $1"
if [ -f "$RESTART_SCRIPT" ]; then
    log "Triggering Waybar restart..."
    # Run with target AIKO_ROOT config directory to ensure correct theme/config load
    nohup env AIKO_ROOT="$HOME/.config/waybar" bash "$RESTART_SCRIPT" >/dev/null 2>&1 &
else
    error "Restart script not found at $RESTART_SCRIPT"
fi
