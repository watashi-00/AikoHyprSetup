#!/usr/bin/env bash

# Clipboard history using cliphist and wofi
if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

cliphist list | wofi --dmenu --prompt "Área de Transferência" --style ~/.config/waybar/wofi.css | cliphist decode | wl-copy
