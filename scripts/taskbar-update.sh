#!/usr/bin/env bash
# Experimental: Try to force GTK to see the new icon without a full reload
# by briefly changing the icon theme to something else and back.

TARGET_CONFIG="config-bottom.jsonc"
WAYBAR_PID=$(pgrep -f "waybar --config .*")

if [ -z "$WAYBAR_PID" ]; then
    exit 1
fi

# 1. Notify the system of the new icon
gtk-update-icon-cache -f ~/.local/share/icons/Aiko >/dev/null 2>&1

# 2. Re-apply the current theme via SIGUSR2 (Waybar style reload)
# This sometimes triggers a widget redraw
kill -SIGUSR2 "$WAYBAR_PID"
