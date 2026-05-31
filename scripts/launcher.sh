#!/usr/bin/env bash

# Wofi launcher with custom style
if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

WOFI_CONF="$HOME/.config/wofi/config"
WOFI_STYLE="$HOME/.config/wofi/style.css"

if [ ! -f "$WOFI_CONF" ]; then
    WOFI_CONF="$HOME/.config/waybar/wofi.conf"
fi

if [ ! -f "$WOFI_STYLE" ]; then
    WOFI_STYLE="$HOME/.config/waybar/wofi.css"
fi

wofi --show drun --prompt "Search..." --conf "$WOFI_CONF" --style "$WOFI_STYLE"
