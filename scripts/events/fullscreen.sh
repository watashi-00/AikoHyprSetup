#!/usr/bin/env bash

# event-handler: fullscreen
# Automatically pauses/resumes resource-intensive tasks (like mpvpaper)
# when a window enters or leaves fullscreen mode to save CPU/GPU for games/apps.

EVENT_DATA="${1:-}"
STATE="${EVENT_DATA##*>>}"

if [ "$STATE" = "1" ]; then
    # Fullscreen entered: Suspend intensive processes
    if pgrep -f "mpvpaper" >/dev/null; then
        pkill -STOP -f "mpvpaper"
    fi
    if pgrep -x "cava" >/dev/null; then
        pkill -STOP -x "cava"
    fi
elif [ "$STATE" = "0" ]; then
    # Fullscreen exited: Resume suspended processes
    if pgrep -f "mpvpaper" >/dev/null; then
        pkill -CONT -f "mpvpaper"
    fi
    if pgrep -x "cava" >/dev/null; then
        pkill -CONT -x "cava"
    fi
fi
