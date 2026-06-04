#!/usr/bin/env bash
# experimental: try to force gtk to see the new icon without a full reload
# by briefly changing the icon theme to something else and back.

WAYBAR_PID=$(pgrep -f "waybar --config .*")

if [ -z "$WAYBAR_PID" ]; then
    exit 0
fi

# 1. Notify the system of the new icon
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/Aiko" >/dev/null 2>&1
fi

# 2. Re-apply the current theme via SIGUSR2 (Waybar style reload)
kill -SIGUSR2 "$WAYBAR_PID"
