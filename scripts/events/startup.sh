#!/usr/bin/env bash
# scripts/events/startup.sh - Startup hook for global event-listener

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
AIKO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AIKO_SCRIPTS="$AIKO_ROOT/scripts"

if [ -f "$AIKO_SCRIPTS/lib/utils.sh" ]; then
    # shellcheck disable=SC1091
    source "$AIKO_SCRIPTS/lib/utils.sh"
fi

AIKO_LOG_COMPONENT="event-startup"

log "Starting background clipboard watcher..."
if have wl-paste && have cliphist; then
    # Kill any existing cliphist/wl-paste watcher processes first
    pkill -f "wl-paste --type text --watch" || true
    pkill -f "wl-paste --type image --watch" || true
    
    wl-paste --type text --watch cliphist store &
    wl-paste --type image --watch cliphist store &
    success "Clipboard watcher started successfully."
else
    warn "wl-paste or cliphist not found. Clipboard history disabled."
fi
