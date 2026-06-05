#!/usr/bin/env bash

# event-listener.sh - Global Hyprland event listener to trigger scripts
# Usage: ./event-listener.sh

# Resolve real path to locate utility library
SCRIPT_DIR_LIS="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_LIS="$SCRIPT_DIR_LIS/lib/utils.sh"

if [ -f "$LIB_UTILS_LIS" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_LIS"
else
    AIKO_ROOT="$HOME/.config/waybar"
    AIKO_SCRIPTS="$AIKO_ROOT/scripts"
fi

AIKO_LOG_COMPONENT="events"
EVENTS_DIR="$AIKO_SCRIPTS/events"

# Run startup hook in the background
if [ -f "$EVENTS_DIR/startup.sh" ]; then
    log "Running startup hook..."
    bash "$EVENTS_DIR/startup.sh" &
fi

handle() {
    local line="$1"
    # Event format: EVENT>>DATA
    if [[ "$line" =~ \>\> ]]; then
        local event_name="${line%%>>*}"
        local event_script="$EVENTS_DIR/${event_name}.sh"
        
        if [ -f "$event_script" ]; then
            # Execute handler asynchronously to prevent blocking the event loop
            bash "$event_script" "$line" &
        fi
    fi
}

# Listen to hyprland socket
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    log "Aiko Global Event Listener active..."
    socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
        handle "$line"
    done
else
    error "HYPRLAND_INSTANCE_SIGNATURE not found. Event listener cannot start."
    exit 1
fi
