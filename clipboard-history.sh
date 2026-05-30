#!/usr/bin/env bash

# Clipboard history using cliphist and wofi
if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

WOFI_STYLE="$HOME/.config/wofi/style.css"

if [ ! -f "$WOFI_STYLE" ]; then
    WOFI_STYLE="$HOME/.config/waybar/wofi.css"
fi

cliphist list | wofi --dmenu --prompt "Área de Transferência" --style "$WOFI_STYLE" | cliphist decode | wl-copy
